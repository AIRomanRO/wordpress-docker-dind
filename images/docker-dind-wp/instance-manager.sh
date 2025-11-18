#!/bin/bash
set -e

INSTANCES_DIR="/wordpress-instances"
NETWORK_PREFIX="wp-network"
HOST_CONFIG_DIR="/host-config"
HOST_LOGS_DIR="/host-logs"
WORKSPACE_CONFIG="/wordpress-instances/.workspace-config.json"
INSTANCE_PORT_START=8001

# Default values from environment variables (set in docker-compose-dind.yml from .env)
DEFAULT_MYSQL_VERSION="${DEFAULT_MYSQL_VERSION:-80}"
DEFAULT_PHP_VERSION="${DEFAULT_PHP_VERSION:-83}"
DEFAULT_WEBSERVER="${DEFAULT_WEBSERVER:-nginx}"
DEFAULT_DB_NAME="${DEFAULT_DB_NAME:-wordpress}"
DEFAULT_DB_USER="${DEFAULT_DB_USER:-wordpress}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to get next available port
get_next_port() {
    local max_port=$INSTANCE_PORT_START

    # Check workspace config for existing instance ports
    if [ -f "$WORKSPACE_CONFIG" ]; then
        local ports=$(jq -r '.instances | to_entries[] | .value.port // empty' "$WORKSPACE_CONFIG" 2>/dev/null)
        for port in $ports; do
            if [ "$port" -ge "$max_port" ]; then
                max_port=$((port + 1))
            fi
        done
    fi

    echo "$max_port"
}

# Function to save instance to workspace config
save_instance_to_config() {
    local name=$1
    local port=$2
    local webserver=$3
    local php_version=$4
    local mysql_version=$5

    if [ ! -f "$WORKSPACE_CONFIG" ]; then
        return 0
    fi

    # Update workspace config with instance info
    local temp_file=$(mktemp)
    jq --arg name "$name" \
       --arg port "$port" \
       --arg webserver "$webserver" \
       --arg php "$php_version" \
       --arg mysql "$mysql_version" \
       '.instances[$name] = {
           "port": ($port | tonumber),
           "stack": {
               "webserver": $webserver,
               "phpVersion": $php,
               "mysqlVersion": $mysql
           },
           "createdAt": (now | todate),
           "status": "created"
       }' "$WORKSPACE_CONFIG" > "$temp_file" && mv "$temp_file" "$WORKSPACE_CONFIG"
}

# Function to remove instance from workspace config
remove_instance_from_config() {
    local name=$1

    if [ ! -f "$WORKSPACE_CONFIG" ]; then
        return 0
    fi

    local temp_file=$(mktemp)
    jq --arg name "$name" 'del(.instances[$name])' "$WORKSPACE_CONFIG" > "$temp_file" && mv "$temp_file" "$WORKSPACE_CONFIG"
}

# Function to display usage
usage() {
    cat << EOF
WordPress Instance Manager

Usage: $0 <command> [options]

Commands:
    create <name> [mysql_version] [php_version] [webserver]
                                     Create a new WordPress instance
                                     mysql_version: 56, 57, 80 (default: ${DEFAULT_MYSQL_VERSION})
                                     php_version: 74, 80, 81, 82, 83 (default: ${DEFAULT_PHP_VERSION})
                                     webserver: nginx, apache (default: ${DEFAULT_WEBSERVER})

    start <name>                     Start a WordPress instance

    stop <name>                      Stop a WordPress instance

    remove <name>                    Remove a WordPress instance

    list                             List all WordPress instances

    info <name>                      Show information about an instance

    clone <source> <target> [strategy]
                                     Clone an existing instance
                                     strategy: symlink (default), copy-all, copy-files
                                     - symlink: Share files, separate database
                                     - copy-all: Copy files + database
                                     - copy-files: Copy files, empty database

    logs <name> [service]            Show logs for an instance
                                     service: php, mysql, nginx/apache (default: all)

Examples:
    $0 create mysite 80 83 nginx
    $0 create mysite2 57 74 apache
    $0 start mysite
    $0 info mysite
    $0 clone mysite mysite-clone symlink
    $0 logs mysite php
    $0 stop mysite
    $0 remove mysite

EOF
    exit 1
}

# Function to create a new WordPress instance
create_instance() {
    local name=$1
    local mysql_version=${2:-$DEFAULT_MYSQL_VERSION}
    local php_version=${3:-$DEFAULT_PHP_VERSION}
    local webserver=${4:-$DEFAULT_WEBSERVER}
    local instance_dir="${INSTANCES_DIR}/${name}"

    if [ -d "$instance_dir" ]; then
        echo -e "${RED}Error: Instance '${name}' already exists${NC}"
        exit 1
    fi

    # Validate webserver choice
    if [ "$webserver" != "nginx" ] && [ "$webserver" != "apache" ]; then
        echo -e "${RED}Error: Invalid webserver '${webserver}'. Must be 'nginx' or 'apache'${NC}"
        exit 1
    fi

    echo -e "${GREEN}Creating WordPress instance: ${name}${NC}"
    echo -e "${YELLOW}  MySQL: ${mysql_version}, PHP: ${php_version}, Web Server: ${webserver}${NC}"

    # Map version codes to semantic versions for Docker images
    local mysql_image_version
    case $mysql_version in
        56) mysql_image_version="5.6.51" ;;
        57) mysql_image_version="5.7.44" ;;
        80) mysql_image_version="8.0.40" ;;
        *) mysql_image_version="8.0.40" ;;
    esac

    local php_image_version
    case $php_version in
        74) php_image_version="7.4.33" ;;
        80) php_image_version="8.0.30" ;;
        81) php_image_version="8.1.31" ;;
        82) php_image_version="8.2.26" ;;
        83) php_image_version="8.3.14" ;;
        *) php_image_version="8.3.14" ;;
    esac

    # Map version codes to major.minor for directory names
    local mysql_full_version
    case $mysql_version in
        56) mysql_full_version="5.6" ;;
        57) mysql_full_version="5.7" ;;
        80) mysql_full_version="8.0" ;;
        *) mysql_full_version="8.0" ;;
    esac

    local php_full_version
    case $php_version in
        74) php_full_version="7.4" ;;
        80) php_full_version="8.0" ;;
        81) php_full_version="8.1" ;;
        82) php_full_version="8.2" ;;
        83) php_full_version="8.3" ;;
        *) php_full_version="8.3" ;;
    esac

    local nginx_version="1.27.3"
    local apache_version="2.4.62"

    local webserver_version
    if [ "$webserver" = "nginx" ]; then
        webserver_version="$nginx_version"
    else
        webserver_version="$apache_version"
    fi

    # Create instance directory structure (only data, configs and logs are on host)
    mkdir -p "${instance_dir}"/data/wordpress
    mkdir -p "${instance_dir}"/data/mysql

    # Create config directories
    mkdir -p "${instance_dir}"/config/php-${php_full_version}
    mkdir -p "${instance_dir}"/config/mysql-${mysql_full_version}
    mkdir -p "${instance_dir}"/config/${webserver}-${webserver_version}

    # Create log directories on host (mounted at /host-logs)
    mkdir -p "${HOST_LOGS_DIR}/${name}/php-${php_full_version}"
    mkdir -p "${HOST_LOGS_DIR}/${name}/mysql-${mysql_full_version}"
    mkdir -p "${HOST_LOGS_DIR}/${name}/${webserver}-${webserver_version}"

    # Create symlinks in instance dir pointing to host logs (for backward compatibility)
    mkdir -p "${instance_dir}"/logs
    ln -sf "${HOST_LOGS_DIR}/${name}/php-${php_full_version}" "${instance_dir}/logs/php-${php_full_version}"
    ln -sf "${HOST_LOGS_DIR}/${name}/mysql-${mysql_full_version}" "${instance_dir}/logs/mysql-${mysql_full_version}"
    ln -sf "${HOST_LOGS_DIR}/${name}/${webserver}-${webserver_version}" "${instance_dir}/logs/${webserver}-${webserver_version}"
    
    # Generate random passwords
    local db_password=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)
    local db_root_password=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)

    # Get next available port
    local instance_port=$(get_next_port)
    echo -e "${YELLOW}  Assigned port: ${instance_port}${NC}"

    # Get next available instance ID for network
    local instance_id=$(find "$INSTANCES_DIR" -maxdepth 1 -type d | wc -l)
    local network_name="${NETWORK_PREFIX}-${instance_id}"

    # Create network if it doesn't exist
    if ! docker network inspect "$network_name" >/dev/null 2>&1; then
        local subnet="172.20.${instance_id}.0/24"
        docker network create \
            --driver bridge \
            --subnet "$subnet" \
            "$network_name"
    fi

    # Ensure shared network exists for multi-instance mode
    if ! docker network inspect "wp-shared" >/dev/null 2>&1; then
        docker network create --driver bridge --subnet 172.21.0.0/16 "wp-shared"
    fi

    # Copy default PHP configuration from templates
    cp /app/config-templates/php/*.ini "${instance_dir}/config/php-${php_full_version}/"

    # Create a custom.ini for user overrides
    cat > "${instance_dir}/config/php-${php_full_version}/custom.ini" << 'EOF'
; Custom PHP settings
; Add your custom PHP configuration here
; This file will override settings from other .ini files

; Example: Enable Xdebug for debugging
; xdebug.mode=debug

; Example: Increase memory limit
; memory_limit=512M
EOF

    # Copy default MySQL configuration from templates
    cp /app/config-templates/mysql/my.cnf "${instance_dir}/config/mysql-${mysql_full_version}/"

    # Copy default webserver configuration from templates
    if [ "$webserver" = "nginx" ]; then
        cp /app/config-templates/nginx/wordpress.conf "${instance_dir}/config/${webserver}-${webserver_version}/"
    elif [ "$webserver" = "apache" ]; then
        cp /app/config-templates/apache/wordpress.conf "${instance_dir}/config/${webserver}-${webserver_version}/"
    fi

    # Create docker-compose.yml for the instance
    cat > "${instance_dir}/docker-compose.yml" << EOF
version: '3.8'

services:
  mysql:
    image: airoman/wp-dind:mysql-${mysql_image_version}
    container_name: ${name}-mysql
    environment:
      MYSQL_ROOT_PASSWORD: ${db_root_password}
      MYSQL_DATABASE: ${DEFAULT_DB_NAME}
      MYSQL_USER: ${DEFAULT_DB_USER}
      MYSQL_PASSWORD: ${db_password}
    volumes:
      - ./data/mysql:/var/lib/mysql
      - ${HOST_LOGS_DIR}/${name}/mysql-${mysql_full_version}:/var/log/mysql
      - ${HOST_CONFIG_DIR}/mysql/${mysql_version}/my.cnf:/etc/mysql/conf.d/host.cnf:ro
      - ./config/mysql-${mysql_full_version}/custom.cnf:/etc/mysql/conf.d/custom.cnf:ro
    networks:
      - ${network_name}
      - wp-shared
    restart: unless-stopped

  php:
    image: airoman/wp-dind:php-${php_image_version}
    container_name: ${name}-php
    depends_on:
      - mysql
    environment:
      WORDPRESS_DB_HOST: mysql:3306
      WORDPRESS_DB_USER: ${DEFAULT_DB_USER}
      WORDPRESS_DB_PASSWORD: ${db_password}
      WORDPRESS_DB_NAME: ${DEFAULT_DB_NAME}
    volumes:
      - ./data/wordpress:/var/www/html
      - ${HOST_CONFIG_DIR}/php/${php_version}:/host-php-config:ro
      - ./config/php-${php_full_version}/custom.ini:/usr/local/etc/php/conf.d/zzz-custom.ini:ro
      - ${HOST_LOGS_DIR}/${name}/php-${php_full_version}:/var/log/php
    networks:
      - ${network_name}
      - wp-shared
    restart: unless-stopped

  ${webserver}:
    image: airoman/wp-dind:${webserver}-${webserver_version}
    container_name: ${name}-${webserver}
    depends_on:
      - php
    ports:
      - "${instance_port}:80"
    volumes:
      - ./data/wordpress:/var/www/html:ro
      - ./config/${webserver}-${webserver_version}/wordpress.conf:/etc/${webserver}/conf.d/wordpress.conf:ro
      - ${HOST_LOGS_DIR}/${name}/${webserver}-${webserver_version}:/var/log/${webserver}
    networks:
      - ${network_name}
      - wp-shared
    restart: unless-stopped

networks:
  ${network_name}:
    external: true
  wp-shared:
    external: true
EOF



    # Save instance metadata
    cat > "${instance_dir}/.instance-info" << EOF
NAME=${name}
MYSQL_VERSION=${mysql_version}
PHP_VERSION=${php_version}
WEBSERVER=${webserver}
NETWORK=${network_name}
PORT=${instance_port}
CREATED=$(date -Iseconds)
DB_PASSWORD=${db_password}
DB_ROOT_PASSWORD=${db_root_password}
EOF

    # Save instance to workspace config
    save_instance_to_config "$name" "$instance_port" "$webserver" "$php_full_version" "$mysql_full_version"

    echo -e "${GREEN}Instance '${name}' created successfully!${NC}"
    echo -e "${YELLOW}Instance directory: ${instance_dir}${NC}"
    echo -e "${YELLOW}Configuration:${NC}"
    echo -e "  - MySQL: ${mysql_version}"
    echo -e "  - PHP: ${php_version}"
    echo -e "  - Web Server: ${webserver}"
    echo -e "  - Network: ${network_name}"
    echo -e "  - Port: ${instance_port}"
    echo ""
    echo -e "${YELLOW}Configuration files:${NC}"
    echo -e "  - PHP: ${instance_dir}/config/php/php.ini"
    echo -e "  - MySQL: ${instance_dir}/config/mysql/my.cnf"
    echo -e "  - ${webserver}: ${instance_dir}/config/${webserver}/"
    echo ""
    echo -e "${YELLOW}Data directories:${NC}"
    echo -e "  - WordPress: ${instance_dir}/data/wordpress/"
    echo -e "  - MySQL: ${instance_dir}/data/mysql/"
    echo -e "  - Logs: ${instance_dir}/data/logs/"
    echo ""
    echo "To start the instance, run:"
    echo "  $0 start ${name}"
}

# Function to start an instance
start_instance() {
    local name=$1
    local instance_dir="${INSTANCES_DIR}/${name}"
    
    if [ ! -d "$instance_dir" ]; then
        echo -e "${RED}Error: Instance '${name}' does not exist${NC}"
        exit 1
    fi
    
    # Load instance info to get webserver type
    source "$instance_dir/.instance-info"

    echo -e "${GREEN}Starting WordPress instance: ${name}${NC}"
    cd "$instance_dir"
    docker-compose up -d

    # Get the webserver port
    local webserver_port=$(docker port "${name}-${WEBSERVER}" 80 2>/dev/null | cut -d: -f2)

    echo -e "${GREEN}Instance '${name}' started successfully!${NC}"
    if [ -n "$webserver_port" ]; then
        echo -e "${YELLOW}Access WordPress at: http://localhost:${webserver_port}${NC}"
    fi
}

# Function to stop an instance
stop_instance() {
    local name=$1
    local instance_dir="${INSTANCES_DIR}/${name}"
    
    if [ ! -d "$instance_dir" ]; then
        echo -e "${RED}Error: Instance '${name}' does not exist${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}Stopping WordPress instance: ${name}${NC}"
    cd "$instance_dir"
    docker-compose stop
    echo -e "${GREEN}Instance '${name}' stopped${NC}"
}

# Function to remove an instance
remove_instance() {
    local name=$1
    local instance_dir="${INSTANCES_DIR}/${name}"
    
    if [ ! -d "$instance_dir" ]; then
        echo -e "${RED}Error: Instance '${name}' does not exist${NC}"
        exit 1
    fi
    
    echo -e "${YELLOW}Warning: This will remove all data for instance '${name}'${NC}"
    read -p "Are you sure? (yes/no): " confirm
    
    if [ "$confirm" != "yes" ]; then
        echo "Cancelled"
        exit 0
    fi
    
    echo -e "${GREEN}Removing WordPress instance: ${name}${NC}"
    cd "$instance_dir"
    docker-compose down -v
    cd /
    rm -rf "$instance_dir"

    # Remove from workspace config
    remove_instance_from_config "$name"

    echo -e "${GREEN}Instance '${name}' removed${NC}"
}

# Function to list all instances
list_instances() {
    echo -e "${GREEN}WordPress Instances:${NC}"
    echo ""
    
    if [ ! -d "$INSTANCES_DIR" ] || [ -z "$(ls -A $INSTANCES_DIR 2>/dev/null)" ]; then
        echo "No instances found"
        return
    fi
    
    printf "%-15s %-8s %-8s %-10s %-20s %-10s\n" "NAME" "MYSQL" "PHP" "WEBSERVER" "NETWORK" "STATUS"
    printf "%-15s %-8s %-8s %-10s %-20s %-10s\n" "----" "-----" "---" "---------" "-------" "------"

    for instance_dir in "$INSTANCES_DIR"/*; do
        if [ -d "$instance_dir" ] && [ -f "$instance_dir/.instance-info" ]; then
            source "$instance_dir/.instance-info"
            local status="stopped"
            if docker ps --format '{{.Names}}' | grep -q "^${NAME}-"; then
                status="running"
            fi
            printf "%-15s %-8s %-8s %-10s %-20s %-10s\n" "$NAME" "$MYSQL_VERSION" "$PHP_VERSION" "$WEBSERVER" "$NETWORK" "$status"
        fi
    done
}

# Function to clone an instance
clone_instance() {
    local source_name=$1
    local target_name=$2
    local strategy=${3:-symlink}

    local source_dir="${INSTANCES_DIR}/${source_name}"
    local target_dir="${INSTANCES_DIR}/${target_name}"

    # Validate source instance exists
    if [ ! -d "$source_dir" ] || [ ! -f "$source_dir/.instance-info" ]; then
        echo -e "${RED}Error: Source instance '${source_name}' does not exist${NC}"
        exit 1
    fi

    # Validate target instance doesn't exist
    if [ -d "$target_dir" ]; then
        echo -e "${RED}Error: Target instance '${target_name}' already exists${NC}"
        exit 1
    fi

    # Validate strategy
    if [[ ! "$strategy" =~ ^(symlink|copy-all|copy-files)$ ]]; then
        echo -e "${RED}Error: Invalid clone strategy. Use: symlink, copy-all, or copy-files${NC}"
        exit 1
    fi

    echo -e "${GREEN}Cloning instance '${source_name}' to '${target_name}' using strategy: ${strategy}${NC}"

    # Load source instance info
    source "$source_dir/.instance-info"
    local source_mysql_version=$MYSQL_VERSION
    local source_php_version=$PHP_VERSION
    local source_webserver=$WEBSERVER
    local source_port=$PORT

    # Create new instance with same stack
    echo -e "${YELLOW}Creating target instance...${NC}"
    create_instance "$target_name" "$source_mysql_version" "$source_php_version" "$source_webserver"

    # Stop target instance
    echo -e "${YELLOW}Stopping target instance...${NC}"
    cd "$target_dir"
    docker-compose stop

    # Apply cloning strategy
    case "$strategy" in
        symlink)
            echo -e "${YELLOW}Applying symlink strategy (shared files, separate database)...${NC}"
            # Remove target WordPress directory
            rm -rf "${target_dir}/data/wordpress"
            # Create symlink to source WordPress files
            ln -s "${source_dir}/data/wordpress" "${target_dir}/data/wordpress"
            echo -e "${GREEN}WordPress files symlinked${NC}"
            ;;
        copy-all)
            echo -e "${YELLOW}Applying copy-all strategy (copy files + database)...${NC}"
            # Copy WordPress files
            rm -rf "${target_dir}/data/wordpress"
            cp -a "${source_dir}/data/wordpress" "${target_dir}/data/wordpress"
            echo -e "${GREEN}WordPress files copied${NC}"

            # Copy database
            echo -e "${YELLOW}Copying database...${NC}"
            # Start both instances
            cd "$source_dir" && docker-compose start mysql
            cd "$target_dir" && docker-compose start mysql
            sleep 5

            # Export from source
            docker exec "${source_name}-mysql" mysqldump -u root -p"${DB_ROOT_PASSWORD}" wordpress > /tmp/clone-db.sql
            # Import to target
            docker exec -i "${target_name}-mysql" mysql -u root -p"${DB_ROOT_PASSWORD}" wordpress < /tmp/clone-db.sql
            rm /tmp/clone-db.sql
            echo -e "${GREEN}Database copied${NC}"
            ;;
        copy-files)
            echo -e "${YELLOW}Applying copy-files strategy (copy files, empty database)...${NC}"
            # Copy WordPress files
            rm -rf "${target_dir}/data/wordpress"
            cp -a "${source_dir}/data/wordpress" "${target_dir}/data/wordpress"
            echo -e "${GREEN}WordPress files copied (database is empty)${NC}"
            ;;
    esac

    # Start target instance
    echo -e "${YELLOW}Starting target instance...${NC}"
    cd "$target_dir"
    docker-compose start

    echo -e "${GREEN}Instance '${target_name}' cloned successfully!${NC}"
    echo -e "${YELLOW}Clone strategy: ${strategy}${NC}"

    # Show info
    source "${target_dir}/.instance-info"
    echo -e "${YELLOW}Target instance port: ${PORT}${NC}"
}

# Function to show instance info
show_info() {
    local name=$1
    local instance_dir="${INSTANCES_DIR}/${name}"

    if [ ! -d "$instance_dir" ] || [ ! -f "$instance_dir/.instance-info" ]; then
        echo -e "${RED}Error: Instance '${name}' does not exist${NC}"
        exit 1
    fi
    
    source "$instance_dir/.instance-info"
    
    echo -e "${GREEN}Instance Information: ${name}${NC}"
    echo "================================"
    echo "Name: $NAME"
    echo "MySQL Version: $MYSQL_VERSION"
    echo "PHP Version: $PHP_VERSION"
    echo "Web Server: $WEBSERVER"
    echo "Network: $NETWORK"
    echo "Port: ${PORT:-N/A}"
    echo "Created: $CREATED"
    echo "Instance Directory: $instance_dir"
    echo ""
    echo "Database Credentials:"
    echo "  Database: wordpress"
    echo "  User: wordpress"
    echo "  Password: $DB_PASSWORD"
    echo "  Root Password: $DB_ROOT_PASSWORD"
    echo ""
    echo "Configuration Files:"
    echo "  PHP: $instance_dir/config/php/php.ini"
    echo "  MySQL: $instance_dir/config/mysql/my.cnf"
    echo "  $WEBSERVER: $instance_dir/config/$WEBSERVER/"
    echo ""
    echo "Data Directories:"
    echo "  WordPress: $instance_dir/data/wordpress/"
    echo "  MySQL: $instance_dir/data/mysql/"
    echo "  Logs: $instance_dir/data/logs/"
    echo ""

    # Check if running
    if docker ps --format '{{.Names}}' | grep -q "^${NAME}-"; then
        echo -e "${GREEN}Status: Running${NC}"
        echo ""
        echo "Containers:"
        docker ps --filter "name=${NAME}-" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

        # Get DinD container IP
        local dind_ip=$(hostname -i | awk '{print $1}')
        if [ -n "$PORT" ]; then
            echo ""
            echo -e "${YELLOW}Access URL: http://${dind_ip}:${PORT}${NC}"
            echo -e "${YELLOW}Or via host: http://localhost:${PORT}${NC}"
        fi
    else
        echo -e "${YELLOW}Status: Stopped${NC}"
    fi
}

# Main script logic
case "${1:-}" in
    create)
        [ -z "$2" ] && usage
        create_instance "$2" "${3:-80}" "${4:-83}" "${5:-nginx}"
        ;;
    start)
        [ -z "$2" ] && usage
        start_instance "$2"
        ;;
    stop)
        [ -z "$2" ] && usage
        stop_instance "$2"
        ;;
    remove)
        [ -z "$2" ] && usage
        remove_instance "$2"
        ;;
    list)
        list_instances
        ;;
    info)
        [ -z "$2" ] && usage
        show_info "$2"
        ;;
    clone)
        [ -z "$2" ] && usage
        clone_instance "$2" "$3" "${4:-symlink}"
        ;;
    logs)
        [ -z "$2" ] && usage
        cd "${INSTANCES_DIR}/$2"
        if [ -n "$3" ]; then
            docker-compose logs -f "$3"
        else
            docker-compose logs -f
        fi
        ;;
    *)
        usage
        ;;
esac

