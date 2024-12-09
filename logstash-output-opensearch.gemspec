# SPDX-License-Identifier: Apache-2.0
#
# The OpenSearch Contributors require contributions made to
# this file be licensed under the Apache-2.0 license or a
# compatible open source license.
#
# Modifications Copyright OpenSearch Contributors. See
# GitHub history for details.

signing_key_path = "gem-private_key.pem"

Gem::Specification.new do |s|
  s.name            = 'logstash-output-opensearch'
  s.version         = '2.1.0'

  s.licenses        = ['Apache-2.0']
  s.summary         = "Stores logs in OpenSearch"
  s.description     = "This gem is a Logstash plugin required to be installed on top of the Logstash core pipeline using $LS_HOME/bin/logstash-plugin install gem. This gem is not a stand-alone program"
  s.authors         = ["Elastic", "OpenSearch Contributors"]
  s.email           = 'opensearch@amazon.com'
  s.homepage        = "https://opensearch.org/"
  s.require_paths = ["lib"]

  s.platform = RUBY_PLATFORM

  # Files
  s.files = Dir["lib/**/*","spec/**/*","*.gemspec","*.md","Gemfile","LICENSE","NOTICE", "vendor/jar-dependencies/**/*.jar", "vendor/jar-dependencies/**/*.rb", "VERSION", "docs/**/*"]

  # Tests
  s.test_files = s.files.grep(%r{^(test|spec|features)/})

  if $PROGRAM_NAME.end_with?("gem") && ARGV == ["build", __FILE__] && File.exist?(signing_key_path)
    s.signing_key = signing_key_path
    s.cert_chain  = ['certs/opensearch-rubygems.pem']
  end

  # Special flag to let us know this is actually a logstash plugin
  s.metadata = {
    "logstash_plugin" => "true",
    "logstash_group" => "output",
    "source_code_uri" => "https://github.com/opensearch-project/logstash-output-opensearch"
  }

  s.add_runtime_dependency "manticore", '>= 0.5.4', '< 1.0.0'
  s.add_runtime_dependency 'stud', ['>= 0.0.17', '~> 0.0']
  s.add_runtime_dependency "logstash-core-plugin-api", ">= 1.60", "<= 2.99"
  s.add_runtime_dependency 'logstash-mixin-ecs_compatibility_support', '~>1.0'
  s.add_runtime_dependency 'aws-sdk-core', '~> 3'
  s.add_runtime_dependency 'json', '>= 2.3.0', '~> 2'

  s.add_development_dependency 'logstash-codec-plain'
  s.add_development_dependency 'logstash-devutils'
  s.add_development_dependency 'flores'
  s.add_development_dependency 'cabin', ['~> 0.6']
  s.add_development_dependency 'opensearch-ruby', '~> 1'
end
