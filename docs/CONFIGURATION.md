# Configuration Guide

This guide covers all configuration options for the WordPress Docker-in-Docker setup, including environment variables, configuration files, and customization options.

## Table of Contents

- [Environment Variables (.env)](#environment-variables-env)
- [Configuration Files](#configuration-files)
- [Instance-Specific Configuration](#instance-specific-configuration)
- [Advanced Configuration](#advanced-configuration)

---

## Environment Variables (.env)

The `.env` file is the central configuration point for the entire Docker-in-Docker setup. All settings can be customized by editing this file.

### Location

The `.env` file is located in the project root directory:
```
/media/aurel/72475d1d-9b90-4759-b1f8-e80488ef10d55/wordpress-docker-dind/.env
```

### Structure

The `.env` file is organized into two main sections:

1. **Docker-in-Docker Configuration** - Settings for the DinD setup (used by `docker-compose-dind.yml`)
2. **Legacy Configuration** - Settings for standalone WordPress (used by `docker-compose.yml`)

---

## Docker-in-Docker Configuration Variables

### Project Settings

```bash
# Project name used for container naming
COMPOSE_PROJECT_NAME=wordpress
```

**Usage:** Prefixes all container names and networks.

---

### File Permissions (PUID/PGID)

```bash
# User and Group IDs for file permissions
# Set these to your host user's UID/GID to allow editing WordPress files
PUID=1000
PGID=1000
```

**Purpose:** Controls file ownership for WordPress files to allow host user editing.

**How to find your UID/GID:**
```bash
# On your host machine
id -u  # Returns your user ID (PUID)
id -g  # Returns your group ID (PGID)
```

**Default Values:**
- `PUID=1000` (typical first user on Linux)
- `PGID=1000` (typical first user group on Linux)

**Important Notes:**
- WordPress files in `data/wordpress` will be owned by this UID:GID
- This allows you to edit files directly on the host without permission issues
- If not set, files will be owned by `82:82` (www-data in Alpine) and you'll need sudo to edit them
- Both the DinD container and WordPress containers inside DinD respect these values

**Example:**
```bash
# If your user ID is 1001 and group ID is 1001
PUID=1001
PGID=1001
```

After changing PUID/PGID, restart the environment:
```bash
docker-compose -f docker-compose-dind.yml down
docker-compose -f docker-compose-dind.yml up -d
```

---

### DinD Container Settings

```bash
# DinD container name
DIND_CONTAINER_NAME=wordpress-dind-host

# DinD image tag
DIND_IMAGE_TAG=latest

# Network subnet for DinD
DIND_NETWORK_SUBNET=172.19.0.0/16
```

**DIND_CONTAINER_NAME:**
- Name of the main Docker-in-Docker container
- Default: `wordpress-dind-host`
- Change if you want a different container name

**DIND_IMAGE_TAG:**
- Docker image tag for the DinD image
- Default: `latest`
- Can use specific versions like `27.0`, `26.1`, etc.

**DIND_NETWORK_SUBNET:**
- Subnet for the DinD network
- Default: `172.19.0.0/16`
- Change if it conflicts with your network

---

### Port Configuration

```bash
# Docker daemon port (exposed to host)
DOCKER_DAEMON_PORT=2375

# WordPress instance port range
WP_INSTANCE_PORT_RANGE_START=8000
WP_INSTANCE_PORT_RANGE_END=8099

# phpMyAdmin port
PHPMYADMIN_PORT=8080

# MailCatcher ports
MAIL_CATCHER_HTTP_PORT=1080
MAIL_CATCHER_SMTP_PORT=1025
```

**DOCKER_DAEMON_PORT:**
- Port for accessing the Docker daemon inside DinD
- Default: `2375`
- Used by the CLI tool to communicate with DinD

**WP_INSTANCE_PORT_RANGE_START/END:**
- Range of ports for WordPress instances
- Default: `8000-8099` (supports up to 100 instances)
- Each instance gets a unique port in this range

**PHPMYADMIN_PORT:**
- Port for accessing phpMyAdmin web interface
- Default: `8080`
- Access at: `http://localhost:8080`

**MAIL_CATCHER_HTTP_PORT:**
- Port for MailCatcher web interface
- Default: `1080`
- Access at: `http://localhost:1080`

**MAIL_CATCHER_SMTP_PORT:**
- Port for MailCatcher SMTP server
- Default: `1025`
- WordPress instances send emails to this port

---

### Default Instance Configuration

```bash
# Default MySQL version for new instances
DEFAULT_MYSQL_VERSION=80

# Default PHP version for new instances
DEFAULT_PHP_VERSION=83

# Default web server for new instances
DEFAULT_WEBSERVER=nginx

# Default database name
DEFAULT_DB_NAME=wordpress

# Default database user
DEFAULT_DB_USER=wordpress
```

**DEFAULT_MYSQL_VERSION:**
- MySQL version used when creating instances without specifying version
- Options: `56` (5.6), `57` (5.7), `80` (8.0)
- Default: `80`

**DEFAULT_PHP_VERSION:**
- PHP version used when creating instances without specifying version
- Options: `74` (7.4), `80` (8.0), `81` (8.1), `82` (8.2), `83` (8.3)
- Default: `83`

**DEFAULT_WEBSERVER:**
- Web server used when creating instances without specifying server
- Options: `nginx`, `apache`
- Default: `nginx`

**DEFAULT_DB_NAME:**
- Database name for new WordPress instances
- Default: `wordpress`
- Can be customized per instance

**DEFAULT_DB_USER:**
- Database username for new WordPress instances
- Default: `wordpress`
- Can be customized per instance

---

### WordPress Installation Defaults

```bash
# Default site title
WORDPRESS_WEBSITE_TITLE="My WordPress Site"

# Default admin username
WORDPRESS_ADMIN_USER="admin"

# Default admin password
WORDPRESS_ADMIN_PASSWORD="change-this-password"

# Default admin email
WORDPRESS_ADMIN_EMAIL="admin@example.com"

# Default WordPress locale
WORDPRESS_LOCALE=en_US
```

**WORDPRESS_WEBSITE_TITLE:**
- Default site title when installing WordPress
- Used by `install-wordpress.sh` script
- Can be changed during installation

**WORDPRESS_ADMIN_USER:**
- Default admin username
- Default: `admin`
- **Security:** Change this for production!

**WORDPRESS_ADMIN_PASSWORD:**
- Default admin password
- Default: `change-this-password`
- **Security:** Change this immediately!
- If set to default value, a random password is generated

**WORDPRESS_ADMIN_EMAIL:**
- Default admin email address
- Used for WordPress notifications
- Change to your email address

**WORDPRESS_LOCALE:**
- WordPress language/locale
- Default: `en_US` (English - United States)
- Examples: `fr_FR` (French), `de_DE` (German), `es_ES` (Spanish)
- See: https://make.wordpress.org/polyglots/teams/

---

## Configuration Files

Configuration files are stored in the `config/` directory and organized by software and version.

### Directory Structure

```
config/
├── php/
│   ├── 7.4/
│   │   ├── opcache.ini
│   │   ├── wordpress.ini
│   │   └── xdebug.ini
│   ├── 8.0/
│   ├── 8.1/
│   ├── 8.2/
│   └── 8.3/
├── mysql/
│   ├── 5.6/
│   │   └── my.cnf
│   ├── 5.7/
│   └── 8.0/
├── nginx/
│   └── 1.27/
│       └── wordpress.conf
└── apache/
    └── 2.4/
        └── wordpress.conf
```

### Configuration Layers

The system uses a **three-layer configuration approach**:

1. **Built-in Configs** - Baked into Docker images (default settings)
2. **Host Configs** - In `config/` directory (centralized, shared across instances)
3. **Instance Configs** - In `/wordpress-instances/{name}/config/` (instance-specific overrides)

**Priority:** Instance Configs > Host Configs > Built-in Configs

---

### PHP Configuration

**Location:** `config/php/{version}/`

**Files:**
- `opcache.ini` - OPcache settings for performance
- `wordpress.ini` - WordPress-specific PHP settings
- `xdebug.ini` - Xdebug configuration for debugging

**Common Settings to Customize:**

```ini
# wordpress.ini
upload_max_filesize = 64M
post_max_size = 64M
memory_limit = 256M
max_execution_time = 300
max_input_time = 300
```

**Xdebug Settings:**

```ini
# xdebug.ini
xdebug.mode = debug
xdebug.client_host = host.docker.internal
xdebug.client_port = 9003
xdebug.start_with_request = yes
```

---

### MySQL Configuration

**Location:** `config/mysql/{version}/`

**File:** `my.cnf`

**Common Settings to Customize:**

```ini
[mysqld]
max_allowed_packet = 64M
innodb_buffer_pool_size = 256M
innodb_log_file_size = 64M
```

---

### Nginx Configuration

**Location:** `config/nginx/1.27/`

**File:** `wordpress.conf`

**Common Settings to Customize:**

```nginx
# Increase upload size
client_max_body_size 64M;

# Enable gzip compression
gzip on;
gzip_types text/plain text/css application/json application/javascript;

# Cache static files
location ~* \.(jpg|jpeg|png|gif|ico|css|js)$ {
    expires 1y;
    add_header Cache-Control "public, immutable";
}
```

---

### Apache Configuration

**Location:** `config/apache/2.4/`

**File:** `wordpress.conf`

**Common Settings to Customize:**

```apache
# Increase upload size
php_value upload_max_filesize 64M
php_value post_max_size 64M

# Enable compression
<IfModule mod_deflate.c>
    AddOutputFilterByType DEFLATE text/html text/plain text/xml text/css application/javascript
</IfModule>
```

---

## Instance-Specific Configuration

Each WordPress instance can have its own configuration overrides.

### Location

Instance configs are stored in:
```
/wordpress-instances/{instance-name}/config/
```

### Structure

```
/wordpress-instances/mysite/
├── config/
│   ├── php/
│   │   └── custom.ini
│   ├── mysql/
│   │   └── custom.cnf
│   └── nginx/  (or apache/)
│       └── custom.conf
├── data/
│   └── wordpress/
├── docker-compose.yml
└── logs/
```

### Creating Instance-Specific Configs

1. **Create the config directory:**
   ```bash
   mkdir -p /wordpress-instances/mysite/config/php
   ```

2. **Add custom configuration:**
   ```bash
   cat > /wordpress-instances/mysite/config/php/custom.ini << EOF
   memory_limit = 512M
   max_execution_time = 600
   EOF
   ```

3. **Restart the instance:**
   ```bash
   wp-dind restart mysite
   ```

---

## Advanced Configuration

### Changing Ports

To change the default ports, edit `.env`:

```bash
# Use different ports
PHPMYADMIN_PORT=9080
MAIL_CATCHER_HTTP_PORT=2080
WP_INSTANCE_PORT_RANGE_START=9000
WP_INSTANCE_PORT_RANGE_END=9099
```

Then restart the DinD container:

```bash
docker-compose -f docker-compose-dind.yml down
docker-compose -f docker-compose-dind.yml up -d
```

### Changing Default Versions

To change default PHP/MySQL versions for new instances:

```bash
# Edit .env
DEFAULT_MYSQL_VERSION=57
DEFAULT_PHP_VERSION=81
DEFAULT_WEBSERVER=apache
```

Rebuild the DinD image:

```bash
./build-images.sh
docker-compose -f docker-compose-dind.yml up -d
```

### Network Configuration

To change the DinD network subnet:

```bash
# Edit .env
DIND_NETWORK_SUBNET=172.20.0.0/16
```

Restart the DinD container:

```bash
docker-compose -f docker-compose-dind.yml down
docker-compose -f docker-compose-dind.yml up -d
```

---

## Environment Variable Reference

### Quick Reference Table

| Variable | Default | Description |
|----------|---------|-------------|
| `COMPOSE_PROJECT_NAME` | `wordpress` | Project name prefix |
| `DIND_CONTAINER_NAME` | `wordpress-dind-host` | DinD container name |
| `DIND_IMAGE_TAG` | `latest` | DinD image tag |
| `DIND_NETWORK_SUBNET` | `172.19.0.0/16` | Network subnet |
| `DOCKER_DAEMON_PORT` | `2375` | Docker daemon port |
| `WP_INSTANCE_PORT_RANGE_START` | `8000` | Instance port range start |
| `WP_INSTANCE_PORT_RANGE_END` | `8099` | Instance port range end |
| `PHPMYADMIN_PORT` | `8080` | phpMyAdmin port |
| `MAIL_CATCHER_HTTP_PORT` | `1080` | MailCatcher web port |
| `MAIL_CATCHER_SMTP_PORT` | `1025` | MailCatcher SMTP port |
| `DEFAULT_MYSQL_VERSION` | `80` | Default MySQL version |
| `DEFAULT_PHP_VERSION` | `83` | Default PHP version |
| `DEFAULT_WEBSERVER` | `nginx` | Default web server |
| `DEFAULT_DB_NAME` | `wordpress` | Default database name |
| `DEFAULT_DB_USER` | `wordpress` | Default database user |
| `WORDPRESS_WEBSITE_TITLE` | `My WordPress Site` | Default site title |
| `WORDPRESS_ADMIN_USER` | `admin` | Default admin username |
| `WORDPRESS_ADMIN_PASSWORD` | `change-this-password` | Default admin password |
| `WORDPRESS_ADMIN_EMAIL` | `admin@example.com` | Default admin email |
| `WORDPRESS_LOCALE` | `en_US` | Default WordPress locale |

---

## Best Practices

### Security

1. **Change default passwords** in `.env` before deploying
2. **Use strong passwords** for `WORDPRESS_ADMIN_PASSWORD`
3. **Change default admin username** from `admin`
4. **Restrict port access** using firewall rules
5. **Use HTTPS** in production environments

### Performance

1. **Adjust PHP memory limits** based on your needs
2. **Configure OPcache** for better PHP performance
3. **Tune MySQL settings** for your workload
4. **Enable caching** in Nginx/Apache configs

### Maintenance

1. **Keep `.env` file secure** - don't commit to version control
2. **Document custom changes** in instance configs
3. **Backup configuration files** regularly
4. **Test changes** in development before production

---

## See Also

- [Quick Reference](QUICK_REFERENCE.md) - Command quick reference
- [Usage Guide](USAGE.md) - Detailed usage examples
- [Troubleshooting](TROUBLESHOOTING.md) - Common issues and solutions
- [Architecture](ARCHITECTURE.md) - System architecture details

