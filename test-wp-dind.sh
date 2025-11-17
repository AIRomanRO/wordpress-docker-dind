#!/bin/bash

# WordPress DinD Comprehensive Test Script
# Tests both workspace mode and multi-instance mode

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
PARENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_DIR="${PARENT_DIR}/test-wp"
CLI_TOOL="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/cli-tool/bin/wp-dind.js"
DIND_IP=""
CONTAINER_NAME=""

# Test results
TESTS_PASSED=0
TESTS_FAILED=0

# Helper functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
    ((TESTS_PASSED++))
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
    ((TESTS_FAILED++))
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_section() {
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
}

# Wait for service to be ready
wait_for_service() {
    local url=$1
    local max_attempts=${2:-30}
    local attempt=1
    
    log_info "Waiting for service at $url..."
    
    while [ $attempt -le $max_attempts ]; do
        if curl -s -o /dev/null -w "%{http_code}" "$url" | grep -q "200\|302\|301"; then
            log_success "Service is ready at $url"
            return 0
        fi
        echo -n "."
        sleep 2
        ((attempt++))
    done
    
    log_error "Service at $url did not become ready"
    return 1
}

# Check HTTP response
check_http_response() {
    local url=$1
    local expected_code=${2:-200}
    local description=$3
    
    log_info "Checking $description: $url"
    
    local response_code=$(curl -s -o /dev/null -w "%{http_code}" "$url")
    
    if [[ "$response_code" == "$expected_code" ]] || [[ "$expected_code" == "200|302|301" && "$response_code" =~ ^(200|302|301)$ ]]; then
        log_success "$description returned $response_code"
        return 0
    else
        log_error "$description returned $response_code (expected $expected_code)"
        return 1
    fi
}

# Get DinD container IP
get_dind_ip() {
    local container=$1
    DIND_IP=$(docker inspect "$container" | jq -r '.[0].NetworkSettings.Networks["wp-dind"].IPAddress')
    if [ -z "$DIND_IP" ] || [ "$DIND_IP" == "null" ]; then
        log_error "Failed to get DinD IP address"
        return 1
    fi
    log_info "DinD IP: $DIND_IP"
    return 0
}

# Cleanup function
cleanup() {
    log_section "Cleaning Up"
    
    if [ -d "$TEST_DIR" ]; then
        cd "$TEST_DIR"
        
        # Stop and destroy workspace if exists
        if [ -f "docker-compose.yml" ]; then
            log_info "Stopping and removing containers..."
            docker-compose down -v 2>/dev/null || true
        fi
        
        # Remove test directory
        cd "$PARENT_DIR"
        log_info "Removing test directory: $TEST_DIR"
        rm -rf "$TEST_DIR"
    fi
    
    log_success "Cleanup completed"
}

# Test workspace mode
test_workspace_mode() {
    log_section "TEST 1: Workspace Mode"
    
    # Create test directory
    log_info "Creating test directory: $TEST_DIR"
    rm -rf "$TEST_DIR"
    mkdir -p "$TEST_DIR"
    cd "$TEST_DIR"
    
    # Initialize workspace mode
    log_info "Initializing workspace mode..."
    cat > init-answers.txt << EOF
test-wp
workspace
nginx
8.3
8.0
EOF
    
    node "$CLI_TOOL" init < init-answers.txt
    rm init-answers.txt
    
    if [ ! -f "wp-dind-workspace.json" ]; then
        log_error "Workspace config not created"
        return 1
    fi
    
    # Verify workspace type
    local workspace_type=$(jq -r '.workspaceType' wp-dind-workspace.json)
    if [ "$workspace_type" != "workspace" ]; then
        log_error "Workspace type is $workspace_type, expected 'workspace'"
        return 1
    fi
    log_success "Workspace initialized with type: $workspace_type"
    
    # Start DinD
    log_info "Starting DinD container..."
    docker-compose up -d
    
    # Wait for DinD to be ready
    sleep 15
    
    # Get container name and IP
    CONTAINER_NAME=$(docker-compose ps -q wordpress-dind | xargs docker inspect --format='{{.Name}}' | sed 's/\///')
    get_dind_ip "$CONTAINER_NAME" || return 1
    
    # Wait for workspace to start
    log_info "Waiting for workspace containers to start..."
    sleep 10
    
    # Check if workspace containers are running
    log_info "Checking workspace containers..."
    docker exec "$CONTAINER_NAME" docker ps --format "{{.Names}}" | grep -q "workspace-nginx" || {
        log_error "workspace-nginx container not running"
        docker exec "$CONTAINER_NAME" docker ps -a
        return 1
    }
    log_success "Workspace containers are running"
    
    # Install WordPress
    log_info "Installing WordPress..."
    node "$CLI_TOOL" install-wordpress \
        --url "http://localhost:8000" \
        --title "Test Workspace" \
        --admin-user "admin" \
        --admin-password "admin123" \
        --admin-email "admin@test.local"
    
    # Wait for WordPress to be ready
    sleep 5
    
    # Test access via localhost
    check_http_response "http://localhost:8000" "200|302|301" "Workspace via localhost:8000" || return 1
    
    # Test access via DinD IP
    check_http_response "http://${DIND_IP}:8000" "200|302|301" "Workspace via DinD IP:8000" || return 1
    
    # Test shared services
    check_http_response "http://localhost:8080" "200" "phpMyAdmin via localhost" || return 1
    check_http_response "http://${DIND_IP}:8080" "200" "phpMyAdmin via DinD IP" || return 1
    check_http_response "http://localhost:1080" "200" "MailHog via localhost" || return 1
    check_http_response "http://${DIND_IP}:1080" "200" "MailHog via DinD IP" || return 1
    
    log_success "Workspace mode test completed successfully"
    
    # Cleanup
    log_info "Stopping workspace mode environment..."
    docker-compose down -v
    sleep 5
    
    return 0
}

# Test multi-instance mode
test_multi_instance_mode() {
    log_section "TEST 2: Multi-Instance Mode"
    
    # Create test directory
    log_info "Creating test directory: $TEST_DIR"
    rm -rf "$TEST_DIR"
    mkdir -p "$TEST_DIR"
    cd "$TEST_DIR"
    
    # Initialize multi-instance mode
    log_info "Initializing multi-instance mode..."
    cat > init-answers.txt << EOF
test-wp
multi-instance
EOF
    
    node "$CLI_TOOL" init < init-answers.txt
    rm init-answers.txt
    
    if [ ! -f "wp-dind-workspace.json" ]; then
        log_error "Workspace config not created"
        return 1
    fi
    
    # Verify workspace type
    local workspace_type=$(jq -r '.workspaceType' wp-dind-workspace.json)
    if [ "$workspace_type" != "multi-instance" ]; then
        log_error "Workspace type is $workspace_type, expected 'multi-instance'"
        return 1
    fi
    log_success "Workspace initialized with type: $workspace_type"
    
    # Start DinD
    log_info "Starting DinD container..."
    docker-compose up -d
    
    # Wait for DinD to be ready
    sleep 15
    
    # Get container name and IP
    CONTAINER_NAME=$(docker-compose ps -q wordpress-dind | xargs docker inspect --format='{{.Name}}' | sed 's/\///')
    get_dind_ip "$CONTAINER_NAME" || return 1
    
    # Get available versions from config
    local min_php=$(jq -r '.stack.phpVersions | keys | min' wp-dind-workspace.json)
    local max_php=$(jq -r '.stack.phpVersions | keys | max' wp-dind-workspace.json)
    local min_mysql=$(jq -r '.stack.mysqlVersions | keys | min' wp-dind-workspace.json)
    local max_mysql=$(jq -r '.stack.mysqlVersions | keys | max' wp-dind-workspace.json)
    
    log_info "Creating instance with lowest versions (PHP $min_php, MySQL $min_mysql)..."
    docker exec "$CONTAINER_NAME" /app/instance-manager.sh create test-low "$min_mysql" "$min_php" nginx
    
    # Wait for instance to be created
    sleep 10
    
    # Check instance info
    log_info "Getting instance info..."
    docker exec "$CONTAINER_NAME" /app/instance-manager.sh info test-low
    
    # Get instance port from config
    local instance1_port=$(docker exec "$CONTAINER_NAME" jq -r '.instances["test-low"].port' /wordpress-instances/.workspace-config.json)
    log_info "Instance 1 port: $instance1_port"
    
    if [ -z "$instance1_port" ] || [ "$instance1_port" == "null" ]; then
        log_error "Failed to get instance port"
        return 1
    fi
    
    # Install WordPress on instance 1
    log_info "Installing WordPress on instance 1..."
    docker exec "$CONTAINER_NAME" docker exec test-low-php wp core install \
        --url="http://localhost:${instance1_port}" \
        --title="Test Instance Low" \
        --admin_user="admin" \
        --admin_password="admin123" \
        --admin_email="admin@test.local" \
        --skip-email \
        --allow-root
    
    # Wait for WordPress to be ready
    sleep 5
    
    # Test access to instance 1
    check_http_response "http://localhost:${instance1_port}" "200|302|301" "Instance 1 via localhost:${instance1_port}" || return 1
    check_http_response "http://${DIND_IP}:${instance1_port}" "200|302|301" "Instance 1 via DinD IP:${instance1_port}" || return 1
    
    # Create second instance with highest versions
    log_info "Creating instance with highest versions (PHP $max_php, MySQL $max_mysql)..."
    docker exec "$CONTAINER_NAME" /app/instance-manager.sh create test-high "$max_mysql" "$max_php" nginx
    
    # Wait for instance to be created
    sleep 10
    
    # Get instance 2 port
    local instance2_port=$(docker exec "$CONTAINER_NAME" jq -r '.instances["test-high"].port' /wordpress-instances/.workspace-config.json)
    log_info "Instance 2 port: $instance2_port"
    
    if [ -z "$instance2_port" ] || [ "$instance2_port" == "null" ]; then
        log_error "Failed to get instance 2 port"
        return 1
    fi
    
    # Verify sequential port allocation
    if [ "$instance2_port" -ne $((instance1_port + 1)) ]; then
        log_warning "Ports are not sequential: $instance1_port, $instance2_port"
    else
        log_success "Sequential port allocation verified: $instance1_port, $instance2_port"
    fi
    
    # Install WordPress on instance 2
    log_info "Installing WordPress on instance 2..."
    docker exec "$CONTAINER_NAME" docker exec test-high-php wp core install \
        --url="http://localhost:${instance2_port}" \
        --title="Test Instance High" \
        --admin_user="admin" \
        --admin_password="admin123" \
        --admin_email="admin@test.local" \
        --skip-email \
        --allow-root
    
    # Wait for WordPress to be ready
    sleep 5
    
    # Test access to instance 2
    check_http_response "http://localhost:${instance2_port}" "200|302|301" "Instance 2 via localhost:${instance2_port}" || return 1
    check_http_response "http://${DIND_IP}:${instance2_port}" "200|302|301" "Instance 2 via DinD IP:${instance2_port}" || return 1
    
    log_success "Multi-instance mode test completed successfully"
    
    # Cleanup
    log_info "Stopping multi-instance mode environment..."
    docker-compose down -v
    sleep 5
    
    return 0
}

# Main test execution
main() {
    log_section "WordPress DinD Comprehensive Test Suite"

    log_info "Test directory: $TEST_DIR"
    log_info "CLI tool: $CLI_TOOL"

    # Check prerequisites
    if ! command -v node &> /dev/null; then
        log_error "Node.js is not installed or not in PATH"
        log_error "Please install Node.js 24+ to run this test script"
        log_error "Alternatively, manually test using the commands in docs/WORKSPACE_MODES.md"
        exit 1
    fi

    if [ ! -f "$CLI_TOOL" ]; then
        log_error "CLI tool not found at $CLI_TOOL"
        exit 1
    fi
    
    # Run tests
    test_workspace_mode || log_error "Workspace mode test failed"
    test_multi_instance_mode || log_error "Multi-instance mode test failed"
    
    # Final cleanup
    cleanup
    
    # Print summary
    log_section "Test Summary"
    echo -e "${GREEN}Tests Passed: $TESTS_PASSED${NC}"
    echo -e "${RED}Tests Failed: $TESTS_FAILED${NC}"
    
    if [ $TESTS_FAILED -eq 0 ]; then
        log_success "All tests passed! 🎉"
        exit 0
    else
        log_error "Some tests failed"
        exit 1
    fi
}

# Run main function
main "$@"

