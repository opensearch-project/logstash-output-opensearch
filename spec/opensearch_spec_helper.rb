# SPDX-License-Identifier: Apache-2.0
#
#  The OpenSearch Contributors require contributions made to
#  this file be licensed under the Apache-2.0 license or a
#  compatible open source license.
#
#  Modifications Copyright OpenSearch Contributors. See
#  GitHub history for details.

require_relative './spec_helper'

require 'elasticsearch'

require 'json'
require 'cabin'

module OpenSearchHelper
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
    "_doc"
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
    :routing
  end

  def self.es_version
    RSpec.configuration.filter[:es_version] || ENV['ES_VERSION']
  end

  RSpec::Matchers.define :have_hits do |expected|
    match do |actual|
      expected == actual['hits']['total']['value']
    end
  end

  RSpec::Matchers.define :have_index_pattern do |expected|
    match do |actual|
      test_against = Array(actual['index_patterns'].nil? ? actual['template'] : actual['index_patterns'])
      test_against.include?(expected)
    end
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
    # TODO: use index template if version >= 7.8 & OpenSearch
    t[name]
  end

  def get_template_settings(template)
    template['template']
  end

  def get_template_mappings(template)
    template['mappings']
  end
end

RSpec.configure do |config|
  config.include OpenSearchHelper
end
