# syntax=docker/dockerfile:1

FROM ghcr.io/linuxserver/baseimage-alpine:3.23

ARG BUILD_DATE
ARG VERSION
ARG MANYFOLD_VERSION
LABEL build_version="Linuxserver.io version:- ${VERSION} Build-date:- ${BUILD_DATE}"
LABEL maintainer="thespad"

ENV RAILS_ENV="production" \
    NODE_ENV="production" \
    RACK_ENV="production" \
    DOCKER_TAG=lscr.io/linuxserver/manyfold:${VERSION} \
    PORT=3214 \
    RAILS_SERVE_STATIC_FILES=true \
    APP_VERSION=${MANYFOLD_VERSION} \
    HOME=/config

RUN \
  apk add --no-cache \
    assimp-dev \
    file \
    gcompat \
    imagemagick \
    imagemagick-heic \
    imagemagick-jpeg \
    imagemagick-webp \
    jemalloc \
    libarchive \
    mariadb-connector-c \
    pciutils \
    postgresql16-client \
    ruby \
    ruby-bundler && \
  apk add --no-cache --virtual=build-dependencies \
    build-base \
    git \
    grep \
    libffi-dev \
    mariadb-dev \
    nodejs \
    npm \
    postgresql-dev \
    ruby-dev \
    yaml-dev && \
  echo "**** install manyfold F3D and VTK packages ****" && \
  curl -s -o \
    /tmp/f3d.apk -L \
    "https://github.com/manyfold3d/f3d-alpine/releases/download/v3.4.1-r2/f3d-3.4.1-r2.x86_64.apk" && \
  curl -s -o \
    /tmp/vtk.apk -L \
    "https://github.com/manyfold3d/f3d-alpine/releases/download/v3.4.1-r1/vtk-9.5.2-r0.x86_64.apk" && \
  apk add --no-cache --allow-untrusted /tmp/f3d.apk /tmp/vtk.apk && \
  rm /tmp/f3d.apk /tmp/vtk.apk && \
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
  npm install -g corepack && \
  corepack enable && \
  yarn install && \
  gem install foreman && \
  RUBY=$(apk list ruby | grep -oP '.*-\K(\d\.\d\.\d)') && \
  sed -i "s/\d.\d.\d/${RUBY}/" .ruby-version && \
  bundle config set --local deployment 'true' && \
  bundle config set --local without 'development test' && \
  bundle config force_ruby_platform true && \
  bundle install && \
  touch db/schema.rb && \
  DATABASE_URL="nulldb://user:pass@localhost/db" \
  SECRET_KEY_BASE="placeholder" \
  APP_VERSION=${MANYFOLD_VERSION} \
  bundle exec rake assets:precompile && \
  rm db/schema.rb && \
  printf "Linuxserver.io version: ${VERSION}\nBuild-date: ${BUILD_DATE}" > /build_version && \
  echo "**** cleanup ****" && \
  yarn cache clean && \
  apk del --purge \
    build-dependencies && \
  rm -rf \
    $HOME/.bundle/cache \
    $HOME/.cache \
    $HOME/.npm \
    $HOME/.yarn \
    /app/www/node_modules/ \
    /app/www/tmp/cache/ \
    /app/www/vendor/bundle/ruby/3.?.?/cache/* \
    /tmp/*

COPY root/ /

EXPOSE 3214
