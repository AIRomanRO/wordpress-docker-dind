#!/bin/sh
set -e

# If host config directory is mounted, copy configs from there
# This allows editing configs on the host and restarting the container to apply changes
if [ -d "/host-php-config" ] && [ "$(ls -A /host-php-config 2>/dev/null)" ]; then
    echo "Copying PHP configuration from host..."
    cp -f /host-php-config/*.ini /usr/local/etc/php/conf.d/ 2>/dev/null || true
fi

# Execute the main command
exec "$@"
