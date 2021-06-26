#!/bin/bash
set -ex

export PATH=$BUILD_DIR/gradle/bin:$PATH

bundle exec rspec -fd spec/unit -t ~integration
