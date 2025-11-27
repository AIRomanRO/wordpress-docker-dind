#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Docker Hub repository
DOCKER_HUB_REPO="airoman/wp-dind"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}WordPress Docker-in-Docker Image Builder${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Function to build an image with semantic versioning tags
build_image() {
    local context=$1
    local service_name=$2
    local version=$3
    local additional_tags=("${@:4}")

    # Construct image names
    local local_image="${service_name}:${version}"
    # For Docker Hub: airoman/wp-dind:mysql-5.6.51 format
    local hub_tag="${service_name#wp-}-${version}"
    local hub_image="${DOCKER_HUB_REPO}:${hub_tag}"

    echo -e "${GREEN}Building ${service_name}:${version}...${NC}"

    # Build the image with local tag
    docker build -t "${local_image}" "$context"

    # Tag for Docker Hub
    docker tag "${local_image}" "${hub_image}"
    echo -e "${YELLOW}  Tagged as ${hub_image}${NC}"

    # Add any additional semantic version tags (no 'latest')
    for tag in "${additional_tags[@]}"; do
        if [ -n "$tag" ]; then
            local local_tag="${service_name}:${tag}"
            local hub_alias_tag="${service_name#wp-}-${tag}"
            local hub_alias="${DOCKER_HUB_REPO}:${hub_alias_tag}"

            docker tag "${local_image}" "${local_tag}"
            docker tag "${local_image}" "${hub_alias}"
            echo -e "${YELLOW}  Tagged as ${local_tag} and ${hub_alias}${NC}"
        fi
    done

    echo -e "${GREEN}  ✓ ${service_name}:${version} built successfully${NC}"
    echo ""
}

# Build MySQL images
echo -e "${BLUE}Building MySQL images...${NC}"
build_image "./images/MySQL/56" "wp-mysql" "5.6.51" "5.6"
build_image "./images/MySQL/57" "wp-mysql" "5.7.44" "5.7"
build_image "./images/MySQL/80" "wp-mysql" "8.0.40" "8.0"

# Build PHP images
echo -e "${BLUE}Building PHP-FPM images...${NC}"
build_image "./images/php/7.4" "wp-php" "7.4.33"
build_image "./images/php/8.0" "wp-php" "8.0.30"
build_image "./images/php/8.1" "wp-php" "8.1.31"
build_image "./images/php/8.2" "wp-php" "8.2.26"
build_image "./images/php/8.3" "wp-php" "8.3.14"
build_image "./images/php/8.4" "wp-php" "8.4.1"

# Build Nginx image
echo -e "${BLUE}Building Nginx image...${NC}"
build_image "./images/nginx" "wp-nginx" "1.27.3"

# Build Apache image
echo -e "${BLUE}Building Apache image...${NC}"
build_image "./images/apache" "wp-apache" "2.4.62"

# Build phpMyAdmin image
echo -e "${BLUE}Building phpMyAdmin image...${NC}"
build_image "./images/phpMyAdmin" "wp-phpmyadmin" "5.2.3"

# Build MailCatcher image
echo -e "${BLUE}Building MailCatcher image...${NC}"
build_image "./images/mailCatcher" "wp-mailcatcher" "0.10.0"

# Build Redis image
echo -e "${BLUE}Building Redis image...${NC}"
build_image "./images/redis" "wp-redis" "7.4.1" "7.4"

# Build Redis Commander image
echo -e "${BLUE}Building Redis Commander image...${NC}"
build_image "./images/redis-commander" "wp-redis-commander" "0.8.1"

# Build Docker-in-Docker image
echo -e "${BLUE}Building Docker-in-Docker image...${NC}"
build_image "./images/docker-dind-wp" "wp-dind" "27.0.3" "27.0"

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}All images built successfully!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${YELLOW}Local images:${NC}"
docker images | grep -E "^wp-mysql|^wp-php|^wp-nginx|^wp-apache|^wp-phpmyadmin|^wp-mailcatcher|^wp-redis|^wp-dind" | sort

echo ""
echo -e "${YELLOW}Docker Hub images (${DOCKER_HUB_REPO}):${NC}"
docker images | grep "${DOCKER_HUB_REPO}" | sort

echo ""
echo -e "${BLUE}Image Summary (Semantic Versioning):${NC}"
echo -e "  ${GREEN}MySQL:${NC}"
echo -e "    • ${DOCKER_HUB_REPO}:mysql-5.6.51, ${DOCKER_HUB_REPO}:mysql-5.6"
echo -e "    • ${DOCKER_HUB_REPO}:mysql-5.7.44, ${DOCKER_HUB_REPO}:mysql-5.7"
echo -e "    • ${DOCKER_HUB_REPO}:mysql-8.0.40, ${DOCKER_HUB_REPO}:mysql-8.0"
echo ""
echo -e "  ${GREEN}PHP-FPM:${NC}"
echo -e "    • ${DOCKER_HUB_REPO}:php-7.4.33"
echo -e "    • ${DOCKER_HUB_REPO}:php-8.0.30"
echo -e "    • ${DOCKER_HUB_REPO}:php-8.1.31"
echo -e "    • ${DOCKER_HUB_REPO}:php-8.2.26"
echo -e "    • ${DOCKER_HUB_REPO}:php-8.3.14"
echo -e "    • ${DOCKER_HUB_REPO}:php-8.4.1"
echo ""
echo -e "  ${GREEN}Web Servers:${NC}"
echo -e "    • ${DOCKER_HUB_REPO}:nginx-1.27.3"
echo -e "    • ${DOCKER_HUB_REPO}:apache-2.4.62"
echo ""
echo -e "  ${GREEN}Services:${NC}"
echo -e "    • ${DOCKER_HUB_REPO}:phpmyadmin-5.2.3"
echo -e "    • ${DOCKER_HUB_REPO}:mailcatcher-0.10.0"
echo -e "    • ${DOCKER_HUB_REPO}:redis-7.4.1, ${DOCKER_HUB_REPO}:redis-7.4"
echo -e "    • ${DOCKER_HUB_REPO}:redis-commander-0.8.1"
echo ""
echo -e "  ${GREEN}DinD:${NC}"
echo -e "    • ${DOCKER_HUB_REPO}:dind-27.0.3, ${DOCKER_HUB_REPO}:dind-27.0"
echo ""
echo -e "${BLUE}Next steps:${NC}"
echo -e "  ${YELLOW}1.${NC} Push images to Docker Hub: ${GREEN}npm run push:images${NC}"
echo -e "  ${YELLOW}2.${NC} Start the environment: ${GREEN}npm start${NC}"
echo ""

