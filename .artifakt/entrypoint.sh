#!/bin/bash

set -e

echo ">>>>>>>>>>>>>> START CUSTOM ENTRYPOINT SCRIPT <<<<<<<<<<<<<<<<< "

# make sure folders are writable
chown -R www-data:www-data /data
mkdir -p /var/www/html/var/cache/prod && chown -R www-data:www-data /var/www/html/var/cache/prod
mkdir -p /var/www/html/var/cache/dev && chown -R www-data:www-data /var/www/html/var/cache/dev
echo DEBUG 
ls -la /var/www/html/var/cache

# set runtime env. vars on the fly
export APP_ENV=prod
export APP_DATABASE_NAME=${ARTIFAKT_MYSQL_DATABASE_NAME:-changeme}
export APP_DATABASE_USER=${ARTIFAKT_MYSQL_USER:-changeme}
export APP_DATABASE_PASSWORD=${ARTIFAKT_MYSQL_PASSWORD:-changeme}
export APP_DATABASE_HOST=${ARTIFAKT_MYSQL_HOST:-mysql}
export APP_DATABASE_PORT=${ARTIFAKT_MYSQL_PORT:-3306}

export DATABASE_URL=mysql://$APP_DATABASE_USER:$APP_DATABASE_PASSWORD@$APP_DATABASE_HOST:$APP_DATABASE_PORT/$APP_DATABASE_NAME

# generate jwt data if not present yet
su www-data -s /bin/bash -c '
  set -e
  if [[ ! -f /data/config/jwt/private.pem ]]; then
    source /data/passphrase
    jwt_passphrase=${JWT_PASSPHRASE:-$(grep ''^JWT_PASSPHRASE='' .env | cut -f 2 -d ''='')}
    echo "$jwt_passphrase" | openssl genpkey -out config/jwt/private.pem -pass stdin -aes256 -algorithm rsa -pkeyopt rsa_keygen_bits:4096
    echo "$jwt_passphrase" | openssl pkey -in config/jwt/private.pem -passin stdin -out config/jwt/public.pem -pubout
    setfacl -R -m u:www-data:rX -m u:"$(whoami)":rwX config/jwt
    setfacl -dR -m u:www-data:rX -m u:"$(whoami)":rwX config/jwt
  fi
'

wait-for $APP_DATABASE_HOST:$APP_DATABASE_PORT --timeout=180

su www-data -s /bin/bash -c 'php ./bin/console doctrine:migrations:status'

if [ $ARTIFAKT_IS_MAIN_INSTANCE == 1 ]; then
    source /.artifakt/install.sh
fi

echo ">>>>>>>>>>>>>> END CUSTOM ENTRYPOINT SCRIPT <<<<<<<<<<<<<<<<< "
