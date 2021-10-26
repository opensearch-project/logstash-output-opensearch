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

CURR_DIR=`dirname $(realpath $0)`; cd $CURR_DIR
GIT_ROOT=`git rev-parse --show-toplevel`

echo 'Clear previous gem'
echo -n "Remove "; rm -rfv logstash-output-opensearch*.gem

cd $GIT_ROOT # We need to build the gem in root of this repo so .gemspec file contained locations are resolving correctly

echo 'Building plugin gem'
gem build logstash-output-opensearch.gemspec

echo 'Move Gem Location'
mv -v logstash-output-opensearch*.gem $CURR_DIR
