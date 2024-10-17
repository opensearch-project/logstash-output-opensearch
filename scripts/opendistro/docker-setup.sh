#!/bin/bash

# This is intended to be run the plugin's root directory. `.scripts/opendistro/docker-setup.sh`
# Ensure you have Docker installed locally and set the OPENDISTRO_VERSION environment variable.
set -e

if [ -f Gemfile.lock ]; then
    rm Gemfile.lock
fi
cd scripts/opendistro;

docker compose down
docker compose build
