FROM alpine:3.19@sha256:07824853e0c8a02afee9467b7a2a8e4e20c64f68a63bc5e9c3d0a50d1b751c37

LABEL maintainer="PHPNuxBill M-Pesa Gateway"
LABEL description="Trusted radclient image for sending RADIUS CoA/Disconnect packets to MikroTik"

RUN apk add --no-cache freeradius-utils bash

# Run as non-root if invoked directly, but radclient usually needs raw UDP sockets.
USER root

ENTRYPOINT ["/usr/bin/radclient"]
