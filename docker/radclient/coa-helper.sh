#!/bin/sh
# Helper for sending RADIUS CoA/Disconnect packets to the rofa-freeradius server.
# Usage:
#   coa-helper disconnect <username>
#   coa-helper coa <username> [rate-limit]

ACTION=${1:-}
USERNAME=${2:-}
RATE_LIMIT=${3:-}

SERVER=${RADIUS_SERVER:-rofa-freeradius}
PORT=${RADIUS_COA_PORT:-3799}
SECRET=${RADIUS_SECRET:-secret}

case "$ACTION" in
    disconnect)
        printf 'User-Name = "%s"\n' "$USERNAME" | /usr/bin/radclient -x "$SERVER:$PORT" disconnect "$SECRET"
        ;;
    coa)
        if [ -n "$RATE_LIMIT" ]; then
            printf 'User-Name = "%s"\nMikrotik-Rate-Limit = "%s"\n' "$USERNAME" "$RATE_LIMIT" | /usr/bin/radclient -x "$SERVER:$PORT" coa "$SECRET"
        else
            printf 'User-Name = "%s"\n' "$USERNAME" | /usr/bin/radclient -x "$SERVER:$PORT" coa "$SECRET"
        fi
        ;;
    *)
        echo "Usage: coa-helper {disconnect|coa} <username> [rate-limit]"
        exit 1
        ;;
esac
