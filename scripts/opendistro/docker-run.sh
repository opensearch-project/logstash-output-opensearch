#!/bin/bash

# This is intended to be run inside the docker container as the command of the docker compose.
set -ex

cd scripts/opendistro

docker compose up --exit-code-from logstash
