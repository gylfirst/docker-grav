FROM php:8.3-apache
LABEL maintainer="Matthieu Tourrette <contact@matthieu-t.fr> (@gylfirst)"

# Enable Apache Rewrite + Expires Module
RUN a2enmod rewrite expires && \
    sed -i 's/ServerTokens OS/ServerTokens ProductOnly/g' \
    /etc/apache2/conf-available/security.conf

# Install dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    unzip \
    libfreetype6-dev \
    libjpeg62-turbo-dev \
    libpng-dev \
    libyaml-dev \
    libzip4 \
    libzip-dev \
    zlib1g-dev \
    libicu-dev \
    g++ \
    git \
    cron \
    vim \
    wget \
    && docker-php-ext-install opcache \
    && docker-php-ext-configure intl \
    && docker-php-ext-install intl \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j$(nproc) gd \
    && docker-php-ext-install zip \
    && rm -rf /var/lib/apt/lists/*

# set recommended PHP.ini settings
# see https://secure.php.net/manual/en/opcache.installation.php
RUN { \
    echo 'opcache.memory_consumption=128'; \
    echo 'opcache.interned_strings_buffer=8'; \
    echo 'opcache.max_accelerated_files=4000'; \
    echo 'opcache.revalidate_freq=2'; \
    echo 'opcache.fast_shutdown=1'; \
    echo 'opcache.enable_cli=1'; \
    echo 'upload_max_filesize=128M'; \
    echo 'post_max_size=128M'; \
    echo 'expose_php=off'; \
    echo 'opcache.enable=1'; \
    echo 'opcache.jit_buffer_size=100M'; \
    echo 'opcache.jit=1235'; \
    } > /usr/local/etc/php/conf.d/php-recommended.ini

RUN pecl install apcu \
    && pecl install yaml-2.2.3 \
    && docker-php-ext-enable apcu yaml

# Set user to www-data
RUN chown www-data:www-data /var/www
USER www-data

# NOT NEEDED IF USING THIS GRAV SKELETON
# Define Grav specific version of Grav or use latest stable
# ARG GRAV_VERSION=latest

# Define Grav's skeleton specific version of Grav or use latest stable
ARG GRAV_SKELETON_VERSION=v1.7.6

# Install grav (change version if needed)
WORKDIR /var/www
RUN wget -O grav-admin.zip https://github.com/hibbitts-design/grav-skeleton-open-publishing-space/releases/download/${GRAV_SKELETON_VERSION}/grav-skeleton-open-publishing-space.zip && \
    unzip grav-admin.zip -d grav-admin && \
    mv -T /var/www/grav-admin /var/www/html && \
    rm grav-admin.zip

# NOT NEEDED IF USING THIS GRAV SKELETON
# Update to last version and install Grav Admin plugin
# RUN cd /var/www/html && bin/gpm selfupgrade -f -y && bin/gpm install admin -y

# Create cron job for Grav maintenance scripts
RUN (crontab -l; echo "* * * * * cd /var/www/html;/usr/local/bin/php bin/grav scheduler 1>> /dev/null 2>&1") | crontab -

# Return to root user
USER root

# Copy init scripts
# COPY docker_entrypoint.sh /entrypoint.sh

# Install custom loading
WORKDIR /usr/src/app
RUN wget -O loading.sh https://cloud.matthieu-t.fr/index.php/s/dl_load_script/download && \
    chmod +x loading.sh

# provide container inside image for data persistence
VOLUME ["/var/www/html"]

# ENTRYPOINT ["/entrypoint.sh"]
# CMD ["apache2-foreground"]
CMD ["sh", "-c", "/usr/src/app/loading.sh && cron && apache2-foreground"]
