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

\$radius_host = "${RADIUS_DB_HOST:-${DB_HOST:-rofa-mysql}}";
\$radius_port = "";
\$radius_user = "${RADIUS_DB_USER:-${DB_USER:-rofa_nuxbill}}";
\$radius_pass = "${RADIUS_DB_PASSWORD:-${DB_PASSWORD:-password}}";
\$radius_name = "${RADIUS_DB_NAME:-${DB_NAME:-rofa_nuxbill}}";

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

# Initialize RADIUS tables if the nas table does not exist in the RADIUS database
RADIUS_DB_HOST="${RADIUS_DB_HOST:-$DB_HOST}"
RADIUS_DB_USER="${RADIUS_DB_USER:-$DB_USER}"
RADIUS_DB_PASSWORD="${RADIUS_DB_PASSWORD:-$DB_PASSWORD}"
RADIUS_DB_NAME="${RADIUS_DB_NAME:-$DB_NAME}"
if ! mysql $MYSQL_OPTS -h "$RADIUS_DB_HOST" -u "$RADIUS_DB_USER" -p"$RADIUS_DB_PASSWORD" -e "SELECT 1 FROM nas LIMIT 1" "$RADIUS_DB_NAME" >/dev/null 2>&1; then
    echo "Initializing RADIUS tables..."
    mysql $MYSQL_OPTS -h "$RADIUS_DB_HOST" -u "$RADIUS_DB_USER" -p"$RADIUS_DB_PASSWORD" "$RADIUS_DB_NAME" < /var/www/html/install/radius.sql
fi

# Fix permissions for writable directories
mkdir -p /var/www/html/system/cache
chown -R www-data:www-data /var/www/html/ui/cache /var/www/html/ui/compiled /var/www/html/system/uploads /var/www/html/system/cache 2>/dev/null || true
chmod -R 755 /var/www/html/ui/cache /var/www/html/ui/compiled /var/www/html/system/cache 2>/dev/null || true

# Enable PHPNuxBill cron job to run every 5 minutes as www-data
CRON_LOG=/var/log/phpnuxbill-cron.log
mkdir -p /var/log
touch "$CRON_LOG"
chown www-data:www-data "$CRON_LOG"
mkdir -p /etc/cron.d
cat > /etc/cron.d/phpnuxbill <<'CRON'
# PHPNuxBill scheduled jobs
*/5 * * * * /bin/sh -c 'cd /var/www/html/system && su -s /bin/sh www-data -c "/usr/local/bin/php cron.php" >> /var/log/phpnuxbill-cron.log 2>&1'
CRON
chmod 0644 /etc/cron.d/phpnuxbill
# Start dcron in the background (it reads /etc/cron.d and /etc/crontabs)
crond -b -L /var/log/crond.log

# Start PHP-FPM in the background
php-fpm -D

# Start nginx in the foreground (keeps container running)
exec nginx -g 'daemon off;'
