# Production image for PHPNuxBill with FreeRADIUS-REST integration.
#
#   Build:  docker build -f docker/phpnuxbill/Dockerfile -t rofa-phpnuxbill:latest .
#   Dockploy: compose service builds this path (see docker-compose.yml -> build.dockerfile)
#
# Production characteristics:
#   * production nginx config  -> access/error logs to stdout/stderr, hardened
#   * production php.ini       -> errors to stderr, explicit timezone, limits
#   * dev/deploy artifacts stripped from the runtime filesystem
#   * HEALTHCHECK against the local web endpoint
# Runtime requirements preserved: dcron (deauth/expire sweeps every 5 min) and
# freeradius-utils (radclient for Disconnect-Requests) — do not remove them.

FROM php:8.2-fpm-alpine

LABEL org.opencontainers.image.title="rofa-phpnuxbill" \
      org.opencontainers.image.description="PHPNuxBill + FreeRADIUS REST (production)"

# Install nginx, cron, runtime dependencies and PHP extensions required by PHPNuxBill
RUN apk add --no-cache \
        nginx \
        dcron \
        mariadb-client \
        freeradius-utils \
        freetype-dev \
        libjpeg-turbo-dev \
        libpng-dev \
        libwebp-dev \
        libzip-dev \
        zlib-dev \
        curl-dev \
        oniguruma-dev \
        libxml2-dev \
    && docker-php-ext-configure gd --with-freetype --with-jpeg --with-webp \
    && docker-php-ext-install -j$(nproc) gd pdo pdo_mysql mysqli zip mbstring curl xml \
    && rm -rf /var/cache/apk/*

# Copy application source
COPY . /var/www/html
WORKDIR /var/www/html

# PHPNuxBill expects the pages folder, not pages_template
RUN if [ -d /var/www/html/pages_template ] && [ ! -d /var/www/html/pages ]; then \
        mv /var/www/html/pages_template /var/www/html/pages; \
    fi

# Strip dev/deploy-only artifacts from the runtime filesystem
# (config.php is generated from environment variables by the entrypoint and
#  must never be baked into the image; .env is excluded by .dockerignore.)
RUN rm -rf \
        /var/www/html/staging-export \
        /var/www/html/test_mpesa_radius.sh \
        /var/www/html/system/paymentgateway/mpesa/tests \
        /var/www/html/docker \
        /var/www/html/docker-compose.yml \
        /var/www/html/docker-compose.example.yml \
        /var/www/html/.dockerignore \
        /var/www/html/.gitignore \
        /var/www/html/.htaccess_firewall

# Nginx site config, PHP overrides and startup script
COPY docker/phpnuxbill/nginx.production.conf /etc/nginx/http.d/default.conf
COPY docker/phpnuxbill/php.production.ini /usr/local/etc/php/conf.d/zz-production.ini
COPY docker/phpnuxbill/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# Ensure required directories exist and are writable
RUN mkdir -p /var/www/html/ui/cache /var/www/html/ui/compiled /var/www/html/system/uploads /var/www/html/system/cache \
    && chown -R www-data:www-data /var/www/html \
    && chmod -R 755 /var/www/html

EXPOSE 80

# Served pages answer within the start period even when the database is still
# coming up (the entrypoint waits for MySQL before starting php-fpm/nginx).
HEALTHCHECK --interval=30s --timeout=5s --start-period=30s --retries=3 \
    CMD wget -q -O /dev/null http://127.0.0.1/ || exit 1

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["nginx", "-g", "daemon off;"]
