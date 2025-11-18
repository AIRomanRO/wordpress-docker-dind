#!/bin/bash
set -e

echo "Starting Docker-in-Docker WordPress Environment..."

# Handle PUID/PGID for file permissions
PUID=${PUID:-82}  # Default to www-data (82) in Alpine
PGID=${PGID:-82}

echo "Setting up user permissions (PUID=${PUID}, PGID=${PGID})..."

# Create or modify wpuser group and user to match host UID/GID
if ! getent group wpuser >/dev/null 2>&1; then
    addgroup -g ${PGID} wpuser 2>/dev/null || echo "Group ${PGID} already exists"
else
    # Modify existing group
    delgroup wpuser 2>/dev/null || true
    addgroup -g ${PGID} wpuser 2>/dev/null || echo "Group ${PGID} already exists"
fi

if ! getent passwd wpuser >/dev/null 2>&1; then
    adduser -D -u ${PUID} -G wpuser -s /bin/bash wpuser 2>/dev/null || echo "User ${PUID} already exists"
else
    # Modify existing user
    deluser wpuser 2>/dev/null || true
    adduser -D -u ${PUID} -G wpuser -s /bin/bash wpuser 2>/dev/null || echo "User ${PUID} already exists"
fi

# Export PUID/PGID for use in other scripts
export PUID
export PGID

# Start supervisord in the background to manage all services
/usr/bin/supervisord -c /etc/supervisord.conf &
SUPERVISOR_PID=$!

# Wait for Docker daemon to be ready
echo "Waiting for Docker daemon to start..."
timeout=60
counter=0
until docker info >/dev/null 2>&1; do
    sleep 1
    counter=$((counter + 1))
    if [ $counter -ge $timeout ]; then
        echo "ERROR: Docker daemon failed to start within ${timeout} seconds"
        exit 1
    fi
done

echo "Docker daemon is ready!"

# Wait for PHP-FPM to be ready
echo "Waiting for PHP-FPM to start..."
timeout=30
counter=0
until nc -z 127.0.0.1 9000 >/dev/null 2>&1; do
    sleep 1
    counter=$((counter + 1))
    if [ $counter -ge $timeout ]; then
        echo "WARNING: PHP-FPM may not have started properly"
        break
    fi
done

echo "PHP-FPM is ready!"

# Wait for Nginx to be ready
echo "Waiting for Nginx to start..."
timeout=30
counter=0
until nc -z 127.0.0.1 8080 >/dev/null 2>&1; do
    sleep 1
    counter=$((counter + 1))
    if [ $counter -ge $timeout ]; then
        echo "WARNING: Nginx may not have started properly"
        break
    fi
done

echo "Nginx is ready!"

# Wait for MailCatcher to be ready
echo "Waiting for MailCatcher to start..."
timeout=30
counter=0
until nc -z 127.0.0.1 1080 >/dev/null 2>&1; do
    sleep 1
    counter=$((counter + 1))
    if [ $counter -ge $timeout ]; then
        echo "WARNING: MailCatcher may not have started properly"
        break
    fi
done

echo "MailCatcher is ready!"

# Wait for Redis to be ready
echo "Waiting for Redis to start..."
timeout=30
counter=0
until nc -z 127.0.0.1 6379 >/dev/null 2>&1; do
    sleep 1
    counter=$((counter + 1))
    if [ $counter -ge $timeout ]; then
        echo "WARNING: Redis may not have started properly"
        break
    fi
done

echo "Redis is ready!"

# Wait for Redis Commander to be ready
echo "Waiting for Redis Commander to start..."
timeout=30
counter=0
until nc -z 127.0.0.1 8081 >/dev/null 2>&1; do
    sleep 1
    counter=$((counter + 1))
    if [ $counter -ge $timeout ]; then
        echo "WARNING: Redis Commander may not have started properly"
        break
    fi
done

echo "Redis Commander is ready!"

# Setup network isolation if enabled
if [ "${ENABLE_NETWORK_ISOLATION}" = "true" ]; then
    echo "Setting up network isolation..."
    /app/network-setup.sh
fi

# Load shared images from host if volume is mounted
if [ -d "/shared-images" ] && [ "$(ls -A /shared-images 2>/dev/null)" ]; then
    echo "Loading shared images from host..."
    for image_tar in /shared-images/*.tar; do
        if [ -f "$image_tar" ]; then
            echo "Loading $(basename $image_tar)..."
            docker load -i "$image_tar" || echo "Warning: Failed to load $image_tar"
        fi
    done
fi

# Pull WordPress and related images if not present
echo "Ensuring WordPress images are available..."
images=(
    "wordpress:latest"
    "wordpress:php8.3"
    "wordpress:php8.2"
)

for img in "${images[@]}"; do
    if ! docker image inspect "$img" >/dev/null 2>&1; then
        echo "Pulling $img..."
        docker pull "$img" || echo "Warning: Failed to pull $img"
    fi
done

echo "Docker-in-Docker WordPress environment is ready!"
echo ""
echo "Services running:"
echo "  - Docker daemon (port 2375)"
echo "  - phpMyAdmin (port 8080) - http://localhost:8080"
echo "  - MailHog Web UI (port 1080) - http://localhost:1080"
echo "  - MailHog SMTP (port 1025)"
echo "  - Redis (port 6379)"
echo "  - Redis Commander (port 8081) - http://localhost:8081 (admin/admin)"
echo ""

# Start workspace if in workspace mode
if [ "${WORKSPACE_TYPE}" = "workspace" ]; then
    echo "Workspace mode detected, starting workspace..."
    /app/workspace-manager.sh start || echo "Warning: Failed to start workspace"
fi

echo "Available commands:"
echo "  - docker ps                    : List running containers"
echo "  - /app/instance-manager.sh     : Manage WordPress instances"
echo "  - /app/workspace-manager.sh    : Manage workspace mode"
echo ""

# Keep the container running by waiting for supervisord
wait $SUPERVISOR_PID

