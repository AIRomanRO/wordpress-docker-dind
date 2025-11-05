# Troubleshooting Guide

This guide helps you diagnose and resolve common issues with the WordPress Docker-in-Docker environment.

## General Troubleshooting Steps

1. **Check Docker status**: `docker info`
2. **Check container status**: `docker ps -a`
3. **View logs**: `docker logs <container-name>`
4. **Check resources**: `docker system df`
5. **Verify network**: `docker network ls`

## Common Issues

### 1. DinD Container Won't Start

#### Symptoms
- Container exits immediately after starting
- "Cannot connect to Docker daemon" error
- Container status shows "Exited (1)"

#### Diagnosis

```bash
# Check container logs
docker logs wordpress-dind-host

# Check if privileged mode is enabled
docker inspect wordpress-dind-host | grep Privileged

# Check system resources
docker system df
df -h
```

#### Solutions

**Solution 1: Ensure Privileged Mode**

Edit `docker-compose.yml`:
```yaml
services:
  wordpress-dind:
    privileged: true  # Must be true
```

**Solution 2: Check Disk Space**

```bash
# Clean up Docker
docker system prune -a

# Remove unused volumes
docker volume prune
```

**Solution 3: Increase Resources**

For Docker Desktop:
- Settings → Resources → Advanced
- Increase CPU and Memory allocation

**Solution 4: Check AppArmor/SELinux**

```bash
# Temporarily disable AppArmor (Ubuntu)
sudo systemctl stop apparmor

# Temporarily disable SELinux (RHEL/CentOS)
sudo setenforce 0
```

### 2. WordPress Instance Creation Fails

#### Symptoms
- "Network already exists" error
- "Cannot create container" error
- Instance directory created but containers not running

#### Diagnosis

```bash
# Check available networks
wp-dind exec docker network ls

# Check if instance directory exists
wp-dind exec ls -la /wordpress-instances/

# Check Docker daemon inside DinD
wp-dind exec docker info
```

#### Solutions

**Solution 1: Clean Up Existing Networks**

```bash
# Remove unused networks
wp-dind exec docker network prune

# Remove specific network
wp-dind exec docker network rm wp-network-1
```

**Solution 2: Check Instance Name**

```bash
# List existing instances
wp-dind exec instance-manager.sh list

# Use a different name
wp-dind exec instance-manager.sh create mysite2 80
```

**Solution 3: Verify Docker Daemon**

```bash
# Restart DinD container
docker-compose restart wordpress-dind

# Wait for Docker daemon to be ready
docker logs -f wordpress-dind-host
```

### 3. Cannot Access WordPress Site

#### Symptoms
- Browser shows "Connection refused"
- "This site can't be reached" error
- Timeout when accessing URL

#### Diagnosis

```bash
# Check if containers are running
wp-dind exec docker ps

# Check port mapping
wp-dind exec docker port mysite-nginx 80

# Check nginx logs
wp-dind exec docker logs mysite-nginx

# Test from inside DinD
wp-dind exec curl http://mysite-nginx
```

#### Solutions

**Solution 1: Verify Port Mapping**

```bash
# Get instance info
wp-dind exec instance-manager.sh info mysite

# Access using the correct port
# Example: http://localhost:8001
```

**Solution 2: Check Nginx Configuration**

```bash
# View nginx config
wp-dind exec cat /wordpress-instances/mysite/nginx/conf.d/wordpress.conf

# Test nginx config
wp-dind exec docker exec mysite-nginx nginx -t

# Reload nginx
wp-dind exec docker exec mysite-nginx nginx -s reload
```

**Solution 3: Check Firewall**

```bash
# Check if port is open (Linux)
sudo iptables -L -n | grep 8001

# Allow port through firewall
sudo ufw allow 8001
```

### 4. Database Connection Errors

#### Symptoms
- "Error establishing database connection"
- WordPress shows database error page
- MySQL container not running

#### Diagnosis

```bash
# Check MySQL container status
wp-dind exec docker ps | grep mysql

# Check MySQL logs
wp-dind exec docker logs mysite-mysql

# Test MySQL connection
wp-dind exec docker exec mysite-mysql \
  mysql -u wordpress -p wordpress -e "SELECT 1"
```

#### Solutions

**Solution 1: Verify Database Credentials**

```bash
# Get correct credentials
wp-dind exec instance-manager.sh info mysite

# Update wp-config.php if needed
wp-dind exec vi /wordpress-instances/mysite/wordpress/wp-config.php
```

**Solution 2: Restart MySQL Container**

```bash
# Restart MySQL
wp-dind exec docker restart mysite-mysql

# Wait for MySQL to be ready
wp-dind exec docker logs -f mysite-mysql
```

**Solution 3: Check MySQL Data Directory**

```bash
# Check permissions
wp-dind exec ls -la /wordpress-instances/mysite/mysql/

# Fix permissions if needed
wp-dind exec chown -R 999:999 /wordpress-instances/mysite/mysql/
```

### 5. phpMyAdmin Cannot Connect

#### Symptoms
- "Cannot connect to MySQL server" error
- Login fails with correct credentials
- phpMyAdmin shows blank page

#### Diagnosis

```bash
# Check phpMyAdmin logs
docker logs wordpress-phpmyadmin

# Check if phpMyAdmin can reach MySQL
docker exec wordpress-phpmyadmin ping mysite-mysql
```

#### Solutions

**Solution 1: Use Correct Server Name**

In phpMyAdmin login:
- Server: `mysite-mysql` (container name)
- Username: `wordpress` or `root`
- Password: (from instance info)

**Solution 2: Connect phpMyAdmin to Instance Network**

```bash
# Connect phpMyAdmin to instance network
docker network connect wp-network-1 wordpress-phpmyadmin

# Disconnect when done
docker network disconnect wp-network-1 wordpress-phpmyadmin
```

**Solution 3: Use Docker Exec**

```bash
# Access MySQL directly
wp-dind exec docker exec -it mysite-mysql \
  mysql -u root -p
```

### 6. MailCatcher Not Receiving Emails

#### Symptoms
- No emails appear in MailCatcher
- WordPress sends emails but they're not caught
- SMTP connection errors

#### Diagnosis

```bash
# Check MailCatcher logs
docker logs wordpress-mailcatcher

# Test SMTP connection
telnet localhost 1025

# Check if WordPress can reach MailCatcher
wp-dind exec docker exec mysite-wordpress ping mailcatcher
```

#### Solutions

**Solution 1: Configure WordPress SMTP**

Install WP Mail SMTP plugin and configure:
- SMTP Host: `mailcatcher`
- SMTP Port: `1025`
- Encryption: None
- Authentication: None

**Solution 2: Connect to Shared Network**

```bash
# Connect WordPress to DinD network
docker network connect wp-dind mysite-wordpress
```

**Solution 3: Use wp-config.php**

Add to `wp-config.php`:
```php
define('SMTP_HOST', 'mailcatcher');
define('SMTP_PORT', 1025);
```

### 7. CLI Tool Not Found

#### Symptoms
- `wp-dind: command not found`
- CLI tool installed but not accessible

#### Diagnosis

```bash
# Check if installed
npm list -g wp-dind-cli

# Check npm global bin path
npm config get prefix

# Check PATH
echo $PATH
```

#### Solutions

**Solution 1: Add npm to PATH**

```bash
# Add to ~/.bashrc or ~/.zshrc
export PATH="$(npm config get prefix)/bin:$PATH"

# Reload shell
source ~/.bashrc
```

**Solution 2: Reinstall CLI Tool**

```bash
# Uninstall
npm uninstall -g wp-dind-cli

# Reinstall
cd cli-tool
npm install -g .
```

**Solution 3: Use npx**

```bash
# Run without global install
npx wp-dind-cli init
```

### 8. Port Conflicts

#### Symptoms
- "Port already in use" error
- Cannot start container
- Address already in use

#### Diagnosis

```bash
# Check which process is using the port
lsof -i :8080
netstat -tuln | grep 8080

# Check Docker port mappings
docker ps --format "table {{.Names}}\t{{.Ports}}"
```

#### Solutions

**Solution 1: Change Port in docker-compose.yml**

```yaml
services:
  phpmyadmin:
    ports:
      - "8081:80"  # Changed from 8080
```

**Solution 2: Stop Conflicting Service**

```bash
# Find process ID
lsof -t -i:8080

# Kill process
kill -9 $(lsof -t -i:8080)
```

**Solution 3: Use Dynamic Ports**

```yaml
services:
  nginx:
    ports:
      - "0:80"  # Docker assigns random port
```

### 9. Slow Performance

#### Symptoms
- WordPress site loads slowly
- Database queries are slow
- High CPU/memory usage

#### Diagnosis

```bash
# Check resource usage
docker stats

# Check disk I/O
docker stats --format "table {{.Container}}\t{{.BlockIO}}"

# Check MySQL slow query log
wp-dind exec docker exec mysite-mysql \
  cat /var/log/mysql/slow-query.log
```

#### Solutions

**Solution 1: Increase Resources**

Edit `docker-compose.yml`:
```yaml
services:
  wordpress-dind:
    deploy:
      resources:
        limits:
          cpus: '4.0'
          memory: 8G
```

**Solution 2: Optimize MySQL**

Edit MySQL configuration:
```ini
[mysqld]
innodb_buffer_pool_size = 1G
max_connections = 100
query_cache_size = 32M
```

**Solution 3: Use Volume Drivers**

For better I/O performance:
```yaml
volumes:
  mysql-data:
    driver: local
    driver_opts:
      type: none
      o: bind
      device: /path/to/fast/storage
```

### 10. Network Connectivity Issues

#### Symptoms
- Containers cannot communicate
- DNS resolution fails
- Network timeout errors

#### Diagnosis

```bash
# Check networks
wp-dind exec docker network ls

# Inspect network
wp-dind exec docker network inspect wp-network-1

# Test connectivity
wp-dind exec docker exec mysite-wordpress ping mysite-mysql

# Check DNS
wp-dind exec docker exec mysite-wordpress nslookup mysite-mysql
```

#### Solutions

**Solution 1: Recreate Network**

```bash
# Stop instance
wp-dind exec instance-manager.sh stop mysite

# Remove network
wp-dind exec docker network rm wp-network-1

# Recreate network
wp-dind exec /app/network-setup.sh

# Start instance
wp-dind exec instance-manager.sh start mysite
```

**Solution 2: Check Network Driver**

```bash
# Verify bridge driver
wp-dind exec docker network inspect wp-network-1 | grep Driver
```

**Solution 3: Restart Docker Daemon**

```bash
# Restart DinD container
docker-compose restart wordpress-dind
```

## Advanced Troubleshooting

### Enable Debug Mode

#### WordPress Debug

Edit `wp-config.php`:
```php
define('WP_DEBUG', true);
define('WP_DEBUG_LOG', true);
define('WP_DEBUG_DISPLAY', false);
```

View logs:
```bash
wp-dind exec tail -f /wordpress-instances/mysite/wordpress/wp-content/debug.log
```

#### Docker Debug

Enable Docker debug mode:
```json
{
  "debug": true,
  "log-level": "debug"
}
```

### Collect Diagnostic Information

```bash
# System information
docker version
docker info
docker-compose version

# Container information
docker ps -a
docker stats --no-stream

# Network information
docker network ls
docker network inspect wp-dind

# Volume information
docker volume ls
docker system df -v

# Logs
docker logs wordpress-dind-host > dind.log
docker-compose logs > compose.log
```

### Reset Everything

If all else fails:

```bash
# Stop all containers
docker-compose down

# Remove all containers
docker rm -f $(docker ps -aq)

# Remove all volumes
docker volume rm $(docker volume ls -q)

# Remove all networks
docker network prune -f

# Remove all images
docker rmi -f $(docker images -q)

# Rebuild
./build-images.sh
docker-compose up -d
```

## Getting Help

### Before Asking for Help

1. Check this troubleshooting guide
2. Review the documentation
3. Search existing issues on GitHub
4. Collect diagnostic information

### How to Report Issues

Include:
1. **Environment**: OS, Docker version, docker-compose version
2. **Steps to reproduce**: Exact commands used
3. **Expected behavior**: What should happen
4. **Actual behavior**: What actually happens
5. **Logs**: Relevant log output
6. **Configuration**: docker-compose.yml, .env files

### Support Channels

- **Email**: aur3l.roman@gmail.com
- **GitHub Issues**: https://github.com/yourusername/wordpress-docker-dind/issues
- **Documentation**: https://github.com/yourusername/wordpress-docker-dind/docs

## Useful Commands

```bash
# View all logs
docker-compose logs -f

# Restart everything
docker-compose restart

# Check health
docker inspect wordpress-dind-host | grep Health

# Clean up
docker system prune -a --volumes

# Export logs
docker logs wordpress-dind-host > dind.log 2>&1

# Check disk usage
docker system df -v

# Monitor resources
watch -n 1 'docker stats --no-stream'
```

