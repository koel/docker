FROM php:7.2.0-fpm-alpine3.6 as builder

# The version and repository to clone koel from.
ENV KOEL_CLONE_SOURCE https://github.com/phanan/koel.git
ENV KOEL_VERSION_REF v3.7.0

# Used to ensure only necessary dependencies are pulled when running yarn.
ENV NODE_ENV production

# The version of yarn to install.
ENV YARN_VERSION 1.3.2

# The version of php-composer to install.
ENV COMPOSER_VERSION 1.1.2

# Install dependencies.
RUN apk add --update \
  curl \
  gnupg \
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

# Install yarn. A modern apk package is only available in alpine 3.7.
RUN curl -o- -L https://yarnpkg.com/install.sh \
  | sh -s -- --version ${YARN_VERSION}

# Clone the repository.
RUN git clone $KOEL_CLONE_SOURCE -b $KOEL_VERSION_REF /tmp/koel

# Place artifacts here.
WORKDIR /tmp/koel

# Install runtime dependencies.
RUN composer install
RUN yarn install
RUN yarn run production

# The runtime image.
FROM php:7.2.0-fpm-alpine3.6

# Install dependencies.
RUN apk add --update \
  zlib-dev \
  php7-mbstring \
  php7-curl \
  php7-simplexml \
  && docker-php-ext-install zip

# TODO: Run Koel Init?
# TODO: Pin Versions

# Copy artifacts from build stage.
COPY --from=builder /tmp/koel /koel
