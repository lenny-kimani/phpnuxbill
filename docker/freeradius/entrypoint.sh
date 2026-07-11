#!/bin/sh
set -e

# Substitute environment variables into FreeRADIUS config templates.
# The templates use @RADIUS_SECRET@ and @PHPNUXBILL_URL@ as placeholders.

SECRET=${RADIUS_SECRET:-secret}
PHP_URL=${PHPNUXBILL_URL:-http://rofa-phpnuxbill}

mkdir -p /etc/raddb/mods-enabled /etc/raddb/sites-enabled

sed -e "s|@RADIUS_SECRET@|$SECRET|g" \
    -e "s|@PHPNUXBILL_URL@|$PHP_URL|g" \
    /etc/raddb/templates/clients.conf.tpl > /etc/raddb/clients.conf

sed -e "s|@RADIUS_SECRET@|$SECRET|g" \
    -e "s|@PHPNUXBILL_URL@|$PHP_URL|g" \
    /etc/raddb/templates/rest.tpl > /etc/raddb/mods-enabled/rest

sed -e "s|@RADIUS_SECRET@|$SECRET|g" \
    -e "s|@PHPNUXBILL_URL@|$PHP_URL|g" \
    /etc/raddb/templates/default.tpl > /etc/raddb/sites-enabled/default

# Validate generated configuration
radiusd -XC

# Wait for PHPNuxBill to be reachable; the REST module instantiates a
# connection at startup and will fail if the backend is unavailable.
CHECK_URL="$PHP_URL/radius.php?action=authenticate"
echo "Waiting for PHPNuxBill REST backend at $PHP_URL ..."
for i in $(seq 1 60); do
    if curl -fsS -m 2 "$CHECK_URL" >/dev/null 2>&1; then
        echo "PHPNuxBill REST backend is reachable."
        break
    fi
    sleep 2
done

# Start FreeRADIUS in foreground
exec radiusd -f
