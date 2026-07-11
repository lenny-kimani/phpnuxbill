FROM php:8.2-fpm-alpine

LABEL org.opencontainers.image.title="rofa-phpnuxbill"
LABEL org.opencontainers.image.description="PHPNuxBill on Alpine Linux with nginx + PHP-FPM"

# Install nginx, runtime dependencies and PHP extensions required by PHPNuxBill
RUN apk add --no-cache \
        nginx \
        mariadb-client \
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

# Nginx site configuration and startup script
COPY docker/phpnuxbill/nginx.conf /etc/nginx/http.d/default.conf
COPY docker/phpnuxbill/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# Ensure required directories exist and are writable
RUN mkdir -p /var/www/html/ui/cache /var/www/html/ui/compiled /var/www/html/system/uploads \
    && chown -R www-data:www-data /var/www/html \
    && chmod -R 755 /var/www/html

EXPOSE 80

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["nginx", "-g", "daemon off;"]
