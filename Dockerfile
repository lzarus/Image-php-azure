# syntax=docker/dockerfile:1
FROM ubuntu:jammy
LABEL maintainer="Update by Hasiniaina Andriatsiory <hasiniaina.andriatsiory@gmail.com>"

# Stop dpkg-reconfigure tzdata from prompting for input
ENV DEBIAN_FRONTEND=noninteractive
ENV PHP_VERSION 7.4
# Install apache and php7
RUN apt-get update && \
	apt-get install --force-yes -y --no-install-recommends \
	lsb-release ca-certificates apt-transport-https software-properties-common apt-utils gnupg \
        apache2 \
	curl \
	cron \
	openssh-server 
RUN add-apt-repository ppa:ondrej/php -y && apt-get update
RUN apt-get remove --purge -y libhashkit-dev 
RUN apt-get install -y --no-install-recommends $(bash -c 'echo "php${PHP_VERSION} php${PHP_VERSION}-apcu php${PHP_VERSION}-bcmath php${PHP_VERSION}-cli php${PHP_VERSION}-curl php${PHP_VERSION}-gettext php${PHP_VERSION}-gd php${PHP_VERSION}-intl php${PHP_VERSION}-json php${PHP_VERSION}-ldap php${PHP_VERSION}-mbstring php${PHP_VERSION}-memcached php${PHP_VERSION}-mysql php${PHP_VERSION}-opcache  php${PHP_VERSION}-soap php${PHP_VERSION}-tidy php${PHP_VERSION}-yaml php${PHP_VERSION}-zip"') 

#composer
RUN  curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

COPY tcpping /usr/bin/tcpping
RUN chmod 755 /usr/bin/tcpping

COPY init_container.sh /bin/
COPY hostingstart.html /home/site/wwwroot/hostingstart.html

RUN chmod 755 /bin/init_container.sh \
    && mkdir -p /home/LogFiles/ \
    && echo "root:Docker!" | chpasswd \
    && echo "cd /home" >> /root/.bashrc \
    && ln -s /home/site/wwwroot /var/www/html \
    && mkdir -p /opt/startup

# configure startup
COPY sshd_config /etc/ssh/
COPY ssh_setup.sh /tmp
COPY startup.sh /tmp/
RUN mkdir -p /opt/startup \
   && chmod -R +x /opt/startup \
   && mv /tmp/startup.sh /opt/startup/ \
   && chmod -R +x /opt/startup/startup.sh \
   && chmod -R +x /tmp/ssh_setup.sh \
   && (sleep 1;/tmp/ssh_setup.sh 2>&1 > /dev/null) \
   && rm -rf /tmp/*

ENV PORT 8080
ENV SSH_PORT 2222
EXPOSE 2222 8080
COPY sshd_config /etc/ssh/

ENV PATH ${PATH}:/home/site/wwwroot

RUN rm -f /etc/php/7.4/php.ini \
   && { \
                echo 'error_log=/dev/stderr'; \
                echo 'display_errors=Off'; \
                echo 'log_errors=On'; \
                echo 'display_startup_errors=Off'; \
                echo 'date.timezone=Europe/Paris'; \
    } > /etc/php/7.4/php.ini

COPY core/apache2.conf /etc/apache2/
COPY core/envvars /etc/apache2/
RUN rm -f /etc/apache2/conf-enabled/other-vhosts-access-log.conf \
	&& rm /etc/apache2/sites-enabled/000-default.conf && touch /var/log/cron.log \
	&& a2enmod rewrite expires headers && service apache2 restart \
	&& echo "syntax on\ncolorscheme desert"  > ~/.vimrc 

COPY core/swagger.conf /etc/apache2/sites-enabled/
WORKDIR /home/site/wwwroot

ENTRYPOINT ["/bin/init_container.sh"]
#clean
RUN apt-get clean && rm -rf /var/cache/apt/lists
