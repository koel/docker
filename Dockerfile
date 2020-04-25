FROM php:7.3.15-alpine as php-builder

# The version and repository to clone koel from.
ARG KOEL_CLONE_SOURCE=https://github.com/koel/koel.git
ARG KOEL_VERSION_REF=v4.3.1

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

# Install runtime dependencies.
RUN composer install --no-dev --optimize-autoloader

# Install and build frontend.
FROM alpine:3.11.6 as front-builder

# Add nodejs and yarn. bash and the other 8 deps are needed to build pngquant, which is a dev dependency for koel...
RUN apk add --no-cache nodejs \
    python3 bash lcms2-dev libpng-dev gcc g++ make autoconf automake \
    yarn

# Copy sources from php builder
COPY --from=php-builder /tmp/koel /tmp/koel

# Install, build frontend assets and then delete the sources to save disk space
RUN cd /tmp/koel/resources/assets && \
    yarn install --non-interactive && \
    cd /tmp/koel/ && \
    yarn install --non-interactive && \
    yarn run production && \
    rm -rf /tmp/koel/node_modules \
      /tmp/koel/resources/assets

# The runtime image.
FROM php:7.3.15-apache-buster

# Install dependencies.
RUN apt-get update && \
  apt-get install --yes --no-install-recommends \
    libapache2-mod-xsendfile \
    libzip-dev \
    zip \
    ffmpeg \
  && docker-php-ext-install \
    zip \
    pdo_mysql \
    exif \
  && apt-get clean

# Copy Apache configuration
COPY ./apache.conf /etc/apache2/sites-available/000-default.conf

# Deploy Apache configuration
RUN a2enmod rewrite

# Copy artifacts from build stage.
COPY --from=front-builder --chown=www-data:www-data /tmp/koel /var/www/html

# Music volume
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
