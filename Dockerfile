FROM node:10.15.3 as app

WORKDIR /app

COPY package.json npm-shrinkwrap.json /app/

RUN npm install --quiet

COPY . /app

RUN make build_app


FROM node:10.15.3

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
