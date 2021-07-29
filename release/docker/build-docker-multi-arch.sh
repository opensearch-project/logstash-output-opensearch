#!/bin/bash

# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

# This is intended to be run the plugin's root directory. `release/docker`
# Ensure you have Docker Desktop installed as buildx only support Docker Desktop on macOS and Windows

set -e

# Variables
BUILDER_NUM=`date +%s`
BUILDER_NAME="multiarch_${BUILDER_NUM}"

# Imports and functions
function cleanup_docker_buildx() {
    # Cleanup docker buildx
    echo -e "\n* Cleanup docker buildx"
    docker buildx use default
    docker buildx rm $BUILDER_NAME > /dev/null 2>&1
}

# Building plugin
bash build-plugin.sh

# Identify Logstash version
version=${LOGSTASH_VERSION}
if [[ -z "$version" ]]; then
  version=7.13.2
fi

# Prepare docker buildx
trap cleanup_docker_buildx TERM INT EXIT
echo -e "\n* Prepare docker buildx"
docker buildx use default
docker buildx create --name $BUILDER_NAME --use
docker buildx inspect --bootstrap

# Check buildx status
echo -e "\n* Check buildx status"
docker buildx ls | grep $BUILDER_NAME
docker ps | grep $BUILDER_NAME

# Docker Build Images
docker buildx build --platform linux/amd64,linux/arm64 --build-arg VERSION=$version -t opensearchstaging/logstash-oss-with-opensearch-output-plugin:$version -f Dockerfile --push .

