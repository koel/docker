FROM php:7.2.0-apache-stretch as builder

# The version and repository to clone koel from.
ARG KOEL_CLONE_SOURCE=https://github.com/phanan/koel.git
ARG KOEL_VERSION_REF=v4.1.0

# The version of php-composer to install.
ARG COMPOSER_VERSION=1.1.2

# The version of nodejs to install.
ARG NODE_VERSION=node_8.x

# Install dependencies to install dependencies.
RUN apt-get update && apt-get install --yes \
  gnupg=2.1.18-8~deb9u4 \
  apt-transport-https=1.4.9 \
  libpng-dev=1.6.28-1+deb9u1

# Add node repository.
RUN curl --silent https://deb.nodesource.com/gpgkey/nodesource.gpg.key \
    | apt-key add - && \
  echo "deb https://deb.nodesource.com/${NODE_VERSION} stretch main" \
    | tee /etc/apt/sources.list.d/nodesource.list && \
  echo "deb-src https://deb.nodesource.com/${NODE_VERSION} stretch main" \
    | tee --append /etc/apt/sources.list.d/nodesource.list

# Add yarn repository.
RUN curl --silent --show-error https://dl.yarnpkg.com/debian/pubkey.gpg \
    | apt-key add - && \
  echo "deb https://dl.yarnpkg.com/debian/ stable main" \
    | tee /etc/apt/sources.list.d/yarn.list

# These are dependencies needed both at build time and at runtime.
ARG RUNTIME_DEPS="\
  libxml2-dev \
  zlib1g-dev \
  libcurl4-openssl-dev"

# Install dependencies.
RUN apt-get update && \
  apt-get install --yes \
  nodejs \
  yarn \
  git \
  ${RUNTIME_DEPS}

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
RUN mkdir /var/www/.yarn && chown www-data:www-data /var/www/.yarn && \
    mkdir /var/www/.composer && chown www-data:www-data /var/www/.composer && \
    mkdir /var/www/.cache && chown www-data:www-data /var/www/.cache

# Change to a restricted user.
USER www-data

# Clone the koel repository.
RUN git clone ${KOEL_CLONE_SOURCE} -b ${KOEL_VERSION_REF} --recurse-submodules /tmp/koel

# Place artifacts here.
WORKDIR /tmp/koel

# Install runtime dependencies.
RUN composer install --no-dev --optimize-autoloader
# Install and build static assets.
RUN cd /tmp/koel/resources/assets && yarn install && cd /tmp/koel/ && yarn install && yarn run production

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

# Copy artifacts from build stage.
COPY --from=builder /tmp/koel /var/www/html

# Copy Apache configuration
COPY ./apache.conf /etc/apache2/sites-available/000-default.conf

# Koel makes use of Larvel's pretty URLs. This requires some additional
# configuration: https://laravel.com/docs/4.2#pretty-urls
COPY ./.htaccess /var/www/html

# Fix permissions.
RUN chown www-data:www-data /var/www/html/.htaccess
RUN a2enmod rewrite

# Music volume
VOLUME ["/media"]

# Setup bootstrap script.
COPY koel-entrypoint /usr/local/bin/
ENTRYPOINT ["koel-entrypoint"]
CMD ["apache2-foreground"]

EXPOSE 80
