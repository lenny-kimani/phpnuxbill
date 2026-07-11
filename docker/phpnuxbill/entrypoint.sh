#!/bin/sh
set -e

# Generate PHPNuxBill config.php from environment variables if it does not exist
CONFIG_FILE=/var/www/html/config.php
if [ ! -f "$CONFIG_FILE" ]; then
    cat > "$CONFIG_FILE" <<EOF
<?php
\$protocol = (!empty(\$_SERVER['HTTPS']) && \$_SERVER['HTTPS'] !== 'off' ||
             (isset(\$_SERVER['SERVER_PORT']) && \$_SERVER['SERVER_PORT'] == 443)) ? "https://" : "http://";
\$host = isset(\$_SERVER['HTTP_HOST']) ? \$_SERVER['HTTP_HOST'] : (isset(\$_SERVER['SERVER_NAME']) ? \$_SERVER['SERVER_NAME'] : 'localhost');
\$baseDir = rtrim(dirname(\$_SERVER['SCRIPT_NAME']), '/\\\\');
define('APP_URL', \$protocol . \$host . \$baseDir);

\$_app_stage = 'Live';

\$db_host = "${DB_HOST:-rofa-mysql}";
\$db_port = "";
\$db_user = "${DB_USER:-rofa_nuxbill}";
\$db_pass = "${DB_PASSWORD:-password}";
\$db_name = "${DB_NAME:-rofa_nuxbill}";

if(\$_app_stage!='Live'){
    error_reporting(E_ERROR);
    ini_set('display_errors', 1);
    ini_set('display_startup_errors', 1);
} else {
    error_reporting(E_ERROR);
    ini_set('display_errors', 0);
    ini_set('display_startup_errors', 0);
}
EOF
    chmod 644 "$CONFIG_FILE"
fi

# Wait for MySQL to be ready
DB_HOST="${DB_HOST:-rofa-mysql}"
DB_USER="${DB_USER:-rofa_nuxbill}"
DB_PASSWORD="${DB_PASSWORD:-password}"
DB_NAME="${DB_NAME:-rofa_nuxbill}"

echo "Waiting for database $DB_HOST ..."
MYSQL_OPTS="--ssl=0"
for i in $(seq 1 30); do
    if mysql $MYSQL_OPTS -h "$DB_HOST" -u "$DB_USER" -p"$DB_PASSWORD" -e "SELECT 1" "$DB_NAME" >/dev/null 2>&1; then
        echo "Database is ready."
        break
    fi
    sleep 2
done

# Initialize database on first run if tbl_appconfig does not exist
if ! mysql $MYSQL_OPTS -h "$DB_HOST" -u "$DB_USER" -p"$DB_PASSWORD" -e "SELECT 1 FROM tbl_appconfig LIMIT 1" "$DB_NAME" >/dev/null 2>&1; then
    echo "Initializing PHPNuxBill database..."
    mysql $MYSQL_OPTS -h "$DB_HOST" -u "$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" < /var/www/html/install/phpnuxbill.sql
fi

# Fix permissions for writable directories
chown -R www-data:www-data /var/www/html/ui/cache /var/www/html/ui/compiled /var/www/html/system/uploads 2>/dev/null || true
chmod -R 755 /var/www/html/ui/cache /var/www/html/ui/compiled 2>/dev/null || true

# Start PHP-FPM in the background
php-fpm -D

# Start nginx in the foreground (keeps container running)
exec nginx -g 'daemon off;'
