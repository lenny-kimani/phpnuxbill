FROM alpine:3.19

LABEL org.opencontainers.image.title="rofa-freeradius"
LABEL org.opencontainers.image.description="FreeRADIUS 3 with REST module on Alpine Linux"

# FreeRADIUS and REST module for PHPNuxBill integration
RUN apk add --no-cache \
        freeradius \
        freeradius-rest \
        freeradius-utils \
        bash \
        envsubst \
        curl \
    && rm -rf /var/cache/apk/*

# RADIUS ports: authentication, accounting, CoA/Disconnect
EXPOSE 1812/udp 1813/udp 3799/udp

# Copy config templates and runtime entrypoint
COPY docker/freeradius/clients.conf /etc/raddb/templates/clients.conf.tpl
COPY docker/freeradius/rest /etc/raddb/templates/rest.tpl
COPY docker/freeradius/sites/default /etc/raddb/templates/default.tpl
COPY docker/freeradius/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# envsubst is used in the entrypoint to fill placeholders
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
