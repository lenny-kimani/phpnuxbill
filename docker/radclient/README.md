# RADIUS CoA / Disconnect Container

This directory contains a minimal, trusted container image for sending RADIUS Change of Authorization (CoA) and Disconnect packets to MikroTik NAS devices.

## Build

```bash
docker build -t phpnuxbill-radclient docker/radclient/
```

## Usage from PHPNuxBill

The PHPNuxBill `Radius` device class will use `radclient` from the host if it is installed. If the host does not have FreeRADIUS utilities, you can run the container instead:

```bash
# Disconnect a user
printf 'User-Name = %s\n' "$USERNAME" | docker run -i --rm phpnuxbill-radclient -x "$NAS_IP:$NAS_PORT" disconnect "$NAS_SECRET"

# CoA example (push new rate limit)
printf 'User-Name = %s\nMikrotik-Rate-Limit = 2M/2M\n' "$USERNAME" | docker run -i --rm phpnuxbill-radclient -x "$NAS_IP:$NAS_PORT" coa "$NAS_SECRET"
```

## MikroTik Configuration

Ensure the router accepts incoming CoA/Disconnect messages:

```rsc
/radius incoming set accept=yes port=3799
```

The source IP of the container host must match a configured `/radius` client on the MikroTik.

## Trust / Supply Chain

The image is based on a pinned Alpine Linux digest and installs `freeradius-utils` from the official Alpine package repository. Rebuild the image whenever the base digest is updated or a new FreeRADIUS version is required.
