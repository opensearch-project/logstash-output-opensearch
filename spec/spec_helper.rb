# SPDX-License-Identifier: Apache-2.0
#
#  The OpenSearch Contributors require contributions made to
#  this file be licensed under the Apache-2.0 license or a
#  compatible open source license.
#
#  Modifications Copyright OpenSearch Contributors. See
#  GitHub history for details.

require "logstash/devutils/rspec/spec_helper"

require "logstash/outputs/opensearch"

module LogStash::Outputs::OpenSearch::SpecHelper
end

RSpec.configure do |config|
  config.include LogStash::Outputs::OpenSearch::SpecHelper
end