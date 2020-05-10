ARG PHP_VERSION=7.3
# Deployment doesn't work on Alpine
FROM php:${PHP_VERSION}-cli AS deployer
ARG OSTICKET_VERSION=1.14.1
RUN set -x \
    && apt-get update \
    && apt-get install -y git-core \
    && git clone -b v${OSTICKET_VERSION} --depth 1 https://github.com/osTicket/osTicket.git \
    && cd osTicket \
    && php manage.php deploy -sv /data/upload \
    # www-data is uid:gid 82:82 in php:7.0-fpm-alpine
    && chown -R 82:82 /data/upload \
    # Hide setup
    && mv /data/upload/setup /data/upload/setup_hidden \
    && chown -R root:root /data/upload/setup_hidden \
    && chmod -R go= /data/upload/setup_hidden

FROM php:${PHP_VERSION}-fpm-alpine
# environment for osticket
ENV HOME=/data
# setup workdir
WORKDIR /data
COPY --from=deployer /data/upload upload
ARG APACHE2_VERSION=2.4.43
RUN set -x && \
    # requirements and PHP extensions
    apk add --no-cache --update \
        apache2~=${APACHE2_VERSION} apache2-proxy apache2-ssl \
        wget \
        msmtp \
        ca-certificates \
        supervisor \
        libpng \
        c-client \
        openldap \
        libintl \
        libxml2 \
        icu \
        libzip-dev \
        openssl && \
    apk add --no-cache --virtual .build-deps \
        imap-dev \
        libpng-dev \
        curl-dev \
        openldap-dev \
        gettext-dev \
        libxml2-dev \
        icu-dev \
        autoconf \
        g++ \
        make \
        pcre-dev && \
    docker-php-ext-install gd curl ldap mysqli sockets gettext mbstring xml intl opcache && \
    docker-php-ext-configure imap --with-imap-ssl && \
    docker-php-ext-install imap && \
    docker-php-ext-configure zip --with-libzip=/usr/include && docker-php-ext-install zip && \
    pecl install apcu && docker-php-ext-enable apcu && \
    apk del .build-deps && \
    rm -rf /var/cache/apk/* && \
    # Create msmtp log
    touch /var/log/msmtp.log && \
    chown www-data:www-data /var/log/msmtp.log 
    
COPY files/ /
VOLUME ["/data/upload/include/plugins","/data/upload/include/i18n","/var/log/apache2"]
EXPOSE 80
CMD ["/data/bin/start.sh"]