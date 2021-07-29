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

echo 'Clear previous gem'
echo -n "Remove "; rm -rfv logstash-output-opensearch*.gem

echo 'Copy gemspec'
trap '{ echo -n "Remove "; rm -rfv logstash-output-opensearch.gemspec; }' INT TERM EXIT
cp -v ../../logstash-output-opensearch.gemspec .

echo 'Building plugin gem'
gem build logstash-output-opensearch.gemspec

