# The runtime image.
FROM alpine:3.23.2

# The koel version to download
ARG KOEL_VERSION_REF=v8.3.0

# Install dependencies
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
  php84-ctype \
  php84-fileinfo \
  php84-json \
  php84-mbstring \
  php84-openssl \
  php84-tokenizer \
  php84-xml \
  php84-dom \
  php84-bcmath \
  php84-exif \
  php84-gd \
  php84-pdo \
  php84-pdo_mysql \
  php84-pdo_pgsql \
  php84-pgsql \
  php84-zip \
  php84-session \
  busybox-suid \
  musl-locales \
  musl-locales-lang \
  tzdata \
   # as well as nano for easier debugging and updating configs
    nano \
  # Set locale to prevent removal of non-ASCII path characters when transcoding with ffmpeg. do this first so all the php configurations make use of this as well
# See https://github.com/koel/docker/pull/91 & https://krython.com/post/resolving-alpine-linux-locale-issues/
  && echo "en_US.UTF-8 UTF-8" > /etc/locale.gen \
  && export LANG=en_US.UTF-8 \
  && export LC_ALL=en_US.UTF-8 \
  && echo 'export LANG=en_US.UTF-8' >> /etc/profile \
  && echo 'export LC_ALL=en_US.UTF-8' >> /etc/profile

# Install x-sendfile for apache2, fix home folder
RUN apk add --no-cache apache2-dev gcc musl-dev \
  && curl -o mod_xsendfile.c https://tn123.org/mod_xsendfile/mod_xsendfile.c \
  && apxs -cia mod_xsendfile.c \
  && rm mod_xsendfile.* \
  && apk del --no-cache apache2-dev gcc musl-dev \
  && mkdir /var/www/lib \
  && ln -s /usr/lib/apache2 /var/www/lib/apache2

# Copy Apache configuration
COPY apache/site.conf /etc/apache2/conf.d/
COPY apache/httpd.conf /etc/apache2/
COPY apache/www.conf /etc/php84/php-fpm.d/

# Copy php.ini
COPY ./php.ini "$PHP_INI_DIR/php.ini"

# make crontab file
RUN touch /etc/crontabs/www-data

  
# Setup user and folders
RUN adduser -S www-data -G www-data -h /var/www/ -H
RUN mkdir -p /var/www/html && chown www-data:www-data /var/www/html && chown www-data /var/log/php84 && mkdir /var/log/apache && chown www-data /var/log/apache
  
# setup volume folders
RUN mkdir /music \
&& chown www-data:www-data /music \
# Create the search-indexes volume so it has the correct permissions
&& mkdir -p /var/www/html/storage/search-indexes \
&& chown -R www-data:www-data /var/www/html

# Volumes for the music files and search index
# This declaration must be AFTER creating the folders and setting their permissions
# and AFTER changing to non-root user.
# Otherwise, they are owned by root and the user cannot write to them.
VOLUME ["/music", "/var/www/html/storage/search-indexes"]
  
# Do the actual application setup as www-data user
  
# Download the koel release matching the version and remove anything not necessary for production, then move it to the right place. All in one command so we don't duplicate data across layers
RUN curl -L https://github.com/koel/koel/releases/download/${KOEL_VERSION_REF}/koel-${KOEL_VERSION_REF}.tar.gz | tar -xz -C /tmp \
  && chown www-data:www-data /tmp/koel \
  && chmod 755 /tmp/koel \
  && cd /tmp/koel/ \
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
    .cursor/ \
    .junie/ \
    .husky/ \
    .vscode/ \
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
    tests/songs/ \
    pnpm-lock.yaml \
    README.md \
    CODE_OF_CONDUCT.md \
    tailwind.config.js \
    eslint.config.js \
    postcss.config.cjs \
    commitlint.config.js \
    .htaccess.example \
    CLAUDE.md \
  && cp -R /tmp/koel/. /var/www/html \
  && chown -R www-data:www-data /var/www/html \
  && mv /var/www/html/public/manifest.json.example /var/www/html/public/manifest.json \
  # we use php-pfm because it's plain better, but that means htaccess php directives can't be parsed here
  && sed -e '/^php*/ s/^#*/#/' -i /var/www/html/public/.htaccess \
  && rm -R /tmp/koel

USER www-data
  
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
    LC_ALL=en_US.UTF-8

USER root
# Setup bootstrap script.
COPY koel-entrypoint /usr/local/bin/
COPY koel-init /usr/local/bin/
WORKDIR /var/www/html
ENTRYPOINT ["koel-entrypoint"]
CMD [""]

EXPOSE 80

# Check that the homepage is displayed
HEALTHCHECK --start-period=30s --interval=5m --timeout=5s \
  CMD curl -f http://localhost/sw.js || exit 1
