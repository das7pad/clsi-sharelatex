# This file was auto-generated, do not edit it directly.
# Instead run bin/update_build_scripts from
# https://github.com/das7pad/sharelatex-dev-env

FROM node:10.16.3

CMD ["node", "--expose-gc", "app.js"]

ENTRYPOINT ["/bin/sh", "entrypoint.sh"]

WORKDIR /app

COPY docker_cleanup.sh /

COPY install_deps.sh /app/
RUN /app/install_deps.sh

COPY package.json package-lock.json /app/

RUN /docker_cleanup.sh npm ci

COPY . /app

RUN /docker_cleanup.sh make build_app

ARG RELEASE
ARG COMMIT
ENV \
    SERVICE_NAME="clsi" \
    RELEASE=${RELEASE} \
    SENTRY_RELEASE=${RELEASE} \
    COMMIT=${COMMIT}
