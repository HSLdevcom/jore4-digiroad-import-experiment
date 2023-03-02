#!/bin/bash

set -euo pipefail

# download latest version of the docker-compose package
curl https://raw.githubusercontent.com/HSLdevcom/jore4-tools/main/docker/download-docker-bundle.sh | bash

# start up test database and hasura for migrations
docker-compose -f ./docker/docker-compose.yml -f ./docker/docker-compose.custom.yml up jore4-testdb jore4-hasura
