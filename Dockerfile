FROM php:7.2.0-apache-stretch as php-builder

# The version and repository to clone koel from.
ARG KOEL_CLONE_SOURCE=https://github.com/phanan/koel.git
ARG KOEL_VERSION_REF=v4.1.0

# The version of php-composer to install.
ARG COMPOSER_VERSION=1.1.2

# These are dependencies needed both at build time and at runtime.
ARG RUNTIME_DEPS="\
  libxml2-dev \
  zlib1g-dev \
  libcurl4-openssl-dev"

# Install dependencies to install dependencies.
RUN apt-get update && apt-get install --yes --no-install-recommends \
  gnupg=2.1.18-8~deb9u4 \
  apt-transport-https=1.4.9 \
  libpng-dev=1.6.28-1+deb9u1 \
  git \
  ${RUNTIME_DEPS} && \
  apt-get clean

# Install composer from getcomposer.org. An apk package is only available in
# edge (> 3.7).
RUN curl -sS https://getcomposer.org/installer \
    | php -- \
          --install-dir=/usr/local/bin \
          --filename=composer \
          --version=${COMPOSER_VERSION} && \
	chmod +x /usr/local/bin/composer && \
  composer --version

ARG PHP_BUILD_DEPS="zip mbstring curl xml exif"

# The repo version wasn't working so using docker-php-ext-install instead. Not
# using docker-php-ext-install for every extension because it is badly
# documented.
RUN docker-php-ext-install ${PHP_BUILD_DEPS}

# Create cache dirs for package managers and dependencies.
RUN mkdir /var/www/.composer && chown www-data:www-data /var/www/.composer && \
    mkdir /var/www/.cache && chown www-data:www-data /var/www/.cache

# Change to a restricted user.
USER www-data

# Clone the koel repository.
RUN git clone ${KOEL_CLONE_SOURCE} -b ${KOEL_VERSION_REF} --recurse-submodules /tmp/koel

# Place artifacts here.
WORKDIR /tmp/koel

# Install runtime dependencies.
RUN composer install --no-dev --optimize-autoloader

# Install and build frontend. Alpine 3.10 Needed for Node.js 10. Koel can't be built on Node 12.
FROM alpine:3.10 as front-builder

# Add nodejs and yarn. bash and the other 8 deps are needed to build pngquant, which is a dev dependency for koel...
RUN apk add --no-cache nodejs \
    bash lcms2-dev libpng-dev gcc g++ make autoconf automake \
    yarn

# Copy sources from php builder
COPY --from=php-builder /tmp/koel /tmp/koel

# Install and build static assets.
RUN cd /tmp/koel/resources/assets && \
    yarn install --non-interactive && \
    cd /tmp/koel/ && \
    yarn install --non-interactive && yarn run production

# The runtime image.
FROM php:7.2.0-apache-stretch

# These are dependencies needed both at build time and at runtime. This is
# repeated because docker doesn't seem to have a way to share args across build
# contexts.
ARG RUNTIME_DEPS="\
  libcurl4-openssl-dev \
  libapache2-mod-xsendfile \
  zlib1g-dev \
  libxml2-dev \
  faad \
  ffmpeg"

ARG PHP_RUNTIME_DEPS="\
  mbstring \
  curl \
  xml \
  zip \
  pdo \
  pdo_mysql \
  exif"

# Install dependencies.
RUN apt-get update && \
  apt-get install --yes ${RUNTIME_DEPS} && \
  docker-php-ext-install ${PHP_RUNTIME_DEPS} && \
  apt-get clean

# Copy Apache configuration
COPY ./apache.conf /etc/apache2/sites-available/000-default.conf

# Deploy Apache configuration
RUN a2enmod rewrite

# Copy artifacts from build stage.
COPY --from=front-builder --chown=www-data:www-data /tmp/koel /var/www/html

# Koel makes use of Laravel's pretty URLs. This requires some additional
# configuration https://laravel.com/docs/4.2#pretty-urls
COPY --chown=www-data:www-data ./.htaccess /var/www/html

# Music volume
VOLUME ["/media"]

# Setup bootstrap script.
COPY koel-entrypoint /usr/local/bin/
ENTRYPOINT ["koel-entrypoint"]
CMD ["apache2-foreground"]

EXPOSE 80
