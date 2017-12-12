FROM php:7.2.0-apache-stretch as builder

# The version and repository to clone koel from.
ARG KOEL_CLONE_SOURCE=https://github.com/phanan/koel.git
ARG KOEL_VERSION_REF=v3.7.0

# The version of php-composer to install.
ARG COMPOSER_VERSION=1.1.2

# The version of nodejs to install.
ARG NODE_VERSION=node_8.x

# These are dependencies needed both at build time and at runtime.
ARG RUNTIME_DEPS="\
  php7.0-mbstring=7.0.19-1 \
  php7.0-curl=7.0.19-1 \
  php7.0-xml=7.0.19-1 \
  php7.0-pgsql=7.0.19-1 \
  php7.0-mysql=7.0.19-1 \
  zlib1g-dev=1:1.2.8.dfsg-5"

# Install dependencies to install dependencies.
RUN apt-get update && apt-get install --yes \
  gnupg2=2.1.18-8~deb9u1 \
  apt-transport-https=1.4.8

# Add node repository.
RUN curl --silent https://deb.nodesource.com/gpgkey/nodesource.gpg.key \
    | apt-key add - && \
  echo "deb https://deb.nodesource.com/$NODE_VERSION stretch main" \
    | tee /etc/apt/sources.list.d/nodesource.list && \
  echo "deb-src https://deb.nodesource.com/$NODE_VERSION stretch main" \
    | tee --append /etc/apt/sources.list.d/nodesource.list

# Add yarn repository.
RUN curl --silent --show-error https://dl.yarnpkg.com/debian/pubkey.gpg \
    | apt-key add - && \
  echo "deb https://dl.yarnpkg.com/debian/ stable main" \
    | tee /etc/apt/sources.list.d/yarn.list

# Install dependencies.
RUN apt-get update && \
  apt-get install --yes \
  nodejs=8.9.3-1nodesource1 \
  yarn=1.3.2-1 \
  git=1:2.11.0-3+deb9u2 \
  $RUNTIME_DEPS

# The repo version wasn't working so using docker-php-ext-install instead. Not
# using docker-php-ext-install for every extension because it is badly
# documented.
RUN docker-php-ext-install zip

# Install composer from getcomposer.org. An apk package is only available in
# edge (> 3.7).
RUN curl -sS https://getcomposer.org/installer \
    | php -- \
          --install-dir=/usr/local/bin \
          --filename=composer \
          --version=${COMPOSER_VERSION} && \
	chmod +x /usr/local/bin/composer && \
  composer --version

# Clone the koel repository.
RUN git clone $KOEL_CLONE_SOURCE -b $KOEL_VERSION_REF /tmp/koel

# Place artifacts here.
WORKDIR /tmp/koel

# Install runtime dependencies.
RUN composer install
RUN yarn install

# The runtime image.
FROM php:7.2.0-apache-stretch

# These are dependencies needed both at build time and at runtime. This is
# repeated because docker doesn't seem to have a way to share args across build
# contexts.
ARG RUNTIME_DEPS="\
  php7.0-mbstring=7.0.19-1 \
  php7.0-curl=7.0.19-1 \
  php7.0-xml=7.0.19-1 \
  php7.0-pgsql=7.0.19-1 \
  php7.0-mysql=7.0.19-1 \
  zlib1g-dev=1:1.2.8.dfsg-5"

# Install dependencies.
RUN apt-get update && \
  apt-get install --yes $RUNTIME_DEPS && \
  docker-php-ext-install zip && \
  apt-get clean

# Copy artifacts from build stage.
COPY --chown=www-data:www-data --from=builder /tmp/koel /var/www/html

# Koel makes use of Larvel's pretty URLs. This requires some additional
# configuration: https://laravel.com/docs/4.2#pretty-urls
COPY --chown=www-data:www-data ./.htaccess /var/www/html
RUN a2enmod rewrite

# Make logging directory with correct permissions.
RUN mkdir -p /var/www/html/storage/log
RUN chown -R www-data:www-data /var/www/html/storage/log

EXPOSE 80
