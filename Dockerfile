FROM php:7.2.0-fpm-alpine3.6 as builder

# TODO: Pin Versions

# The version and repository to clone koel from.
ENV KOEL_CLONE_SOURCE https://github.com/phanan/koel.git
ENV KOEL_VERSION_REF v3.7.0

# The version of yarn to install.
ENV YARN_VERSION 1.3.2

# The version of php-composer to install.
ENV COMPOSER_VERSION 1.1.2

# Install dependencies.
RUN apk add --update \
  nodejs=6.10.3-r1 \
  tar \
  curl \
  openssl \
  git \
  zlib-dev \
  php7-mbstring \
  php7-curl \
  php7-simplexml

# The apk version wasn't working so using docker-php-ext-install instead. Not
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

# Install yarn. A modern apk package is only available in alpine 3.7 which there
# is no php image for.
ADD https://yarnpkg.com/downloads/$YARN_VERSION/yarn-v${YARN_VERSION}.tar.gz /opt/yarn.tar.gz
RUN mkdir -p /opt/yarn/ && tar xf /opt/yarn.tar.gz --directory /opt/yarn --strip-components=1
ENV PATH $PATH:/opt/yarn/bin/
RUN yarn --version

# Clone the repository.
RUN git clone $KOEL_CLONE_SOURCE -b $KOEL_VERSION_REF /tmp/koel

# Place artifacts here.
WORKDIR /tmp/koel

# Install runtime dependencies.
RUN composer install
RUN yarn install

# The runtime image.
FROM php:7.2.0-fpm-alpine3.6

# Install dependencies.
RUN apk add --update \
  zlib-dev \
  php7-mbstring \
  php7-curl \
  php7-simplexml \
  && docker-php-ext-install zip

# Copy artifacts from build stage.
COPY --from=builder /tmp/koel /var/www/html
