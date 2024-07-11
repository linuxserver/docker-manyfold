# syntax=docker/dockerfile:1

FROM ghcr.io/linuxserver/baseimage-alpine:3.20

ARG BUILD_DATE
ARG VERSION
ARG MANYFOLD_VERSION
LABEL build_version="Linuxserver.io version:- ${VERSION} Build-date:- ${BUILD_DATE}"
LABEL maintainer="thespad"

ENV RAILS_ENV="production" \
    NODE_ENV="production" \
    RACK_ENV="production" \
    PORT=3214 \
    RAILS_SERVE_STATIC_FILES=true \
    APP_VERSION=${MANYFOLD_VERSION}

RUN \
  apk add --no-cache \
    glfw \
    libarchive \
    libstdc++ \
    mesa-gl \
    pciutils \
    postgresql16-client \
    ruby \
    ruby-bundler && \
  apk add --no-cache --virtual=build-dependencies \
    build-base \
    git \
    libffi-dev \
    mariadb-dev \
    nodejs \
    postgresql-dev \
    ruby-dev \
    yarn && \
  echo "**** install manyfold ****" && \
  mkdir -p /app/www && \
  if [ -z ${MANYFOLD_VERSION+x} ]; then \
    MANYFOLD_VERSION=$(curl -sX GET "https://api.github.com/repos/manyfold3d/manyfold/releases/latest" \
    | awk '/tag_name/{print $4;exit}' FS='[""]'); \
  fi && \
  curl -sX GET "https://api.github.com/repos/manyfold3d/manyfold/git/matching-refs/tags/${MANYFOLD_VERSION}" \
    | jq -r '.[].object.sha' > /app/www/GIT_SHA && \
  curl -s -o \
    /tmp/manyfold.tar.gz -L \
    "https://github.com/manyfold3d/manyfold/archive/${MANYFOLD_VERSION}.tar.gz" && \
  tar xf \
    /tmp/manyfold.tar.gz -C \
    /app/www/ --strip-components=1 && \
  cd /app/www && \
  yarn install && \
  gem install foreman && \
  sed -i 's/3.3.1/3.3.3/' .ruby-version && \
  bundle config set --local deployment 'true' && \
  bundle config set --local without 'development test' && \
  bundle config force_ruby_platform true && \
  bundle install && \
  DATABASE_URL="nulldb://user:pass@localhost/db" \
  SECRET_KEY_BASE="placeholder" \
  bundle exec rake assets:precompile && \
  printf "Linuxserver.io version: ${VERSION}\nBuild-date: ${BUILD_DATE}" > /build_version && \
  echo "**** cleanup ****" && \
  yarn cache clean && \
  apk del --purge \
    build-dependencies && \
  rm -rf \
    $HOME/.bundle/cache \
    $HOME/.composer \
    /app/www/node_modules/ \
    /app/www/tmp/cache/ \
    /app/www/vendor/bundle/ruby/3.3.0/cache/* \
    /tmp/*

COPY root/ /

EXPOSE 3214