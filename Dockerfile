# This file was auto-generated, do not edit it directly.
# Instead run bin/update_build_scripts from
# https://github.com/das7pad/sharelatex-dev-env

FROM node:12.16.1 AS base

CMD ["node", "--expose-gc", "app.js"]

ENTRYPOINT ["/bin/sh", "entrypoint.sh"]

WORKDIR /app

COPY docker_cleanup.sh /

COPY install_deps.sh /app/
RUN /app/install_deps.sh

COPY package.json package-lock.json /app/

FROM base AS dev-deps

RUN /docker_cleanup.sh npm ci

FROM dev-deps as dev

COPY . /app

RUN /docker_cleanup.sh make build_app

RUN DATA_DIRS="cache compiles db" \
&&  mkdir -p ${DATA_DIRS} \
&&  chown node:node ${DATA_DIRS}

VOLUME /app/cache /app/compiles /app/db
