# wp-dind CLI Reference

Complete command reference for the WordPress Docker-in-Docker CLI tool.

## Table of Contents

- [Installation](#installation)
- [Quick Start](#quick-start)
- [Command Reference](#command-reference)
  - [Initialization](#initialization)
  - [Environment Management](#environment-management)
  - [WordPress Installation](#wordpress-installation)
  - [Instance Management](#instance-management)
  - [Utilities](#utilities)
- [Examples](#examples)
- [Services](#services)

## Installation

```bash
npm install -g
# or
npm link
```

## Quick Start

### Workspace Mode (Single WordPress Site)

```bash
# 1. Initialize workspace
wp-dind init
# Select "workspace" mode and choose your stack

# 2. Start environment
wp-dind start

# 3. Install WordPress
wp-dind install-wordpress

# 4. Get access URLs
wp-dind ports
```

### Multi-Instance Mode (Multiple WordPress Sites)

```bash
# 1. Initialize workspace
wp-dind init
# Select "multi-instance" mode

# 2. Start environment
wp-dind start

# 3. Create instances
wp-dind instance create mysite 80 83 nginx
wp-dind instance create legacy 57 74 apache

# 4. Get access URLs
wp-dind ports
```

## Command Reference

### Initialization

#### `wp-dind init`

Initialize a new WordPress DinD workspace in the current directory.

**Options:**
- `-d, --dir <directory>` - Target directory (default: current directory)
- `--with-phpmyadmin` - Include phpMyAdmin service
- `--with-mailcatcher` - Include MailCatcher service

**Interactive Prompts:**
- Workspace name
- Workspace type (workspace or multi-instance)
- Web server (nginx or apache) - workspace mode only
- PHP version (7.4, 8.0, 8.1, 8.2, 8.3) - workspace mode only
- MySQL version (5.6, 5.7, 8.0) - workspace mode only

**Example:**
```bash
wp-dind init
wp-dind init -d /path/to/workspace
```

---

### Environment Management

#### `wp-dind start`

Start the DinD container and all services.

**Options:**
- `-d, --dir <directory>` - Target directory (default: current directory)

**Example:**
```bash
wp-dind start
```

#### `wp-dind stop`

Stop the DinD container and all services.

**Options:**
- `-d, --dir <directory>` - Target directory (default: current directory)

**Example:**
```bash
wp-dind stop
```

#### `wp-dind status`

Check the status of all containers.

**Options:**
- `-d, --dir <directory>` - Target directory (default: current directory)

**Example:**
```bash
wp-dind status
```

#### `wp-dind ports`

List all accessible services, ports, and connection details.

**Options:**
- `-d, --dir <directory>` - Target directory (default: current directory)

**Output:**
- Core services (Docker, MySQL, phpMyAdmin, MailCatcher, Redis)
- WordPress instances with their ports
- MySQL connection credentials

**Example:**
```bash
wp-dind ports
```

#### `wp-dind ps`

List all running containers.

**Options:**
- `-d, --dir <directory>` - Target directory (default: current directory)
- `-a, --all` - Show all containers (including stopped)

**Example:**
```bash
wp-dind ps
wp-dind ps -a
```

#### `wp-dind logs`

View logs from the DinD environment.

**Options:**
- `-d, --dir <directory>` - Target directory (default: current directory)
- `-f, --follow` - Follow log output (live tail)
- `-s, --service <service>` - Show logs for specific service

**Example:**
```bash
wp-dind logs
wp-dind logs -f
wp-dind logs -s wordpress-dind
```

#### `wp-dind destroy`

Completely remove the DinD environment including all containers, volumes, and data.

**Options:**
- `-d, --dir <directory>` - Target directory (default: current directory)

**Warning:** This action cannot be undone!

**Example:**
```bash
wp-dind destroy
```

---

### WordPress Installation

#### `wp-dind install-wordpress`

Install WordPress in the workspace (data/wordpress directory). **Workspace mode only.**

**Options:**
- `-d, --dir <directory>` - Target directory (default: current directory)
- `--url <url>` - WordPress site URL (default: http://&lt;dind-ip&gt;:8000)
- `--title <title>` - Site title (default: workspace name)
- `--admin-user <username>` - Admin username (default: admin)
- `--admin-password <password>` - Admin password (default: prompted)
- `--admin-email <email>` - Admin email (default: admin@example.com)
- `--skip-install` - Download WordPress only, skip installation

**Example:**
```bash
wp-dind install-wordpress
wp-dind install-wordpress --url http://172.19.0.2:8000 --title "My Site" --admin-user admin --admin-password secret123
```

---

### Instance Management

#### `wp-dind instance create`

Create a new isolated WordPress instance. **Multi-instance mode only.**

**Syntax:**
```bash
wp-dind instance create <name> [mysql_version] [php_version] [webserver]
```

**Arguments:**
- `name` - Instance name (required)
- `mysql_version` - MySQL version: 56, 57, 80 (default: 80)
- `php_version` - PHP version: 74, 80, 81, 82, 83 (default: 83)
- `webserver` - Web server: nginx, apache (default: nginx)

**Options:**
- `-d, --dir <directory>` - Target directory (default: current directory)

**Example:**
```bash
wp-dind instance create mysite
wp-dind instance create mysite 80 83 nginx
wp-dind instance create legacy 57 74 apache
```

#### `wp-dind instance list`

List all WordPress instances with their configuration and status.

**Options:**
- `-d, --dir <directory>` - Target directory (default: current directory)

**Example:**
```bash
wp-dind instance list
```

#### `wp-dind instance info`

Show detailed information about a specific instance.

**Syntax:**
```bash
wp-dind instance info <name>
```

**Options:**
- `-d, --dir <directory>` - Target directory (default: current directory)

**Output:**
- Configuration (MySQL, PHP, web server versions)
- Port assignment
- Database credentials
- File paths

**Example:**
```bash
wp-dind instance info mysite
```

#### `wp-dind instance start`

Start a specific WordPress instance.

**Syntax:**
```bash
wp-dind instance start <name>
```

**Options:**
- `-d, --dir <directory>` - Target directory (default: current directory)

**Example:**
```bash
wp-dind instance start mysite
```

#### `wp-dind instance stop`

Stop a specific WordPress instance.

**Syntax:**
```bash
wp-dind instance stop <name>
```

**Options:**
- `-d, --dir <directory>` - Target directory (default: current directory)

**Example:**
```bash
wp-dind instance stop mysite
```

#### `wp-dind instance remove`

Remove a WordPress instance and all its data.

**Syntax:**
```bash
wp-dind instance remove <name>
```

**Options:**
- `-d, --dir <directory>` - Target directory (default: current directory)

**Example:**
```bash
wp-dind instance remove mysite
```

#### `wp-dind instance clone`

Clone an existing instance with different strategies.

**Syntax:**
```bash
wp-dind instance clone <source> <target> [strategy]
```

**Arguments:**
- `source` - Source instance name (required)
- `target` - Target instance name (required)
- `strategy` - Cloning strategy (default: symlink)
  - `symlink` - Share files, separate database
  - `copy-all` - Copy files and database
  - `copy-files` - Copy files, empty database

**Options:**
- `-d, --dir <directory>` - Target directory (default: current directory)

**Example:**
```bash
wp-dind instance clone mysite mysite-dev symlink
wp-dind instance clone mysite mysite-staging copy-all
wp-dind instance clone mysite mysite-test copy-files
```

#### `wp-dind instance logs`

View logs for a specific instance.

**Syntax:**
```bash
wp-dind instance logs <name> [service]
```

**Arguments:**
- `name` - Instance name (required)
- `service` - Service name: php, mysql, nginx, apache (default: all)

**Options:**
- `-d, --dir <directory>` - Target directory (default: current directory)

**Example:**
```bash
wp-dind instance logs mysite
wp-dind instance logs mysite php
wp-dind instance logs mysite mysql
```

---

### Utilities

#### `wp-dind exec`

Execute a command inside a specific container.

**Syntax:**
```bash
wp-dind exec <container> <command...>
```

**Arguments:**
- `container` - Container name (e.g., dind, workspace-php, mysite-php)
- `command` - Command to execute

**Options:**
- `-d, --dir <directory>` - Target directory (default: current directory)
- `-i, --interactive` - Run in interactive mode (allocate TTY)
- `-u, --user <user>` - Run as specific user (e.g., www-data, root)

**Example:**
```bash
# Execute WP-CLI command
wp-dind exec dind wp plugin list

# Access container shell
wp-dind exec -i dind bash

# Run command as www-data user
wp-dind exec -u www-data dind wp cache flush

# Execute in specific instance
wp-dind exec mysite-php php -v
```

#### `wp-dind help`

Show help for wp-dind or a specific command.

**Syntax:**
```bash
wp-dind help [command]
```

**Example:**
```bash
wp-dind help
wp-dind help init
wp-dind help instance
```

---

## Examples

### Workspace Mode Examples

**Complete workflow:**
```bash
# Initialize and configure
wp-dind init
# Select: workspace, nginx, PHP 8.3, MySQL 8.0

# Start environment
wp-dind start

# Install WordPress
wp-dind install-wordpress \
  --url http://172.19.0.2:8000 \
  --title "My Development Site" \
  --admin-user admin \
  --admin-password secret123 \
  --admin-email admin@example.com

# Check services
wp-dind ports

# Execute WP-CLI commands
wp-dind exec dind wp plugin install woocommerce --activate
wp-dind exec dind wp theme activate storefront
wp-dind exec dind wp user list

# View logs
wp-dind logs -f

# Stop when done
wp-dind stop
```

### Multi-Instance Mode Examples

**Create multiple instances with different stacks:**
```bash
# Initialize
wp-dind init
# Select: multi-instance

# Start environment
wp-dind start

# Create production-like instance (MySQL 8.0, PHP 8.3, nginx)
wp-dind instance create production 80 83 nginx

# Create staging instance (MySQL 8.0, PHP 8.2, nginx)
wp-dind instance create staging 80 82 nginx

# Create legacy instance (MySQL 5.7, PHP 7.4, apache)
wp-dind instance create legacy 57 74 apache

# List all instances
wp-dind instance list

# Get instance details
wp-dind instance info production

# Clone production to development
wp-dind instance clone production development symlink

# View all ports
wp-dind ports

# Access instances at:
# http://<dind-ip>:8001 (production)
# http://<dind-ip>:8002 (staging)
# http://<dind-ip>:8003 (legacy)
# http://<dind-ip>:8004 (development)
```

**Manage instances:**
```bash
# Stop specific instance
wp-dind instance stop staging

# Start specific instance
wp-dind instance start staging

# View instance logs
wp-dind instance logs production php

# Remove instance
wp-dind instance remove legacy
```

### Common Tasks

**Connect to MySQL:**
```bash
# Get connection details
wp-dind ports

# Connect from host machine
mysql -h <dind-ip> -P 3306 -u wordpress -pwordpress wordpress

# Or use phpMyAdmin
# Open http://<dind-ip>:8080 in browser
```

**Execute WP-CLI commands:**
```bash
# In workspace mode
wp-dind exec dind wp plugin list
wp-dind exec dind wp theme list
wp-dind exec dind wp db export /var/www/html/backup.sql

# In multi-instance mode (execute inside instance container)
docker exec wp-dind-<workspace-name> docker exec mysite-php wp plugin list
```

**Access container shells:**
```bash
# Access DinD host shell
wp-dind exec -i dind bash

# Access workspace PHP container
docker exec -it wp-dind-<workspace-name> docker exec -it workspace-php bash

# Access instance PHP container
docker exec -it wp-dind-<workspace-name> docker exec -it mysite-php bash
```

**Backup and restore:**
```bash
# Backup WordPress files
tar -czf wordpress-backup.tar.gz data/wordpress/

# Backup database
wp-dind exec dind wp db export /var/www/html/db-backup.sql

# Restore files
tar -xzf wordpress-backup.tar.gz

# Restore database
wp-dind exec dind wp db import /var/www/html/db-backup.sql
```

---

## Services

All services run inside the DinD container and are accessible via the DinD IP address.
Use `wp-dind ports` to get the DinD IP and see all available services.

### Core Services

| Service | Port | Description | Credentials |
|---------|------|-------------|-------------|
| Docker Daemon | 2375 | Docker API inside DinD | - |
| MySQL | 3306 | Database server | wordpress/wordpress |
| phpMyAdmin | 8080 | Database management | wordpress/wordpress |
| MailCatcher Web | 1080 | Email testing interface | - |
| MailCatcher SMTP | 1025 | SMTP server | - |
| Redis | 6379 | Cache server | - |
| Redis Commander | 8081 | Redis management | - |

### WordPress Access

**Workspace Mode:**
- WordPress: `http://<dind-ip>:8000`

**Multi-Instance Mode:**
- Instances: `http://<dind-ip>:8001`, `8002`, `8003`, etc.
- Use `wp-dind ports` to see all instances and their ports

### Important Notes

1. **No localhost access**: Services are NOT accessible via localhost to avoid conflicts when running multiple DinD instances
2. **DinD IP**: Each DinD instance gets its own IP address on the wp-dind network (172.19.0.0/16)
3. **Get IP**: Use `wp-dind ports` to get the exact IP address and port for each service
4. **No auto-start**: DinD containers do NOT auto-start after host reboot (restart policy: "no")
5. **Multiple instances**: You can run multiple DinD workspaces in parallel without port conflicts

### Network Architecture

```
Host Machine
  └─ wp-dind network (172.19.0.0/16)
      ├─ wp-dind-workspace1 (172.19.0.2)
      │   └─ Internal containers on wp-shared network (172.21.0.0/16)
      │       ├─ workspace-mysql (172.21.0.2)
      │       ├─ workspace-php (172.21.0.3)
      │       └─ workspace-nginx (172.21.0.4)
      │
      └─ wp-dind-workspace2 (172.19.0.3)
          └─ Internal containers on wp-shared network (172.21.0.0/16)
              ├─ workspace-mysql (172.21.0.2)
              ├─ workspace-php (172.21.0.3)
              └─ workspace-nginx (172.21.0.4)
```

---

## Troubleshooting

### Common Issues

**Port conflicts:**
```bash
# Check what's using the port
docker ps | grep wp-dind

# Stop conflicting workspace
cd /path/to/other/workspace
wp-dind stop
```

**Can't connect to services:**
```bash
# Get the correct DinD IP
wp-dind ports

# Check if containers are running
wp-dind status
wp-dind ps
```

**WordPress installation fails:**
```bash
# Check if MySQL is ready
docker exec wp-dind-<workspace-name> docker exec workspace-mysql mysqladmin ping -h localhost -u root -prootpassword

# Check logs
wp-dind logs -f
```

**Permission issues:**
```bash
# Fix file permissions
sudo chown -R $USER:$USER data/wordpress/
```

---

## Version Information

Run `wp-dind --version` to see the current version.

For more information, see the main README.md file.

