# This file was auto-generated, do not edit it directly.
# Instead run bin/update_build_scripts from
# https://github.com/das7pad/sharelatex-dev-env

FROM node:10.16.3 as app

WORKDIR /app

COPY package.json npm-shrinkwrap.json /app/

RUN npm install --quiet

COPY . /app

RUN make build_app


FROM node:10.16.3

CMD ["node", "--expose-gc", "app.js"]

WORKDIR /app

ENTRYPOINT ["/bin/sh", "entrypoint.sh"]

COPY install_deps.sh /app
RUN /app/install_deps.sh

COPY --from=app /app /app


ARG RELEASE
ARG COMMIT
ENV RELEASE=${RELEASE} \
    SENTRY_RELEASE=${RELEASE} \
    COMMIT=${COMMIT}
