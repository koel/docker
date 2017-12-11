FROM php:7.2.0-apache-stretch as builder

# TODO: Pin Versions

# The version and repository to clone koel from.
ENV KOEL_CLONE_SOURCE https://github.com/phanan/koel.git
ENV KOEL_VERSION_REF v3.7.0

# The version of php-composer to install.
ENV COMPOSER_VERSION 1.1.2

# The version of nodejs to install.
ENV NODE_VERSION node_8.x

# Install dependencies to install dependencies.
RUN apt-get update && apt-get install --yes gnupg2 apt-transport-https

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
  nodejs \
  yarn \
  git \
  php-mbstring \
  php-curl \
  php-xml \
  php7.0-zip \
  zlib1g-dev

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
	chmod +x /usr/local/bin/composer

RUN composer --version

# Clone the koel repository.
RUN git clone $KOEL_CLONE_SOURCE -b $KOEL_VERSION_REF /tmp/koel

# Place artifacts here.
WORKDIR /tmp/koel

# Install runtime dependencies.
RUN composer install
RUN yarn install

# The runtime image.
FROM php:7.2.0-apache-stretch

# Install dependencies.
RUN apt-get update && \
  apt-get install --yes \
  php-mbstring \
  php-curl \
  php-xml \
  php7.0-zip \
  zlib1g-dev

RUN docker-php-ext-install zip

# Copy artifacts from build stage.
COPY --chown=www-data:www-data --from=builder /tmp/koel /var/www/html

# Koel makes use of Larvel's pretty URLs. This requires some additional
# configuration: https://laravel.com/docs/4.2#pretty-urls
COPY --chown=www-data:www-data ./.htaccess /var/www/html
RUN a2enmod rewrite

RUN mkdir -p /var/www/html/storage/log
RUN chown -R www-data:www-data /var/www/html/storage/log
