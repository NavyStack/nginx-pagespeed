ARG NGINX_VERSION=1.31.5
FROM nginx:${NGINX_VERSION} as builder
ARG TARGETARCH
ARG PSOL=jammy
RUN apt-get update && apt-get install -y \
    wget \
    tar \
    build-essential \
    xz-utils \
    git \
    zlib1g-dev \
    libpcre3 \
    libpcre3-dev \
    unzip \
    uuid-dev \
    openssl \
    libssl-dev \
    libbrotli-dev && \
    mkdir -p /opt/build-stage
WORKDIR /opt/build-stage
RUN wget https://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz

RUN if [ "$TARGETARCH" = "amd64" ]; then \
    wget https://www.tiredofit.nl/psol-${PSOL}.tar.xz && \
    git clone --depth=1 https://github.com/apache/incubator-pagespeed-ngx.git && \
    tar xvf psol-${PSOL}.tar.xz && \
    mv psol incubator-pagespeed-ngx && \
    tar zxvf nginx-${NGINX_VERSION}.tar.gz; \
    fi

RUN if [ "$TARGETARCH" = "arm64" ]; then \
    wget https://gitlab.com/gusco/ngx_pagespeed_arm/-/raw/master/psol-1.15.0.0-aarch64.tar.gz && \
    git clone --depth=1 https://github.com/apache/incubator-pagespeed-ngx.git && \
    tar xvf psol-1.15.0.0-aarch64.tar.gz && \
    mv psol incubator-pagespeed-ngx && \
    sed -i 's/x86_64/aarch64/' incubator-pagespeed-ngx/config && \
    sed -i 's/x64/aarch64/' incubator-pagespeed-ngx/config && \
    sed -i 's/-luuid/-l:libuuid.so.1/' incubator-pagespeed-ngx/config && \
    tar zxvf nginx-${NGINX_VERSION}.tar.gz; \
    fi

WORKDIR /opt/build-stage/nginx-${NGINX_VERSION}
RUN ./configure --with-compat --add-dynamic-module=../incubator-pagespeed-ngx && \
    make

FROM nginx:${NGINX_VERSION} as final
COPY --from=builder /opt/build-stage/nginx-${NGINX_VERSION}/objs/ngx_pagespeed.so /usr/lib/nginx/modules/
run mkdir -p /var/run/ngx_pagespeed_cache && \
    mkdir -p /var/run/nginx-cache && \
    chown www-data:www-data /var/run/ngx_pagespeed_cache && \
    chown www-data:www-data /var/run/nginx-cache && \
    echo "load_module modules/ngx_pagespeed.so;\n$(cat /etc/nginx/nginx.conf)" > /etc/nginx/nginx.conf