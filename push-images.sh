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
echo -e "${BLUE}WordPress Docker-in-Docker Image Pusher${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Check if logged in to Docker Hub
if ! docker info | grep -q "Username"; then
    echo -e "${YELLOW}Not logged in to Docker Hub. Please login:${NC}"
    docker login
    echo ""
fi

# Function to push an image with all its tags
push_image() {
    local service_name=$1
    local version=$2
    shift 2
    local additional_tags=("$@")

    echo -e "${GREEN}Pushing ${service_name}:${version}...${NC}"

    # Push main version tag (format: airoman/wp-dind:mysql-5.6.51)
    local hub_tag="${service_name#wp-}-${version}"
    docker push "${DOCKER_HUB_REPO}:${hub_tag}"
    echo -e "${YELLOW}  ✓ Pushed ${DOCKER_HUB_REPO}:${hub_tag}${NC}"

    # Push additional tags
    for tag in "${additional_tags[@]}"; do
        if [ -n "$tag" ]; then
            local hub_alias_tag="${service_name#wp-}-${tag}"
            docker push "${DOCKER_HUB_REPO}:${hub_alias_tag}"
            echo -e "${YELLOW}  ✓ Pushed ${DOCKER_HUB_REPO}:${hub_alias_tag}${NC}"
        fi
    done

    echo ""
}

# Push MySQL images
echo -e "${BLUE}Pushing MySQL images...${NC}"
push_image "wp-mysql" "5.6.51" "5.6"
push_image "wp-mysql" "5.7.44" "5.7"
push_image "wp-mysql" "8.0.40" "8.0"

# Push PHP images
echo -e "${BLUE}Pushing PHP-FPM images...${NC}"
push_image "wp-php" "7.4.33"
push_image "wp-php" "8.0.30"
push_image "wp-php" "8.1.31"
push_image "wp-php" "8.2.26"
push_image "wp-php" "8.3.14"
push_image "wp-php" "8.4.1"

# Push Nginx image
echo -e "${BLUE}Pushing Nginx image...${NC}"
push_image "wp-nginx" "1.27.3"

# Push Apache image
echo -e "${BLUE}Pushing Apache image...${NC}"
push_image "wp-apache" "2.4.62"

# Push phpMyAdmin image
echo -e "${BLUE}Pushing phpMyAdmin image...${NC}"
push_image "wp-phpmyadmin" "5.2.3"

# Push MailCatcher image
echo -e "${BLUE}Pushing MailCatcher image...${NC}"
push_image "wp-mailcatcher" "0.10.0"

# Push Redis image
echo -e "${BLUE}Pushing Redis image...${NC}"
push_image "wp-redis" "7.4.1" "7.4"

# Push Redis Commander image
echo -e "${BLUE}Pushing Redis Commander image...${NC}"
push_image "wp-redis-commander" "0.8.1"

# Push Docker-in-Docker image
echo -e "${BLUE}Pushing Docker-in-Docker image...${NC}"
push_image "wp-dind" "27.0.3" "27.0"

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}All images pushed successfully!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${BLUE}Images are now available at:${NC}"
echo -e "  https://hub.docker.com/r/${DOCKER_HUB_REPO}"
echo ""
echo -e "${YELLOW}To pull images from Docker Hub:${NC}"
echo -e "  docker pull ${DOCKER_HUB_REPO}:php-8.3.14"
echo -e "  docker pull ${DOCKER_HUB_REPO}:mysql-8.0.40"
echo -e "  docker pull ${DOCKER_HUB_REPO}:nginx-1.27.3"
echo ""

