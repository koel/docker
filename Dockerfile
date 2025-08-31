# The runtime image.
FROM alpine:3.22.1
# The koel version to download
ARG KOEL_VERSION_REF=v7.12.0

RUN apk add --no-cache --no-interactive \
curl \
apache2 \
apache2-proxy \
    # php-fpm because it's so much faster and efficient in handling web requests, php for cli commands. need to find a way to maybe not have both bloating the image
    php \
    php-fpm \
    libzip-dev \
    zip \
    ffmpeg \
    libpng-dev \
    libjpeg-turbo-dev \
    libpq-dev \
    libwebp-dev \
    libavif-dev \
    # https://laravel.com/docs/8.x/deployment#server-requirements
  php83-ctype \
  php83-fileinfo \
  php83-json \
  php83-mbstring \
  php83-openssl \
  php83-tokenizer \
  php83-xml \
  php83-dom \
    php83-bcmath \
    php83-exif \
    php83-gd \
    php83-pdo \
    php83-pdo_mysql \
    php83-pdo_pgsql \
    php83-pgsql \
    php83-zip \
    php83-session \
    busybox-suid \
  musl-locales \
  musl-locales-lang \
  tzdata \
   # as well as nano for easier debugging and updating configs
    nano \
    ncdu \
  # Set locale to prevent removal of non-ASCII path characters when transcoding with ffmpeg. do this first so all the php configurations make use of this as well
# See https://github.com/koel/docker/pull/91 & https://krython.com/post/resolving-alpine-linux-locale-issues/
  && echo "en_US.UTF-8 UTF-8" > /etc/locale.gen \
  && export LANG=en_US.UTF-8 \
  && export LC_ALL=en_US.UTF-8 \
  && echo 'export LANG=en_US.UTF-8' >> /etc/profile \
  && echo 'export LC_ALL=en_US.UTF-8' >> /etc/profile



RUN adduser -S www-data -G www-data -h /var/www/ -H
RUN mkdir -p /var/www/html && chown www-data:www-data /var/www/html
USER www-data

# Download koel and put the files in the right places
RUN curl -L https://github.com/koel/koel/releases/download/${KOEL_VERSION_REF}/koel-${KOEL_VERSION_REF}.tar.gz | tar -xz -C /tmp \
  && cd /tmp/koel/ \
  # Cleanup the junk from the tar, probably should rework the build at some point to not exclude things not useful outside of dev at that layer already
  && rm -rf .editorconfig \
    .eslintignore \
    .eslintrc \
    .git \
    .gitattributes \
    .github \
    .gitignore \
    .gitmodules \
    .gitpod.dockerfile \
    .gitpod.yml \
    api-docs \
    cypress \
    cypress.json \
    nginx.conf.example \
    package.json \
    phpstan.neon.dist \
    phpunit.xml.dist \
    resources/artifacts/ \
    ruleset.xml \
    scripts/ \
    tag.sh \
    vite.config.js \
    tests/songs \
    pnpm-lock.yaml \
    .husky \
    README.md \
    CODE_OF_CONDUCT.md \
    .vscode \
    tailwind.config.js \
    eslint.config.js \
    postcss.config.cjs \
    commitling.config.js \
    .htaccess.example \
    && cp -R /tmp/koel/. /var/www/html \
  # we use php-pfm because it's plain better, but that means htaccess php directives can't be parsed here
  && sed -e '/^php*/ s/^#*/#/' -i /var/www/html/public/.htaccess \
  # Create the search-indexes volume so it has the correct permissions
  && mkdir -p /var/www/html/storage/search-indexes \
  && [ ! -f /var/www/html/public/manifest.json ] && cp /var/www/html/public/manifest.json.example /var/www/html/public/manifest.json || true \
  && chown -R www-data:www-data /var/www/html \
  # Cleanup the temp download
  && rm -rf /tmp/*


# Install x-sendfile for apache2, fix home folder
USER root
RUN apk add --no-cache apache2-dev gcc musl-dev \
  && curl -o mod_xsendfile.c https://tn123.org/mod_xsendfile/mod_xsendfile.c \
  && apxs -cia mod_xsendfile.c \
  && rm mod_xsendfile.* \
  && apk del --no-cache apache2-dev gcc musl-dev \
  && mkdir /var/www/lib \
  && ln -s /usr/lib/apache2 /var/www/lib/apache2


# Create /tmp/koel
RUN mkdir -p /tmp/koel \
  && chown www-data:www-data /tmp/koel \
  && chmod 755 /tmp/koel\
  # Create the music volume so 
  && mkdir /music \
  && chown www-data:www-data /music \
  && mkdir -p /cache/img/artists \
  && mkdir -p /cache/img/avatars \
  && mkdir -p /cache/img/covers \
  && mkdir -p /cache/img/playlists \
  && mkdir -p /cache/img/radio-stations \
  && chown -R www-data:www-data /cache \
  && chmod -R 755 /cache \
  # redirect public img storage into the cache, putting this here and not with the other koel file setups because it makes more sense here, and they are empty folder so don't have a significant impact on file size
  && rm -r /var/www/html/public/img/artists \
  && rm -r /var/www/html/public/img/avatars \
  && rm -r /var/www/html/public/img/covers \
  && rm -r /var/www/html/public/img/playlists \
  && ln -s /cache/img/artists /var/www/html/public/img/artists \
  && ln -s /cache/img/avatars /var/www/html/public/img/avatars \
  && ln -s /cache/img/covers /var/www/html/public/img/covers \
  && ln -s /cache/img/playlists /var/www/html/public/img/playlists \
  && ln -s /cache/img/radio-stations /var/www/html/public/img/radio-stations

# Volumes for the music files, search index and image cache
# This declaration must be AFTER creating the folders and setting their permissions
# and AFTER changing to non-root user.
# Otherwise, they are owned by root and the user cannot write to them.
VOLUME ["/music", "/var/www/html/storage/search-indexes", "/cache"]


# Copy Apache configuration
COPY apache/site.conf /etc/apache2/conf.d/
COPY apache/httpd.conf /etc/apache2/
COPY apache/www.conf /etc/php83/php-fpm.d/

# Copy php.ini
COPY ./php.ini "$PHP_INI_DIR/php.ini"

# make crontab file
RUN touch /etc/crontabs/www-data

# Apply lalvel optimalizations
RUN cd /var/www/html \
  && php artisan route:cache \
  && php artisan event:cache \
  && php artisan view:cache


ENV FFMPEG_PATH=/usr/bin/ffmpeg \
    MEDIA_PATH=/music \
    STREAMING_METHOD=x-sendfile \
    LANG=en_US.UTF-8 \
    LANGUAGE=en_US:en \
    LC_ALL=en_US.UTF-8  \
    APACHE_LOG_DIR=/var/log/apache2

# Setup bootstrap script.
COPY koel-entrypoint /usr/local/bin/
COPY koel-init /usr/local/bin/
ENTRYPOINT ["koel-entrypoint"]
CMD [""]

EXPOSE 80

# Check that the homepage is displayed
HEALTHCHECK --start-period=30s --interval=5m --timeout=5s \
  CMD curl -f http://localhost/sw.js || exit 1

  