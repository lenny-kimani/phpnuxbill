FROM alpine:3.19

LABEL maintainer="PHPNuxBill M-Pesa Gateway"
LABEL description="Trusted radclient image for sending RADIUS CoA/Disconnect packets to MikroTik"

RUN apk add --no-cache freeradius-utils bash coreutils

# Helper script for common CoA/Disconnect operations
COPY docker/radclient/coa-helper.sh /usr/local/bin/coa-helper
RUN chmod +x /usr/local/bin/coa-helper

# Run as non-root if invoked directly, but radclient usually needs raw UDP sockets.
USER root

# When invoked directly, run radclient; when run without args in compose, keep alive.
COPY docker/radclient/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["radclient"]
