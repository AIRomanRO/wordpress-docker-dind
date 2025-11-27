#!/bin/bash
set -e

INSTANCES_DIR="/wordpress-instances"
WORKSPACE_CONFIG="/wordpress-instances/.workspace-config.json"
MYSQL_PORT_START=3307

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}MySQL Port Migration Script${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "This script will update existing instances to expose MySQL ports"
echo ""

# Function to get next available MySQL port
get_next_mysql_port() {
    local max_port=$MYSQL_PORT_START

    # Check workspace config for existing MySQL ports
    if [ -f "$WORKSPACE_CONFIG" ]; then
        local ports=$(jq -r '.instances | to_entries[] | .value.mysql_port // empty' "$WORKSPACE_CONFIG" 2>/dev/null)
        for port in $ports; do
            if [ "$port" -ge "$max_port" ]; then
                max_port=$((port + 1))
            fi
        done
    fi

    echo "$max_port"
}

# Function to update instance docker-compose.yml
update_instance() {
    local name=$1
    local instance_dir="${INSTANCES_DIR}/${name}"
    local compose_file="${instance_dir}/docker-compose.yml"
    
    if [ ! -f "$compose_file" ]; then
        echo -e "${RED}Error: docker-compose.yml not found for instance '${name}'${NC}"
        return 1
    fi
    
    # Check if MySQL port is already exposed
    if grep -q "ports:" "$compose_file" | grep -A 1 "mysql:" | grep -q "3306:3306"; then
        echo -e "${YELLOW}Instance '${name}' already has MySQL port exposed${NC}"
        return 0
    fi
    
    # Get next available MySQL port
    local mysql_port=$(get_next_mysql_port)
    
    echo -e "${YELLOW}Updating instance '${name}' with MySQL port ${mysql_port}...${NC}"
    
    # Create backup
    cp "$compose_file" "${compose_file}.backup"
    
    # Add MySQL port to docker-compose.yml
    # This uses sed to add the ports section after the mysql service environment section
    sed -i '/mysql:/,/networks:/ {
        /environment:/,/networks:/ {
            /MYSQL_PASSWORD:/a\    ports:\n      - "'${mysql_port}':3306"
        }
    }' "$compose_file"
    
    # Update workspace config with MySQL port
    if [ -f "$WORKSPACE_CONFIG" ]; then
        local temp_file=$(mktemp)
        jq --arg name "$name" \
           --arg mysql_port "$mysql_port" \
           '.instances[$name].mysql_port = ($mysql_port | tonumber)' \
           "$WORKSPACE_CONFIG" > "$temp_file" && mv "$temp_file" "$WORKSPACE_CONFIG"
    fi
    
    echo -e "${GREEN}Instance '${name}' updated with MySQL port ${mysql_port}${NC}"
    echo -e "${YELLOW}Backup saved to: ${compose_file}.backup${NC}"
    
    return 0
}

# Main migration logic
echo "Scanning for instances..."
echo ""

if [ ! -d "$INSTANCES_DIR" ]; then
    echo -e "${RED}Error: Instances directory not found${NC}"
    exit 1
fi

# Get list of instances
instances=$(find "$INSTANCES_DIR" -maxdepth 1 -type d -not -path "$INSTANCES_DIR" -exec basename {} \; 2>/dev/null | grep -v "^\." || true)

if [ -z "$instances" ]; then
    echo "No instances found"
    exit 0
fi

echo "Found instances:"
for instance in $instances; do
    echo "  - $instance"
done
echo ""

# Ask for confirmation
read -p "Do you want to update all instances? (y/n) " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Migration cancelled"
    exit 0
fi

echo ""
echo "Starting migration..."
echo ""

# Update each instance
updated_count=0
failed_count=0

for instance in $instances; do
    if update_instance "$instance"; then
        updated_count=$((updated_count + 1))
    else
        failed_count=$((failed_count + 1))
    fi
    echo ""
done

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Migration Complete${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "Summary:"
echo "  - Updated: $updated_count"
echo "  - Failed: $failed_count"
echo ""
echo -e "${YELLOW}IMPORTANT: You need to restart each instance for changes to take effect:${NC}"
echo ""
for instance in $instances; do
    echo "  cd ${INSTANCES_DIR}/${instance} && docker-compose down && docker-compose up -d"
done
echo ""
echo "Or use the instance manager:"
echo ""
for instance in $instances; do
    echo "  /app/instance-manager.sh restart ${instance}"
done
echo ""

