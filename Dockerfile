FROM node:10.15.3 as app

WORKDIR /app

#wildcard as some files may not be in all repos
COPY package*.json npm-shrink*.json /app/

RUN npm install --quiet

COPY . /app


RUN npm run compile:all

FROM node:10.15.3

WORKDIR /app

CMD ["node", "--expose-gc", "app.js"]
ENTRYPOINT ["/bin/sh", "entrypoint.sh"]

COPY install_deps.sh /app
RUN sh /app/install_deps.sh

COPY --from=app /app /app

