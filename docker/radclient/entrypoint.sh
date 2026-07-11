#!/bin/sh
set -e

# If no arguments were provided, keep the container alive so it can be used
# interactively with `docker compose exec rofa-coa radclient ...`.
if [ "$#" -eq 0 ] || [ "$1" = "radclient" ] && [ "$#" -eq 1 ]; then
    echo "rofa-coa container ready. Use 'docker compose exec rofa-coa radclient ...' to send packets."
    exec tail -f /dev/null
fi

# Otherwise pass through to radclient.
exec /usr/bin/radclient "$@"
