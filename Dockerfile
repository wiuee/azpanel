# syntax=docker/dockerfile:1

FROM composer:2 AS vendor
WORKDIR /app
COPY composer.json composer.lock ./
RUN composer install \
    --no-dev \
    --no-interaction \
    --no-progress \
    --prefer-dist \
    --optimize-autoloader \
    --no-plugins \
    --no-scripts \
    --ignore-platform-req=ext-gd \
    --ignore-platform-req=ext-bcmath

FROM php:8.4.27-apache-bookworm
ARG VERSION=v1.0.0
LABEL org.opencontainers.image.title="azpanel" \
      org.opencontainers.image.description="azpanel web application" \
      org.opencontainers.image.source="https://github.com/wiuee/azpanel" \
      org.opencontainers.image.url="https://github.com/wiuee/azpanel" \
      org.opencontainers.image.version=$VERSION

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        libfreetype6-dev \
        libjpeg62-turbo-dev \
        libonig-dev \
        libpng-dev \
        libzip-dev \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j"$(nproc)" bcmath gd mbstring opcache pdo_mysql zip \
    && rm -rf /var/lib/apt/lists/* \
    && a2enmod rewrite headers \
    && mv "$PHP_INI_DIR/php.ini-production" "$PHP_INI_DIR/php.ini"

ENV APACHE_DOCUMENT_ROOT=/var/www/html/public \
    APP_DEBUG=false
RUN sed -ri -e 's!/var/www/html!${APACHE_DOCUMENT_ROOT}!g' /etc/apache2/sites-available/*.conf \
    && sed -ri -e 's!/var/www/!${APACHE_DOCUMENT_ROOT}!g' /etc/apache2/apache2.conf /etc/apache2/conf-available/*.conf

WORKDIR /var/www/html
COPY . .
COPY --from=vendor /app/vendor ./vendor
RUN php think service:discover \
    && php think vendor:publish \
    && mkdir -p runtime storage \
    && chown -R www-data:www-data runtime storage

EXPOSE 80
