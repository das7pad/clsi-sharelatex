# This file was auto-generated, do not edit it directly.
# Instead run bin/update_build_scripts from
# https://github.com/das7pad/sharelatex-dev-env

FROM node:12.13.1 AS base

CMD ["node", "--expose-gc", "app.js"]

ENTRYPOINT ["/bin/sh", "entrypoint.sh"]

WORKDIR /app

COPY docker_cleanup.sh /

COPY install_deps.sh /app/
RUN /app/install_deps.sh

COPY package.json package-lock.json /app/

FROM base AS dev

RUN /docker_cleanup.sh npm ci

COPY . /app

RUN /docker_cleanup.sh make build_app
