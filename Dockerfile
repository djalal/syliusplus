FROM registry.artifakt.io/sylius:1.11-apache

ENV APP_DEBUG=0
ENV APP_ENV=prod

ARG CODE_ROOT=.

COPY --chown=www-data:www-data $CODE_ROOT /var/www/html

WORKDIR /var/www/html

USER www-data
RUN [ -f composer.lock ] && composer install --no-cache --optimize-autoloader --no-interaction --no-ansi --no-dev || true
USER root

# copy the artifakt folder on root
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
RUN  if [ -d .artifakt ]; then cp -rp /var/www/html/.artifakt /.artifakt/; fi

# run custom scripts build.sh
# hadolint ignore=SC1091
RUN --mount=source=artifakt-custom-build-args,target=/tmp/build-args \
  if [ -f /tmp/build-args ]; then source /tmp/build-args; fi && \
  if [ -f /.artifakt/build.sh ]; then source /.artifakt/build.sh; fi

# Workaround for QEMU on Apple M1 
# Some credit goes to: https://www.linode.com/community/questions/16977/server-fails-after-installing-certbot-mpm-run-failed-exiting#answer-66578
RUN echo 'Mutex posixsem' >> /etc/apache2/apache2.conf