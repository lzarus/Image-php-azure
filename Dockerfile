# syntax=docker/dockerfile:1
FROM ubuntu:lunar AS lzarus_upstream

FROM composer/composer:2-bin AS composer_upstream
LABEL maintainer="Update by Hasiniaina Andriatsiory <hasiniaina.andriatsiory@gmail.com>"

FROM lzarus_upstream AS lzarus_phpbase

ENV DEBIAN_FRONTEND=noninteractive

ARG PHP_VERSION

RUN apt-get update && apt-get upgrade -y && \
    apt-get install -y --no-install-recommends \
    ca-certificates apt-transport-https software-properties-common \
    openssh-server apache2 curl cron gnupg libgd3 zip git unzip nano telnet && \
    rm -rf /var/lib/apt/lists/*

RUN add-apt-repository ppa:ondrej/php 

COPY core/sourcephp.list /etc/apt/sources.list.d/ondrej-ubuntu-php-lunar.list
RUN apt-get update && apt-get install -y --no-install-recommends \
    php${PHP_VERSION} php${PHP_VERSION}-apcu php${PHP_VERSION}-bcmath \
    php${PHP_VERSION}-cli php${PHP_VERSION}-curl php${PHP_VERSION}-gettext \
    php${PHP_VERSION}-gd php${PHP_VERSION}-mbstring php${PHP_VERSION}-memcached \
    php${PHP_VERSION}-mysql php${PHP_VERSION}-opcache php${PHP_VERSION}-soap \
    php${PHP_VERSION}-tidy php${PHP_VERSION}-xml php${PHP_VERSION}-yaml \
    php${PHP_VERSION}-zip && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

RUN sed -i 's/upload_max_filesize = 2M/upload_max_filesize = 768M/g' /etc/php/${PHP_VERSION}/cli/php.ini && \
    sed -i 's/max_file_uploads = 20/max_file_uploads = 50/g' /etc/php/${PHP_VERSION}/cli/php.ini

COPY --from=composer_upstream --link /composer /usr/bin/composer

ENV PORT=8080
ENV SSH_PORT=2222

EXPOSE 2222 8080

COPY sshd_config /etc/ssh/
WORKDIR /home/site/wwwroot
ENTRYPOINT ["/bin/init_container.sh"]

RUN apt-get purge -y gnupg && apt-get autoremove -y && \
    apt-get clean && rm -rf /var/cache/apt/lists /tmp/* /var/tmp/*
    
FROM lzarus_phpbase AS lzarus_msaz
COPY core/apache2.conf /etc/apache2/
COPY core/ports.conf /etc/apache2/
COPY core/security.conf /etc/apache2/sites-enabled/
COPY core/mpm_prefork.conf /etc/apache2/mods-enabled/mpm_prefork.conf
COPY core/envvars /etc/apache2/
COPY init_container.sh /bin/
COPY hostingstart.html /home/site/wwwroot/hostingstart.html

RUN rm /etc/apache2/sites-enabled/000-default.conf && \
    a2enmod rewrite expires headers http2 proxy_http proxy_wstunnel && \
    service apache2 restart && \
    chmod 755 /bin/init_container.sh && \
    mkdir -p /home/LogFiles/ && \
    ln -s /home/site/wwwroot /var/www/html

COPY ssh_setup.sh /tmp/
COPY startup.sh /tmp/
RUN chmod -R +x /tmp/ssh_setup.sh /tmp/startup.sh && \
    mkdir -p /opt/startup && mv /tmp/startup.sh /opt/startup/ && \
    chmod -R +x /opt/startup/startup.sh && \
    /tmp/ssh_setup.sh && rm -rf /tmp/*

ENV PATH=${PATH}:/home/site/wwwroot
FROM lzarus_msaz AS lzarus_swagger
COPY core/swagger.conf /etc/apache2/sites-enabled/
FROM lzarus_msaz AS lzarus_laravel
COPY core/laravel.conf /etc/apache2/sites-enabled/