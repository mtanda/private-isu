FROM alpine:3.20

RUN apk add --no-cache curl ca-certificates \
    && curl -fsSL https://raw.githubusercontent.com/grafana/gcx/v1.2.0/scripts/install.sh \
        | GCX_INSTALL_DIR=/usr/local/bin GCX_VERSION=1.2.0 sh

ENTRYPOINT ["gcx"]
