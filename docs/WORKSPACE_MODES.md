# Workspace Modes Guide

## Overview

The WordPress Docker-in-Docker environment supports two distinct operational modes to fit different development workflows:

1. **Workspace Mode** - Single WordPress installation with selected stack
2. **Multi-Instance Mode** - Multiple isolated WordPress instances for testing

## Choosing a Mode

During initialization (`wp-dind init`), you'll be asked to choose your workspace type:

```bash
? Workspace type:
  ❯ workspace      - Single WordPress site with selected stack
    multi-instance - Multiple WordPress sites for testing different stacks
```

---

## Workspace Mode

### What is it?

Workspace Mode provides a single WordPress installation running inside the DinD container with your chosen technology stack.

### When to use it?

- Developing a single WordPress project
- Need a consistent, simple development environment
- Want direct file access (files in `data/wordpress`)
- Don't need to test across multiple PHP/MySQL versions

### Features

- **Single Stack Selection**: Choose webserver (nginx/apache), PHP version, and MySQL version at initialization
- **Fixed Port**: Always accessible on port 8000
- **Direct File Access**: WordPress files in `data/wordpress` are directly editable on host
- **Automatic Startup**: Workspace containers start automatically when DinD starts
- **Shared Services**: Access to phpMyAdmin, MailHog, Redis, Redis Commander

### Architecture

```
DinD Container (172.19.0.2)
├─ Port 8000 → Workspace WordPress
├─ wp-shared network (172.21.0.0/16)
│   ├─ workspace-mysql (MySQL container)
│   ├─ workspace-php (PHP-FPM container)
│   ├─ workspace-nginx/apache (Web server)
│   └─ Shared services (phpMyAdmin, MailHog, Redis, etc.)
└─ /var/www/html → mounted from host's data/wordpress
```

### Usage

#### Initialize Workspace Mode

```bash
cd /path/to/project
wp-dind init

? Workspace name: my-project
? Workspace type: workspace
? Web server: nginx
? PHP version: 8.3
? MySQL version: 8.0
```

#### Start DinD

```bash
wp-dind start
```

The workspace containers will start automatically.

#### Install WordPress

```bash
wp-dind install-wordpress

# Or with options:
wp-dind install-wordpress \
  --url http://localhost:8000 \
  --title "My Site" \
  --admin-user admin \
  --admin-password secret \
  --admin-email admin@example.com
```

#### Access WordPress

- **Via localhost**: http://localhost:8000
- **Via DinD IP**: http://172.19.0.2:8000

#### Manage Workspace

```bash
# Check workspace status
docker exec wp-dind-<workspace-name> /app/workspace-manager.sh status

# Stop workspace containers
docker exec wp-dind-<workspace-name> /app/workspace-manager.sh stop

# Start workspace containers
docker exec wp-dind-<workspace-name> /app/workspace-manager.sh start
```

---

## Multi-Instance Mode

### What is it?

Multi-Instance Mode allows you to create multiple isolated WordPress instances, each with its own technology stack, running inside the same DinD container.

### When to use it?

- Testing plugin/theme compatibility across PHP versions
- Testing database migrations across MySQL versions
- Comparing nginx vs apache performance
- Need multiple isolated WordPress installations
- Want to clone instances for testing

### Features

- **Multiple Stacks**: Each instance can have different PHP, MySQL, and webserver versions
- **Sequential Ports**: Instances get persistent ports (8001, 8002, 8003, etc.)
- **Network Isolation**: Each instance has its own isolated network + access to shared services
- **Instance Cloning**: Clone instances with different strategies (symlink, copy-all, copy-files)
- **Persistent Configuration**: Instance ports and configs survive DinD restarts

### Architecture

```
DinD Container (172.19.0.2)
├─ Ports 8001-8020 → Instance WordPress sites
├─ wp-shared network (172.21.0.0/16)
│   └─ Shared services (phpMyAdmin, MailHog, Redis, etc.)
├─ wp-network-1 (172.20.1.0/24)
│   ├─ instance1-mysql
│   ├─ instance1-php
│   └─ instance1-nginx (also connected to wp-shared)
├─ wp-network-2 (172.20.2.0/24)
│   ├─ instance2-mysql
│   ├─ instance2-php
│   └─ instance2-apache (also connected to wp-shared)
└─ /wordpress-instances/
    ├─ instance1/
    │   ├─ data/wordpress/
    │   ├─ data/mysql/
    │   ├─ config/
    │   └─ docker-compose.yml
    └─ instance2/
        ├─ data/wordpress/
        ├─ data/mysql/
        ├─ config/
        └─ docker-compose.yml
```

### Usage

#### Initialize Multi-Instance Mode

```bash
cd /path/to/project
wp-dind init

? Workspace name: my-project
? Workspace type: multi-instance
```

#### Start DinD

```bash
wp-dind start
```

#### Create Instances

```bash
# Create instance with PHP 8.3, MySQL 8.0, nginx
docker exec wp-dind-my-project /app/instance-manager.sh create test1 80 83 nginx

# Create instance with PHP 7.4, MySQL 5.7, apache
docker exec wp-dind-my-project /app/instance-manager.sh create test2 57 74 apache

# Create instance with defaults
docker exec wp-dind-my-project /app/instance-manager.sh create test3
```

**Parameters:**
- `<name>`: Instance name (required)
- `[mysql_version]`: 56, 57, 80 (default: 80)
- `[php_version]`: 74, 80, 81, 82, 83 (default: 83)
- `[webserver]`: nginx, apache (default: nginx)

#### List Instances

```bash
docker exec wp-dind-my-project /app/instance-manager.sh list
```

#### Get Instance Info

```bash
docker exec wp-dind-my-project /app/instance-manager.sh info test1
```

This shows:
- Instance configuration (PHP, MySQL, webserver versions)
- Port assignment
- Database credentials
- Access URLs
- Container status

#### Access Instances

Each instance gets a sequential port starting from 8001:

- **Instance 1**: http://localhost:8001 or http://172.19.0.2:8001
- **Instance 2**: http://localhost:8002 or http://172.19.0.2:8002
- **Instance 3**: http://localhost:8003 or http://172.19.0.2:8003

#### Clone Instances

Clone an existing instance with different strategies:

```bash
# Symlink strategy (default) - shared files, separate database
docker exec wp-dind-my-project /app/instance-manager.sh clone test1 test1-clone symlink

# Copy-all strategy - copy files + database
docker exec wp-dind-my-project /app/instance-manager.sh clone test1 test1-full copy-all

# Copy-files strategy - copy files, empty database
docker exec wp-dind-my-project /app/instance-manager.sh clone test1 test1-fresh copy-files
```

**Clone Strategies:**
- **symlink** (default): WordPress files are symlinked (shared), database is separate. Changes to files affect both instances.
- **copy-all**: Complete copy of files and database. Fully independent instance.
- **copy-files**: Copy files only, empty database. Good for fresh installs with same codebase.

#### Manage Instances

```bash
# Start instance
docker exec wp-dind-my-project /app/instance-manager.sh start test1

# Stop instance
docker exec wp-dind-my-project /app/instance-manager.sh stop test1

# View logs
docker exec wp-dind-my-project /app/instance-manager.sh logs test1
docker exec wp-dind-my-project /app/instance-manager.sh logs test1 php

# Remove instance
docker exec wp-dind-my-project /app/instance-manager.sh remove test1
```

---

## Comparison

| Feature | Workspace Mode | Multi-Instance Mode |
|---------|---------------|---------------------|
| **WordPress Sites** | 1 | Multiple |
| **Stack Selection** | At initialization | Per instance |
| **Port** | 8000 (fixed) | 8001+ (sequential) |
| **File Location** | `data/wordpress` | `wordpress-instances/<name>/data/wordpress` |
| **Use Case** | Single project development | Testing across versions |
| **Complexity** | Simple | Advanced |
| **Instance Cloning** | N/A | Yes (3 strategies) |
| **Auto-start** | Yes (with DinD) | No (manual start) |

---

## Switching Modes

To switch from one mode to another, you need to reinitialize the workspace:

```bash
# Stop and remove current environment
wp-dind stop
wp-dind destroy

# Reinitialize with different mode
wp-dind init
# Choose different workspace type

# Start new environment
wp-dind start
```

**Warning**: This will remove all data. Backup your WordPress files and databases before switching modes.

---

## Best Practices

### Workspace Mode

1. **Commit your stack choice**: Document your chosen PHP/MySQL/webserver versions in your project README
2. **Use version control**: Keep `data/wordpress` in version control (excluding `wp-content/uploads`)
3. **Regular backups**: Backup your database regularly using phpMyAdmin or mysqldump

### Multi-Instance Mode

1. **Name instances clearly**: Use descriptive names like `php74-test`, `mysql57-compat`, etc.
2. **Document instance purposes**: Keep a list of what each instance is testing
3. **Clean up unused instances**: Remove instances you're no longer using to save resources
4. **Use cloning wisely**: Symlink strategy is fastest but changes affect both instances

---

## Troubleshooting

### Workspace Mode

**Problem**: Workspace containers not starting

```bash
# Check workspace status
docker exec wp-dind-<name> /app/workspace-manager.sh status

# Check logs
docker logs wp-dind-<name>

# Manually start workspace
docker exec wp-dind-<name> /app/workspace-manager.sh start
```

**Problem**: Port 8000 not accessible

```bash
# Check if port is exposed
docker port wp-dind-<name>

# Check if nginx is running
docker exec wp-dind-<name> docker ps | grep workspace-nginx
```

### Multi-Instance Mode

**Problem**: Instance port not accessible

```bash
# Get instance info to see assigned port
docker exec wp-dind-<name> /app/instance-manager.sh info <instance-name>

# Check if instance is running
docker exec wp-dind-<name> docker ps | grep <instance-name>
```

**Problem**: Instance won't start after DinD restart

Currently, instances need to be manually started after DinD restart. This is a known limitation and will be addressed in a future update.

```bash
# Start instance manually
docker exec wp-dind-<name> /app/instance-manager.sh start <instance-name>
```

---

## See Also

- [Main README](../README.md) - General setup and usage
- [Architecture Documentation](./ARCHITECTURE.md) - Detailed architecture information
- [CLI Tool Documentation](../cli-tool/README.md) - CLI command reference

