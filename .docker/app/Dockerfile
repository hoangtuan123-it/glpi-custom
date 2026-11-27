FROM ghcr.io/glpi-project/glpi-development-env:8.4

USER root

# Allow extra PHP configuration to be placed in a dedicated folder than can serve
# as a volume
ENV PHP_INI_SCAN_DIR=/usr/local/etc/php/conf.d/:/usr/local/etc/php/custom_conf.d/
RUN mkdir /usr/local/etc/php/custom_conf.d/

COPY .docker/php/opcache.ini /usr/local/etc/php/conf.d/20-opcache.ini
COPY .docker/apache/it-central-cache.conf /etc/apache2/conf-available/it-central-cache.conf
RUN a2enmod headers expires deflate && a2enconf it-central-cache
RUN grep -q '^    SetEnv GLPI_ENVIRONMENT_TYPE development$' /etc/apache2/sites-available/000-default.conf \
  && sed -i '0,/SetEnv GLPI_ENVIRONMENT_TYPE development/s//SetEnv GLPI_ENVIRONMENT_TYPE production/' /etc/apache2/sites-available/000-default.conf

# Workaround to make apache use same UID/GID as host user.
ARG HOST_GROUP_ID=1000
RUN groupmod --gid ${HOST_GROUP_ID} www-data
ARG HOST_USER_ID=1000
RUN usermod --uid ${HOST_USER_ID} www-data

# Allow login as www-data user and allow it to execute sudo
RUN usermod --shell /bin/bash www-data
RUN echo "www-data ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# Make www-data user home persistent for cache purpose.
RUN mkdir --parents /home/www-data \
  && chown www-data:www-data /home/www-data \
  && usermod --home /home/www-data www-data
VOLUME /home/www-data

USER www-data
