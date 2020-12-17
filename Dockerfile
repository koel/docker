FROM php:7.3.15-alpine as php-builder

# The version and repository to clone koel from.
ARG KOEL_CLONE_SOURCE=https://github.com/koel/koel.git
ARG KOEL_VERSION_REF=v4.4.0

# Install git and composer
RUN apk add --no-cache composer \
    git \
  && docker-php-ext-install exif

# Change to a restricted user.
USER www-data

# Shallow-clone the koel repository and remove anything not necessary for production
RUN git clone ${KOEL_CLONE_SOURCE} -b ${KOEL_VERSION_REF} --recurse-submodules --single-branch --depth 1 /tmp/koel && \
  cd /tmp/koel && \
  rm -rf .editorconfig \
    .eslintignore \
    .git \
    .gitattributes \
    .github \
    .gitignore \
    .gitmodules \
    .gitpod.dockerfile \
    .gitpod.yml \
    .travis.yml \
    cypress \
    cypress.json \
    nitpick.json \
    phpunit.xml \
    resources/artifacts \
    tests

# Place artifacts here.
WORKDIR /tmp/koel

# Install koel composer dependencies.
RUN composer install --no-dev --optimize-autoloader

# Install and build frontend.
FROM alpine:3.12.3 as front-builder

# Add nodejs and yarn. python2, make and g++ are needed to build node-sass on ARM arch.
RUN apk add --no-cache nodejs \
    yarn \
    python2 make g++

# Copy sources from php builder
COPY --from=php-builder /tmp/koel /tmp/koel

# Install, build frontend assets and then delete the sources to save disk space
RUN cd /tmp/koel/resources/assets && \
    yarn install --non-interactive --network-timeout 100000 && \
    cd /tmp/koel/ && \
    # Skip cypress download and installation. It is not needed for a production image
    CYPRESS_INSTALL_BINARY=0 yarn install --non-interactive && \
    yarn run production && \
    rm -rf /tmp/koel/node_modules \
      /tmp/koel/resources/assets

# The runtime image.
FROM php:7.3.15-apache-buster

# Install koel runtime dependencies.
RUN apt-get update && \
  apt-get install --yes --no-install-recommends \
    libapache2-mod-xsendfile \
    libzip-dev \
    zip \
    ffmpeg \
    libpng-dev \
    libjpeg62-turbo-dev \
  && docker-php-ext-configure gd --with-jpeg-dir=/usr/include/ \
  && docker-php-ext-install \
    zip \
    pdo_mysql \
    exif \
    gd \
  && apt-get clean \
  # Create the music volume so it has the correct permissions
  && mkdir /music \
  && chown www-data:www-data /music

# Copy Apache configuration
COPY ./apache.conf /etc/apache2/sites-available/000-default.conf

# Copy php.ini
COPY ./php.ini "$PHP_INI_DIR/php.ini"
# /usr/local/etc/php/php.ini

# Deploy Apache configuration
RUN a2enmod rewrite

# Copy artifacts from build stage.
COPY --from=front-builder --chown=www-data:www-data /tmp/koel /var/www/html

# Music volume
# This needs to be AFTER creating the folders and setting their permissions
# and AFTER changing to non-root user.
# Otherwise, they are owned by root and the user cannot write to them.
VOLUME ["/music"]

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
