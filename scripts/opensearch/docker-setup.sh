#!/bin/bash

# This is intended to be run the plugin's root directory. `scripts/opensearch/docker-setup.sh`
# Ensure you have Docker installed locally and set the OPENSEARCH_VERSION environment variable.
set -e

if [ -f Gemfile.lock ]; then
    rm Gemfile.lock
fi
cd scripts/opensearch;

docker compose down
docker compose build
