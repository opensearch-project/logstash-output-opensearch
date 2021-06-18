Gem::Specification.new do |s|
  s.name            = 'logstash-output-opensearch'
  s.version         = '1.0.0'

  s.licenses        = ['Apache License (2.0)']
  s.summary         = "Stores logs in OpenSearch"
  s.description     = "This gem is a Logstash plugin required to be installed on top of the Logstash core pipeline using $LS_HOME/bin/logstash-plugin install gem. This gem is not a stand-alone program"
  s.authors         = ["OpenSearch"]
  s.email           = 'opensearch@amazon.com'
  s.homepage        = "https://opensearch.org/"
  s.require_paths = ["lib"]

  s.platform = RUBY_PLATFORM

  # Files
  s.files = Dir["lib/**/*","spec/**/*","*.gemspec","*.md","Gemfile","LICENSE","NOTICE", "vendor/jar-dependencies/**/*.jar", "vendor/jar-dependencies/**/*.rb", "VERSION", "docs/**/*"]

  # Tests
  s.test_files = s.files.grep(%r{^(test|spec|features)/})

  # Special flag to let us know this is actually a logstash plugin
  s.metadata = { "logstash_plugin" => "true", "logstash_group" => "output" }

  s.add_runtime_dependency "manticore", '>= 0.5.4', '< 1.0.0'
  s.add_runtime_dependency 'stud', ['>= 0.0.17', '~> 0.0']
  s.add_runtime_dependency "logstash-core-plugin-api", ">= 1.60", "<= 2.99"
  s.add_runtime_dependency 'logstash-mixin-ecs_compatibility_support', '~>1.0'

  s.add_development_dependency 'logstash-codec-plain'
  s.add_development_dependency 'logstash-devutils'
  s.add_development_dependency 'flores'
  s.add_development_dependency 'cabin', ['~> 0.6']
end
