#!/bin/sh

DOCKER_GROUP=$(stat -c '%g' /var/run/docker.sock)
groupadd --non-unique --gid ${DOCKER_GROUP} dockeronhost
usermod -aG dockeronhost node

# compat
chown node:node /app/cache
chown node:node /app/compiles
chown node:node /app/db

mkdir -p /app/test/acceptance/fixtures/tmp/
chown node:node /app/test/acceptance/fixtures/tmp/

./bin/install_texlive_gce.sh
exec runuser -u node -- "$@"
