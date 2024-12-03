# syntax=docker/dockerfile:1
FROM ubuntu:jammy AS lzarus_upstream

FROM composer/composer:2-bin AS composer_upstream
LABEL maintainer="Update by Hasiniaina Andriatsiory <hasiniaina.andriatsiory@gmail.com>"

FROM lzarus_upstream AS lzarus_msaz


# Configuration des variables d'environnement
ENV DEBIAN_FRONTEND=noninteractive \
    PORT=8080 \
    SSH_PORT=2222

ARG PHP_VERSION

# Installation des dépendances système
RUN apt-get update && apt-get upgrade -y && \
    apt-get install -y --no-install-recommends \
        ca-certificates \
        apt-transport-https \
        software-properties-common \
        openssh-server \
        apache2 \
        curl \
        cron \
        gnupg \
        libgd3 \
        zip \
        git \
        unzip \
        nano \
        telnet \
        traceroute && \
    add-apt-repository ppa:ondrej/php && \
    rm -rf /var/lib/apt/lists/*

# Configuration PHP
COPY core/sourcephp.list /etc/apt/sources.list.d/ondrej-ubuntu-php-jammy.list

# Installation de PHP et ses extensions
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        php${PHP_VERSION} \
        php${PHP_VERSION}-apcu \
        php${PHP_VERSION}-bcmath \
        php${PHP_VERSION}-cli \
        php${PHP_VERSION}-curl \
        php${PHP_VERSION}-gettext \
        php${PHP_VERSION}-gd \
        php${PHP_VERSION}-mbstring \
        php${PHP_VERSION}-memcached \
        php${PHP_VERSION}-mysql \
        php${PHP_VERSION}-opcache \
        php${PHP_VERSION}-soap \
        php${PHP_VERSION}-tidy \
        php${PHP_VERSION}-xml \
        php${PHP_VERSION}-yaml \
        php${PHP_VERSION}-zip && \
    rm -rf /var/lib/apt/lists/* && \
    sed -i 's/upload_max_filesize = 2M/upload_max_filesize = 768M/g' /etc/php/${PHP_VERSION}/cli/php.ini && \
    sed -i 's/max_file_uploads = 20/max_file_uploads = 50/g' /etc/php/${PHP_VERSION}/cli/php.ini

# Installation de Composer
COPY --from=composer_upstream --link /composer /usr/bin/composer

# Configuration SSH et Apache
COPY sshd_config /etc/ssh/
COPY core/apache2.conf /etc/apache2/
COPY core/ports.conf /etc/apache2/
COPY core/security.conf /etc/apache2/sites-enabled/
COPY core/mpm_prefork.conf /etc/apache2/mods-enabled/
COPY core/envvars /etc/apache2/
COPY init_container.sh /bin/
COPY hostingstart.html /home/site/wwwroot/
COPY ssh_setup.sh startup.sh /tmp/

# Configuration du conteneur
RUN chmod 755 /bin/init_container.sh && \
    mkdir -p /home/LogFiles /opt/startup && \
    rm -f /etc/apache2/sites-enabled/000-default.conf && \
    rm -f /etc/apache2/conf-enabled/other-vhosts-access-log.conf && \
    a2enmod rewrite expires headers http2 proxy_http proxy_wstunnel && \
    echo "syntax on\ncolorscheme desert" > ~/.vimrc && \
    ln -s /home/site/wwwroot /var/www/html && \
    mv /tmp/startup.sh /opt/startup/ && \
    chmod -R +x /opt/startup/startup.sh /tmp/ssh_setup.sh && \
    /tmp/ssh_setup.sh && \
    apt-get purge -y gnupg && \
    apt-get autoremove -y && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

WORKDIR /home/site/wwwroot
EXPOSE 2222 8080

ENV PATH=${PATH}:/home/site/wwwroot

ENTRYPOINT ["/bin/init_container.sh"]

FROM lzarus_msaz AS lzarus_swagger
COPY core/swagger.conf /etc/apache2/sites-enabled/

FROM lzarus_msaz AS lzarus_laravel
COPY core/laravel.conf /etc/apache2/sites-enabled/