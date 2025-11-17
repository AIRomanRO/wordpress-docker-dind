FROM php:8.3-fpm-alpine

LABEL maintainer="aur3l.roman@gmail.com"
LABEL version="8.3"
LABEL description="PHP-FPM 8.3 for WordPress Docker-in-Docker setup"

# Install runtime dependencies
RUN apk add --no-cache \
    bash \
    curl \
    freetype \
    icu-libs \
    imagemagick \
    imagemagick-libs \
    libjpeg-turbo \
    libpng \
    libwebp \
    libxml2 \
    libzip \
    oniguruma \
    openldap \
    postgresql-libs \
    sqlite-libs

# Install build dependencies and compile PHP extensions
RUN apk add --no-cache \
    $PHPIZE_DEPS \
    autoconf \
    g++ \
    make \
    linux-headers \
    freetype-dev \
    icu-dev \
    imagemagick-dev \
    jpeg-dev \
    libpng-dev \
    libwebp-dev \
    libxml2-dev \
    libzip-dev \
    oniguruma-dev \
    openldap-dev \
    postgresql-dev \
    sqlite-dev \
    && docker-php-ext-configure gd \
        --with-freetype \
        --with-jpeg \
        --with-webp \
    && docker-php-ext-install -j$(nproc) \
        bcmath \
        exif \
        gd \
        intl \
        ldap \
        mbstring \
        mysqli \
        opcache \
        pdo \
        pdo_mysql \
        pdo_pgsql \
        pdo_sqlite \
        soap \
        zip \
    && pecl install imagick redis \
    && pecl install xdebug \
    && docker-php-ext-enable imagick redis xdebug \
    && apk del --no-network \
        autoconf \
        g++ \
        make \
        linux-headers \
        freetype-dev \
        icu-dev \
        imagemagick-dev \
        jpeg-dev \
        libpng-dev \
        libwebp-dev \
        libxml2-dev \
        libzip-dev \
        oniguruma-dev \
        openldap-dev \
        postgresql-dev \
        sqlite-dev

# Install Composer
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

# Install WP-CLI
RUN curl -o /usr/local/bin/wp https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar && \
    chmod +x /usr/local/bin/wp && \
    mkdir -p /root/.wp-cli

# Copy PHP configuration files
COPY config/opcache-recommended.ini /usr/local/etc/php/conf.d/opcache-recommended.ini
COPY config/wordpress-recommended.ini /usr/local/etc/php/conf.d/wordpress-recommended.ini
COPY config/xdebug.ini /usr/local/etc/php/conf.d/xdebug.ini

# Set working directory
WORKDIR /var/www/html

# Expose PHP-FPM port
EXPOSE 9000

CMD ["php-fpm"]


# Copy entrypoint script
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# Use entrypoint to copy host configs on startup
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
