#!/bin/bash
# SPDX-License-Identifier: Apache-2.0
#
# The OpenSearch Contributors require contributions made to
# this file be licensed under the Apache-2.0 license or a
# compatible open source license.
#
# Modifications Copyright OpenSearch Contributors. See
# GitHub history for details.

# This is intended to be run the plugin's root directory. `dockerfiles/build.sh`
# Ensure you have Docker installed locally and set the VERSION and BUILD_DATE environment variable.
set -e

if [ -d dockerfiles/bin ]; then
  rm -rf dockerfiles/bin
fi

mkdir -p dockerfiles/bin

echo 'Building plugin'
gem build logstash-output-opensearch.gemspec

echo "Moving gem to bin directory"
mv logstash-output-opensearch*.gem dockerfiles/bin/
