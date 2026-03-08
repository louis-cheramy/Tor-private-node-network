FROM debian:bookworm-slim

RUN apt-get update \
    && apt-get install -y --no-install-recommends tor nginx ca-certificates dos2unix \
    && rm -rf /var/lib/apt/lists/*

COPY tor/onion/torrc /etc/tor/torrc
COPY tor/onion/default.conf /etc/nginx/conf.d/default.conf
COPY tor/onion/entrypoint.sh /entrypoint.sh
COPY web/index.html /usr/share/nginx/html/index.html

RUN dos2unix /entrypoint.sh && chmod +x /entrypoint.sh

EXPOSE 80

ENTRYPOINT ["/bin/sh", "/entrypoint.sh"]
