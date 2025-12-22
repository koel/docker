# The runtime image.
FROM php:8.4.8-apache-bookworm

# The koel version to download
ARG KOEL_VERSION_REF=v8.2.0

# Download the koel release matching the version and remove anything not necessary for production
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
    .htaccess.example

# Install koel runtime dependencies.
RUN apt-get update \
  && apt-get install --yes --no-install-recommends \
    cron \
    libapache2-mod-xsendfile \
    libzip-dev \
    zip \
    ffmpeg \
    locales \
    libpng-dev \
    libjpeg62-turbo-dev \
    libpq-dev \
    libwebp-dev \
    libavif-dev \
    # to have a simple editor
    nano \
  && docker-php-ext-configure gd --with-jpeg --with-webp --with-avif \
  # https://laravel.com/docs/8.x/deployment#server-requirements
  # ctype, fileinfo, json, mbstring, openssl, tokenizer and xml are already activated in the base image
  && docker-php-ext-install \
    bcmath \
    exif \
    gd \
    pdo \
    pdo_mysql \
    pdo_pgsql \
    pgsql \
    zip \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/* \
  # Create the music volume so it has the correct permissions
  && mkdir /music \
  && chown www-data:www-data /music \
  # Create the search-indexes volume so it has the correct permissions
  && mkdir -p /var/www/html/storage/search-indexes \
  && chown www-data:www-data /var/www/html/storage/search-indexes \
  # Set locale to prevent removal of non-ASCII path characters when transcoding with ffmpeg
  # See https://github.com/koel/docker/pull/91
  && echo "en_US.UTF-8 UTF-8" > /etc/locale.gen \
  && /usr/sbin/locale-gen

# Copy Apache configuration
COPY ./apache.conf /etc/apache2/sites-available/000-default.conf

# Copy php.ini
COPY ./php.ini "$PHP_INI_DIR/php.ini"
# /usr/local/etc/php/php.ini

# Deploy Apache configuration
RUN a2enmod rewrite

# Copy the downloaded release
RUN cp -R /tmp/koel/. /var/www/html
RUN [ ! -f /var/www/html/public/manifest.json ] && cp /var/www/html/public/manifest.json.example /var/www/html/public/manifest.json || true
RUN chown -R www-data:www-data /var/www/html

# Volumes for the music files and search index
# This declaration must be AFTER creating the folders and setting their permissions
# and AFTER changing to non-root user.
# Otherwise, they are owned by root and the user cannot write to them.
VOLUME ["/music", "/var/www/html/storage/search-indexes"]

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

# Setup bootstrap script.
COPY koel-entrypoint /usr/local/bin/
ENTRYPOINT ["koel-entrypoint"]
CMD ["apache2-foreground"]

EXPOSE 80

# Check that the homepage is displayed
HEALTHCHECK --start-period=30s --interval=5m --timeout=5s \
  CMD curl -f http://localhost/sw.js || exit 1
