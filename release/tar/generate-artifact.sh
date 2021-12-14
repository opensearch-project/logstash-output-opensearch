#!/bin/bash

# Copyright OpenSearch Contributors
# SPDX-License-Identifier: Apache-2.0

# This is intended to be run the plugin's root directory. `release/tar`
set -e

function usage() {
    echo ""
    echo "This script is used to generate the Logstash OSS tar artifact by installing logstash output opensearch plugin."
    echo "--------------------------------------------------------------------------"
    echo "Usage: $0 [args]"
    echo ""
    echo "Required arguments:"
    echo -e "-v VERSION           \tSpecify the Logstash OSS version number that you are installing latest output plugin, e.g. '7.14.2'."
    echo -e "-p PLATFORM          \tSpecify the platform type you are building against, e.g. 'linux, macos'."
    echo -e "-a ARCHITECTURE      \tSpecify the architecture type you are building against, e.g. 'x64, arm64'."
    echo -e "-t TARGET DIRECTORY  \tSpecify the location where you like to generate artifact."
    echo -e "-h                   \tPrint this message."
    echo ""
    echo "--------------------------------------------------------------------------"
}

while getopts ":hv:a:t:p:" arg; do
    case $arg in
        h)
            usage
            exit 1
            ;;
        v)
            VERSION=$OPTARG
            ;;
        p)
            PLATFORM=$OPTARG
            ;;
        a)
            ARCHITECTURE=$OPTARG
            ;;
        t)
            TARGET_DIRECTORY=$OPTARG
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
if [ -z "$VERSION" ] || [ -z "$PLATFORM" ] || [ -z "$ARCHITECTURE" ] || [ -z "$TARGET_DIRECTORY" ]; then
  echo "You must specify '-v VERSION', '-p PLATFORM', '-a ARCHITECTURE', '-t TARGET_DIRECTORY'"
  usage
  exit 1
fi
if [ "$ARCHITECTURE" != "x64" ] && [ "$ARCHITECTURE" != "arm64" ]; then
	echo "We only support 'x64' and 'arm64' as architecture name for -a parameter"
  exit 1
fi
if [ "$PLATFORM" != "macos" ] && [ "$PLATFORM" != "linux" ]; then
	echo "We only support 'macos' and 'linux' as platform name for -p parameter"
  exit 1
fi
if [ "$PLATFORM" == "macos" ] && [ "$ARCHITECTURE" == "arm64" ]; then
	echo "We don't support $ARCHITECTURE for $PLATFORM at this moment"
  exit 1
fi

# map user input to logstash oss for architecture

if [ "$ARCHITECTURE" == "x64" ]; then
  LOGSTASH_OSS_ARCHITECTURE="x86_64"
elif [ "$ARCHITECTURE" == "arm64" ]; then
  LOGSTASH_OSS_ARCHITECTURE="aarch64"
fi

# map user input to logstash oss for platform

if [ "$PLATFORM" == "macos" ]; then
  LOGSTASH_OSS_PLATFORM="darwin"
elif [ "$PLATFORM" == "linux" ]; then
  LOGSTASH_OSS_PLATFORM=$PLATFORM
fi

LOGSTASH_OSS_ARTIFACT_NAME=logstash-oss-$VERSION-$LOGSTASH_OSS_PLATFORM-$LOGSTASH_OSS_ARCHITECTURE.tar.gz
GENERATED_ARTIFACT_NAME=logstash-oss-with-opensearch-output-plugin-$VERSION-$PLATFORM-$ARCHITECTURE.tar.gz

echo 'downloading logstash oss'
wget https://artifacts.elastic.co/downloads/logstash/$LOGSTASH_OSS_ARTIFACT_NAME -P $TARGET_DIRECTORY/;
cd $TARGET_DIRECTORY;
tar xzf $LOGSTASH_OSS_ARTIFACT_NAME;

echo 'installing latest opensearch output plugin'
logstash-$VERSION/bin/logstash-plugin install logstash-output-opensearch;

echo 'bundling logstash oss with latest opensearch output plugin'
tar -czf  $GENERATED_ARTIFACT_NAME logstash-$VERSION;

echo 'Artifact path:'$TARGET_DIRECTORY/$GENERATED_ARTIFACT_NAME;

