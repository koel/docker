# Download koel's released archive
FROM alpine:3.14.0 as release-downloader

# The koel version to download
ARG KOEL_VERSION_REF=v5.1.4

# Install curl to download the release tar.gz
RUN apk add --no-cache curl

# Download the koel release matching the version and remove anything not necessary for production
RUN curl -L https://github.com/koel/koel/releases/download/${KOEL_VERSION_REF}/koel-${KOEL_VERSION_REF}.tar.gz | tar -xz -C /tmp \
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
    composer.lock \
    cypress \
    cypress.json \
    nginx.conf.example \
    package.json \
    phpstan.neon.dist \
    phpunit.xml.dist \
    resources/artifacts/ \
    resources/assets/ \
    ruleset.xml \
    scripts/ \
    tests \
    webpack.config.js \
    webpack.mix.js \
    yarn.lock

# The runtime image.
FROM php:7.4.21-apache-buster

# Install koel runtime dependencies.
RUN apt-get update && \
  apt-get install --yes --no-install-recommends \
    libapache2-mod-xsendfile \
    libzip-dev \
    zip \
    ffmpeg \
    libpng-dev \
    libjpeg62-turbo-dev \
    libpq-dev \
  && docker-php-ext-configure gd --with-jpeg \
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
  # Create the music volume so it has the correct permissions
  && mkdir /music \
  && chown www-data:www-data /music \
  # Create the search-indexes volume so it has the correct permissions
  && mkdir -p /var/www/html/storage/search-indexes \
  && chown www-data:www-data /var/www/html/storage/search-indexes

# Copy Apache configuration
COPY ./apache.conf /etc/apache2/sites-available/000-default.conf

# Copy php.ini
COPY ./php.ini "$PHP_INI_DIR/php.ini"
# /usr/local/etc/php/php.ini

# Deploy Apache configuration
RUN a2enmod rewrite

# Copy the downloaded release
COPY --from=release-downloader --chown=www-data:www-data /tmp/koel /var/www/html

# Volumes for the music files and search index
# This declaration must be AFTER creating the folders and setting their permissions
# and AFTER changing to non-root user.
# Otherwise, they are owned by root and the user cannot write to them.
VOLUME ["/music", "/var/www/html/storage/search-indexes"]

ENV FFMPEG_PATH=/usr/bin/ffmpeg \
    MEDIA_PATH=/music \
    STREAMING_METHOD=x-sendfile

# Setup bootstrap script.
COPY koel-entrypoint /usr/local/bin/
ENTRYPOINT ["koel-entrypoint"]
CMD ["apache2-foreground"]

EXPOSE 80

# Check that the homepage is displayed
HEALTHCHECK --interval=5m --timeout=5s \
  CMD curl -f http://localhost/ || exit 1
