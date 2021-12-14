#!/bin/bash
# Copyright OpenSearch Contributors
# SPDX-License-Identifier: Apache-2.0

# This is intended to be run the  root directory. `release/build.sh`
set -e

GIT_ROOT=`git rev-parse --show-toplevel`

cd $GIT_ROOT # We need to start from repository root

rm -rf builds
mkdir builds

echo 'Building gem'
gem build logstash-output-opensearch.gemspec

echo 'Move Gem Location'
mv -v logstash-output-opensearch*.gem $GIT_ROOT/builds/

echo 'List of gems to be published: '
ls -l $GIT_ROOT/builds
