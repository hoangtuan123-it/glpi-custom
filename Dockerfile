FROM glpi/glpi:11.0.9

COPY --chown=www-data:www-data . /var/www/glpi/

RUN rm -f /var/www/glpi/src/Glpi/Kernel/Listener/RequestListener/CheckStartupErrorsListener.php

WORKDIR /var/www/glpi
USER www-data

HEALTHCHECK --interval=30s --timeout=5s --start-period=60s --retries=3 \
  CMD php -r '$headers = @get_headers("http://127.0.0.1/"); exit($headers !== false && preg_match("/^HTTP\\/\\S+ 200\\b/", $headers[0]) === 1 ? 0 : 1);'
