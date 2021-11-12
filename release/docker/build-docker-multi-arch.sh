#!/bin/bash

# Copyright OpenSearch Contributors
# SPDX-License-Identifier: Apache-2.0

# This is intended to be run the plugin's root directory. `release/docker`
# Ensure you have Docker Desktop installed as buildx only support Docker Desktop on macOS and Windows

set -e

ROOT=`dirname $(realpath $0)`
echo $ROOT
cd $ROOT

# Variables
BUILDER_NUM=`date +%s`
BUILDER_NAME="multiarch_${BUILDER_NUM}"


function usage() {
    echo ""
    echo "This script is used to build the Logstash Docker image by installing logstash output opensearch plugin."
    echo "--------------------------------------------------------------------------"
    echo "Usage: $0 [args]"
    echo ""
    echo "Required arguments:"
    echo -e "-v VERSION          \tSpecify the Logstash OSS version that you are building, e.g. '7.13.2'. This will be used to label the Docker image."
    echo -e "-t INSTALLATION TYPE\tSpecify the installation type t, e.g. local will build and install from github, while remote, will download latest ruby gems and install."
    echo -e "-r REPOSITORY        \tSpecify the Docker Hub Repository name, due to multi-arch image either save in cache or directly upload to Docker Hub Repo, no local copies. The tag name will be pointed to '-v' value and 'latest'"
    echo -e "-h                   \tPrint this message."
    echo ""
    echo "--------------------------------------------------------------------------"
}



# Imports and functions
function cleanup_docker_buildx() {
    # Cleanup docker buildx
    echo -e "\n* Cleanup docker buildx"
    docker buildx use default
    docker buildx rm $BUILDER_NAME > /dev/null 2>&1
}

while getopts ":hv:t:r:" arg; do
    case $arg in
        h)
            usage
            exit 1
            ;;
        v)
            VERSION=$OPTARG
            ;;
        t)
            INSTALL_TYPE=$OPTARG
            ;;
        r)
            REPOSITORY_NAME=$OPTARG
            ;;
        :)
            echo "-${OPTARG} requires an argument"
            usage
            exit 1
            ;;
        ?)
            echo "Invalid option: -${arg}"
            exit 1
            ;;
    esac
done

# Validate the required parameters to present
if [ -z "$VERSION" ] || [ -z "$INSTALL_TYPE" ]; then
  echo "You must specify '-v VERSION', '-t INSTALLATION TYPE'"
  usage
  exit 1
fi

# Validate value for installation type
if [ "$INSTALL_TYPE" != "local" ] && [ "$INSTALL_TYPE" != "remote" ]; then
    echo "Enter either 'local' or 'remote' as INSTALLATION TYPE for -t parameter"
    exit 1
fi

DOCKER_FOLDER_PATH=$INSTALL_TYPE

if [ "$INSTALL_TYPE" = "local" ]; then
    # Build plugin to generate gem
    bash "${DOCKER_FOLDER_PATH}/build-plugin.sh"
fi

DOCKER_FILE_PATH="${ROOT}/${DOCKER_FOLDER_PATH}/Dockerfile"

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
docker buildx build --platform linux/amd64,linux/arm64 --build-arg VERSION=$VERSION -t $REPOSITORY_NAME/logstash-oss-with-opensearch-output-plugin:$VERSION -t $REPOSITORY_NAME/logstash-oss-with-opensearch-output-plugin:latest -f $DOCKER_FILE_PATH --push .

