FROM docker:27-dind

LABEL maintainer="aur3l.roman@gmail.com"
LABEL version="27.0"
LABEL type="wp-dind"
LABEL description="Docker-in-Docker base image for WordPress hosting with image sharing"

# Install required packages
RUN apk add --no-cache \
    bash \
    curl \
    git \
    jq \
    docker-compose \
    iproute2 \
    iptables \
    bridge-utils \
    php83 \
    php83-fpm \
    php83-mysqli \
    php83-json \
    php83-openssl \
    php83-curl \
    php83-zlib \
    php83-xml \
    php83-phar \
    php83-intl \
    php83-dom \
    php83-xmlreader \
    php83-ctype \
    php83-session \
    php83-mbstring \
    php83-gd \
    nginx \
    supervisor \
    redis \
    nodejs \
    npm

# Install MailHog (simpler alternative to MailCatcher, no Ruby dependencies)
RUN curl -L https://github.com/mailhog/MailHog/releases/download/v1.0.1/MailHog_linux_amd64 -o /usr/local/bin/mailhog && \
    chmod +x /usr/local/bin/mailhog

# Install Redis Commander
RUN npm install -g redis-commander

# Install WP-CLI
RUN curl -o /usr/local/bin/wp https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar && \
    chmod +x /usr/local/bin/wp && \
    mkdir -p /root/.wp-cli && \
    wp --info || true

# Copy WP-CLI configuration
COPY wp-cli.yml /root/.wp-cli/config.yml

# Set WP-CLI environment variable to allow root
ENV WP_CLI_ALLOW_ROOT=1

# Download and install phpMyAdmin

# Download and install phpMyAdmin
RUN mkdir -p /var/www/phpmyadmin && \
    cd /tmp && \
    curl -L https://files.phpmyadmin.net/phpMyAdmin/5.2.3/phpMyAdmin-5.2.3-all-languages.tar.gz | tar xz && \
    mv phpMyAdmin-5.2.3-all-languages/* /var/www/phpmyadmin/ && \
    rm -rf phpMyAdmin-5.2.3-all-languages && \
    mkdir -p /var/www/phpmyadmin/tmp && \
    chown -R nginx:nginx /var/www/phpmyadmin && \
    chmod -R 755 /var/www/phpmyadmin/tmp

# Create directories for WordPress instances and services
RUN mkdir -p /wordpress-instances \
    /shared-images \
    /app \
    /var/log/supervisor \
    /run/nginx \
    /run/php-fpm \
    /etc/redis \
    /data/redis && \
    chown redis:redis /data/redis

# Copy application files
COPY entrypoint.sh /app/
COPY network-setup.sh /app/
COPY instance-manager.sh /app/
COPY install-wordpress.sh /app/
COPY workspace-manager.sh /app/
COPY supervisord.conf /etc/supervisord.conf
COPY nginx-phpmyadmin.conf /etc/nginx/http.d/phpmyadmin.conf
COPY phpmyadmin-config.inc.php /var/www/phpmyadmin/config.inc.php
COPY redis.conf /etc/redis/redis.conf

# Copy configuration templates
COPY config-templates/ /app/config-templates/

# Make scripts executable
RUN chmod +x /app/*.sh

WORKDIR /app

# Expose Docker daemon port and service ports
EXPOSE 2375 2376 8080 1080 1025 6379 8081

# Use custom entrypoint
ENTRYPOINT ["/app/entrypoint.sh"]
CMD []
