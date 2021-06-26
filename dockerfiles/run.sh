#!/bin/bash

# SPDX-License-Identifier: Apache-2.0
#
# The OpenSearch Contributors require contributions made to
# this file be licensed under the Apache-2.0 license or a
# compatible open source license.
#
# Modifications Copyright OpenSearch Contributors. See
# GitHub history for details.

# This is intended to be run the plugin's root directory. `dockerfiles/run.sh`
# Ensure you have Docker and docker-compose installed locally
set -e

# Building plugin
./dockerfiles/build.sh

# Identify Logstash version
version=${LOGSTASH_VERSION}
if [[ -z "$version" ]]; then
  version=7.13.2
fi
echo "VERSION=$version" > dockerfiles/.env

# Identify Architecture
arch=`uname -m`
suffix=''
if [ $arch == 'arm64' ]; then
  suffix='-arm64'
elif [ $arch == 'x86_64' ]; then
  arch='amd64'
  suffix='-x64'
else
  echo "Unknown Architecture. Only amd64 and arm64 is supported"
  exit 1
fi
echo "ARCH=$arch" >> dockerfiles/.env
echo "SUFFIX=$suffix" >> dockerfiles/.env

echo 'shutdown existing docker cluster'
docker-compose  --file dockerfiles/docker-compose.yml down

echo 'remove previous image to avoid conflict'
docker image rmi -f "logstash-oss-with-opensearch-output-plugin:$version$suffix"

echo 'build new docker image with latest changes'
docker-compose  --file dockerfiles/docker-compose.yml build

#echo 'start docker cluster'
#docker-compose --file dockerfiles/docker-compose.yml up

# steps to publish image to registry
# docker push ${DOCKER_NAMESPACE}/"logstash-oss-with-opensearch-output-plugin:$version$suffix"
