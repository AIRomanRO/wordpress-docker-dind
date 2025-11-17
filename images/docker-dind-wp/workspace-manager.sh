#!/bin/bash
set -e

WORKSPACE_CONFIG="/wordpress-instances/.workspace-config.json"
WORKSPACE_DIR="/var/www/html"
COMPOSE_FILE="/tmp/workspace-compose.yml"
NGINX_CONFIG_FILE="/tmp/workspace-nginx.conf"
NETWORK_NAME="wp-shared"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to check if workspace mode is enabled
is_workspace_mode() {
    if [ ! -f "$WORKSPACE_CONFIG" ]; then
        return 1
    fi
    
    local workspace_type=$(jq -r '.workspaceType // "multi-instance"' "$WORKSPACE_CONFIG")
    [ "$workspace_type" = "workspace" ]
}

# Function to get workspace stack configuration
get_workspace_stack() {
    if [ ! -f "$WORKSPACE_CONFIG" ]; then
        echo -e "${RED}Error: Workspace config not found${NC}"
        return 1
    fi
    
    WEBSERVER=$(jq -r '.workspaceStack.webserver // "nginx"' "$WORKSPACE_CONFIG")
    PHP_VERSION=$(jq -r '.workspaceStack.phpVersion // "8.3"' "$WORKSPACE_CONFIG")
    MYSQL_VERSION=$(jq -r '.workspaceStack.mysqlVersion // "8.0"' "$WORKSPACE_CONFIG")
    
    # Convert version to short format
    PHP_SHORT=$(echo "$PHP_VERSION" | tr -d '.')
    MYSQL_SHORT=$(echo "$MYSQL_VERSION" | tr -d '.')
}

# Function to map version to image version
get_image_version() {
    local component=$1
    local version=$2
    
    case "$component" in
        php)
            case "$version" in
                74) echo "7.4.33" ;;
                80) echo "8.0.30" ;;
                81) echo "8.1.31" ;;
                82) echo "8.2.26" ;;
                83) echo "8.3.14" ;;
                *) echo "8.3.14" ;;
            esac
            ;;
        mysql)
            case "$version" in
                56) echo "5.6.51" ;;
                57) echo "5.7.44" ;;
                80) echo "8.0.40" ;;
                *) echo "8.0.40" ;;
            esac
            ;;
        nginx)
            echo "1.27.3"
            ;;
        apache)
            echo "2.4.62"
            ;;
    esac
}

# Function to create nginx configuration
create_nginx_config() {
    cat > "$NGINX_CONFIG_FILE" <<'NGINX_EOF'
server {
    listen 80;
    server_name _;

    root /var/www/html;
    index index.php index.html index.htm;

    # Logging
    access_log /var/log/nginx/access.log;
    error_log /var/log/nginx/error.log;

    # Client upload size
    client_max_body_size 64M;

    # WordPress permalinks
    location / {
        try_files $uri $uri/ /index.php?$args;
    }

    # PHP-FPM configuration
    location ~ \.php$ {
        try_files $uri =404;
        fastcgi_split_path_info ^(.+\.php)(/.+)$;
        fastcgi_pass workspace-php:9000;
        fastcgi_index index.php;
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        fastcgi_param PATH_INFO $fastcgi_path_info;

        # Increase timeouts for long-running scripts
        fastcgi_read_timeout 300;
        fastcgi_send_timeout 300;
    }

    # Deny access to sensitive files
    location ~ /\. {
        deny all;
        access_log off;
        log_not_found off;
    }

    location = /favicon.ico {
        log_not_found off;
        access_log off;
    }

    location = /robots.txt {
        allow all;
        log_not_found off;
        access_log off;
    }

    # Deny access to wp-config.php
    location ~* wp-config.php {
        deny all;
    }

    # Cache static files
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$ {
        expires max;
        log_not_found off;
        access_log off;
    }
}
NGINX_EOF
}

# Function to generate docker-compose for workspace
generate_workspace_compose() {
    get_workspace_stack

    local php_image_version=$(get_image_version "php" "$PHP_SHORT")
    local mysql_image_version=$(get_image_version "mysql" "$MYSQL_SHORT")
    local webserver_image_version=$(get_image_version "$WEBSERVER" "")

    echo -e "${GREEN}Generating workspace compose for: ${WEBSERVER}, PHP ${PHP_VERSION}, MySQL ${MYSQL_VERSION}${NC}"

    # Create nginx configuration if needed
    if [ "$WEBSERVER" = "nginx" ]; then
        create_nginx_config
    fi
    
    # Generate webserver config based on type
    local webserver_config=""
    if [ "$WEBSERVER" = "nginx" ]; then
        webserver_config="  workspace-nginx:
    image: airoman/wp-dind:nginx-${webserver_image_version}
    container_name: workspace-nginx
    ports:
      - \"8000:80\"
    volumes:
      - ${WORKSPACE_DIR}:/var/www/html
      - ${NGINX_CONFIG_FILE}:/etc/nginx/conf.d/default.conf:ro
    networks:
      - ${NETWORK_NAME}
    depends_on:
      - workspace-php
    restart: unless-stopped"
    else
        webserver_config="  workspace-apache:
    image: airoman/wp-dind:apache-${webserver_image_version}
    container_name: workspace-apache
    ports:
      - \"8000:80\"
    volumes:
      - ${WORKSPACE_DIR}:/var/www/html
    environment:
      - PHP_FPM_HOST=workspace-php
      - PHP_FPM_PORT=9000
    networks:
      - ${NETWORK_NAME}
    depends_on:
      - workspace-php
    restart: unless-stopped"
    fi
    
    # Generate docker-compose.yml
    cat > "$COMPOSE_FILE" <<EOF
version: '3.8'

services:
  workspace-mysql:
    image: airoman/wp-dind:mysql-${mysql_image_version}
    container_name: workspace-mysql
    environment:
      MYSQL_ROOT_PASSWORD: rootpassword
      MYSQL_DATABASE: wordpress
      MYSQL_USER: wordpress
      MYSQL_PASSWORD: wordpress
    volumes:
      - workspace-mysql-data:/var/lib/mysql
    networks:
      - ${NETWORK_NAME}
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "mysqladmin", "ping", "-h", "localhost", "-u", "root", "-prootpassword"]
      interval: 10s
      timeout: 5s
      retries: 5

  workspace-php:
    image: airoman/wp-dind:php-${php_image_version}
    container_name: workspace-php
    volumes:
      - ${WORKSPACE_DIR}:/var/www/html
    environment:
      - PUID=\${PUID:-1000}
      - PGID=\${PGID:-1000}
    networks:
      - ${NETWORK_NAME}
    depends_on:
      - workspace-mysql
    restart: unless-stopped

${webserver_config}

networks:
  ${NETWORK_NAME}:
    external: true

volumes:
  workspace-mysql-data:
    driver: local
EOF
}

# Function to start workspace
start_workspace() {
    if ! is_workspace_mode; then
        echo -e "${YELLOW}Not in workspace mode, skipping workspace startup${NC}"
        return 0
    fi
    
    echo -e "${GREEN}Starting workspace mode...${NC}"
    
    # Ensure shared network exists
    if ! docker network inspect "$NETWORK_NAME" >/dev/null 2>&1; then
        echo -e "${YELLOW}Creating shared network: ${NETWORK_NAME}${NC}"
        docker network create --driver bridge --subnet 172.21.0.0/16 "$NETWORK_NAME"
    fi
    
    # Generate compose file
    generate_workspace_compose
    
    # Start containers
    echo -e "${GREEN}Starting workspace containers...${NC}"
    docker-compose -f "$COMPOSE_FILE" up -d
    
    # Wait for MySQL to be ready
    echo -e "${YELLOW}Waiting for MySQL to be ready...${NC}"
    timeout=60
    counter=0
    until docker exec workspace-mysql mysqladmin ping -h localhost -u root -prootpassword --silent >/dev/null 2>&1; do
        sleep 1
        counter=$((counter + 1))
        if [ $counter -ge $timeout ]; then
            echo -e "${RED}ERROR: MySQL failed to start within ${timeout} seconds${NC}"
            return 1
        fi
    done
    
    echo -e "${GREEN}Workspace started successfully!${NC}"
    echo -e "${YELLOW}Access WordPress at: http://<dind-ip>:80${NC}"
}

# Function to stop workspace
stop_workspace() {
    if [ ! -f "$COMPOSE_FILE" ]; then
        echo -e "${YELLOW}No workspace compose file found${NC}"
        return 0
    fi
    
    echo -e "${GREEN}Stopping workspace...${NC}"
    docker-compose -f "$COMPOSE_FILE" down
    echo -e "${GREEN}Workspace stopped${NC}"
}

# Function to get workspace status
status_workspace() {
    if ! is_workspace_mode; then
        echo -e "${YELLOW}Workspace mode: disabled${NC}"
        return 0
    fi
    
    get_workspace_stack
    echo -e "${GREEN}Workspace mode: enabled${NC}"
    echo -e "${YELLOW}Stack: ${WEBSERVER}, PHP ${PHP_VERSION}, MySQL ${MYSQL_VERSION}${NC}"
    
    # Check if containers are running
    if docker ps --format '{{.Names}}' | grep -q "^workspace-"; then
        echo -e "${GREEN}Status: running${NC}"
        docker ps --filter "name=workspace-" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
    else
        echo -e "${YELLOW}Status: stopped${NC}"
    fi
}

# Main command handler
case "${1:-}" in
    start)
        start_workspace
        ;;
    stop)
        stop_workspace
        ;;
    status)
        status_workspace
        ;;
    *)
        echo "Usage: $0 {start|stop|status}"
        exit 1
        ;;
esac

