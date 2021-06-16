require_relative './spec_helper'

require 'elasticsearch'

require 'json'
require 'cabin'

module ESHelper
  def get_host_port
    if ENV["INTEGRATION"] == "true"
      "elasticsearch:9200"
    else
      "localhost:9200"
    end
  end

  def get_client
    Elasticsearch::Client.new(:hosts => [get_host_port])
  end

  def doc_type
    if ESHelper.es_version_satisfies?(">=7")
      "_doc"
    else
      "doc"
    end
  end

  def self.action_for_version(action)
    action_params = action[1]
    if ESHelper.es_version_satisfies?(">=8")
      action_params.delete(:_type)
    end
    action[1] = action_params
    action
  end

  def todays_date
    Time.now.strftime("%Y.%m.%d")
  end

  def field_properties_from_template(template_name, field)
    template = get_template(@es, template_name)
    mappings = get_template_mappings(template)
    mappings["properties"][field]["properties"]
  end

  def routing_field_name
    if ESHelper.es_version_satisfies?(">=6")
      :routing
    else
      :_routing
    end
  end

  def self.es_version
    RSpec.configuration.filter[:es_version] || ENV['ES_VERSION']
  end

  RSpec::Matchers.define :have_hits do |expected|
    match do |actual|
      if ESHelper.es_version_satisfies?(">=7")
        expected == actual['hits']['total']['value']
      else
        expected == actual['hits']['total']
      end
    end
  end

  RSpec::Matchers.define :have_index_pattern do |expected|
    match do |actual|
      test_against = Array(actual['index_patterns'].nil? ? actual['template'] : actual['index_patterns'])
      test_against.include?(expected)
    end
  end

  def self.es_version_satisfies?(*requirement)
    es_version = RSpec.configuration.filter[:es_version]
    if es_version.nil?
      puts "Info: ES_VERSION, ELASTIC_STACK_VERSION or 'es_version' tag wasn't set. Returning false to all `es_version_satisfies?` call."
      return false
    end
    es_release_version = Gem::Version.new(es_version).release
    Gem::Requirement.new(requirement).satisfied_by?(es_release_version)
  end

  def clean(client)
    client.indices.delete_template(:name => "*")
    client.indices.delete_index_template(:name => "logstash*") rescue nil
    # This can fail if there are no indexes, ignore failure.
    client.indices.delete(:index => "*") rescue nil
  end

  def set_cluster_settings(client, cluster_settings)
    client.cluster.put_settings(body: cluster_settings)
    get_cluster_settings(client)
  end

  def get_cluster_settings(client)
    client.cluster.get_settings
  end

  def put_alias(client, the_alias, index)
    body = {
        "aliases" => {
            index => {
                "is_write_index"=>  true
            }
        }
    }
    client.put_alias({name: the_alias, body: body})
  end

  def max_docs_policy(max_docs)
  {
    "policy" => {
      "phases"=> {
        "hot" => {
          "actions" => {
            "rollover" => {
              "max_docs" => max_docs
            }
          }
        }
      }
    }
  }
  end

  def max_age_policy(max_age)
  {
    "policy" => {
      "phases"=> {
        "hot" => {
          "actions" => {
            "rollover" => {
              "max_age" => max_age
            }
          }
        }
      }
    }
  }
  end

  def get_template(client, name)
    t = client.indices.get_template(name: name)
    t[name]
  end

  def get_template_settings(template)
    template['settings']
  end

  def get_template_mappings(template)
    if ESHelper.es_version_satisfies?(">=7")
      template['mappings']
    else
      template['mappings']["_default_"]
    end
  end
end

RSpec.configure do |config|
  config.include ESHelper
end
