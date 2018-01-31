#!/bin/bash

if [ ! $(which docker-compose) ]; then
    echo "docker compose not found (or command 'docker-compose' not found)"
    echo "install it and make sure it's in your PATH"
    exit 1
fi

echo "--> creating custom network"
docker network create kongexample

docker-compose pull

docker-compose up -d db

echo "--> waiting for postgres to go up (5 seconds)"
sleep 5

echo "--> setting up database"
docker run --rm \
    --link kong-database:kong-database \
    -e "KONG_DATABASE=postgres" \
    -e "KONG_PG_HOST=kong-database" \
    --network kongexample \
    kong:0.12-alpine kong migrations up

docker-compose up gateway

echo "--> cleaning up"
docker-compose kill
docker-compose rm -f

docker network rm kongexample

echo "--> done"
