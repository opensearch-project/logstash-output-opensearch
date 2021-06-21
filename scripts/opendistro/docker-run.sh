#!/bin/bash

# This is intended to be run inside the docker container as the command of the docker-compose.
set -ex

cd scripts/opendistro

if [ "$INTEGRATION" == "true" ]; then
    docker-compose up --exit-code-from logstash
else
    docker-compose up --exit-code-from logstash logstash
fi
