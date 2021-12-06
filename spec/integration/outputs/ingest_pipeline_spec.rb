# SPDX-License-Identifier: Apache-2.0
#
#  The OpenSearch Contributors require contributions made to
#  this file be licensed under the Apache-2.0 license or a
#  compatible open source license.
#
#  Modifications Copyright OpenSearch Contributors. See
#  GitHub history for details.

require_relative "../../../spec/opensearch_spec_helper"

describe "Ingest pipeline execution behavior", :integration => true do
  subject! do
    require "logstash/outputs/opensearch"
    settings = {
      "hosts" => "#{get_host_port()}",
      "pipeline" => "apache-logs"
    }
    next LogStash::Outputs::OpenSearch.new(settings)
  end

  let(:http_client) { Manticore::Client.new }
  let(:ingest_url) { "http://#{get_host_port()}/_ingest/pipeline/apache-logs" }
  let(:apache_logs_pipeline) { '
  {
    "description" : "Pipeline to parse Apache logs",
    "processors" : [
      {
        "grok": {
          "field": "message",
          "patterns": ["%{COMBINEDAPACHELOG}"]
        }
      }
    ]
  }'
  }

  before :each do
    # Delete all templates first.
    # Clean OpenSearch of data before we start.
    @client = get_client
    @client.indices.delete_template(:name => "*")

    # This can fail if there are no indexes, ignore failure.
    @client.indices.delete(:index => "*") rescue nil

    # delete existing ingest pipeline
    http_client.delete(ingest_url).call

    # register pipeline
    http_client.put(ingest_url, :body => apache_logs_pipeline, :headers => {"content-type" => "application/json" }).call

    #TODO: Use esclient
    #@client.ingest.put_pipeline :id => 'apache_pipeline', :body => pipeline_defintion

    subject.register
    subject.multi_receive([LogStash::Event.new("message" => '183.60.215.50 - - [01/Jun/2015:18:00:00 +0000] "GET /scripts/netcat-webserver HTTP/1.1" 200 182 "-" "Mozilla/5.0 (compatible; EasouSpider; +http://www.easou.com/search/spider.html)"')])
    @client.indices.refresh

    #Wait or fail until everything's indexed.
    Stud::try(10.times) do
      r = @client.search(index: 'logstash-*')
      expect(r).to have_hits(1)
      sleep(0.1)
    end
  end

  it "indexes using the proper pipeline" do
    results = @client.search(:index => 'logstash-*', :q => "message:\"netcat\"")
    expect(results).to have_hits(1)
    expect(results["hits"]["hits"][0]["_source"]["response"]).to eq("200")
    expect(results["hits"]["hits"][0]["_source"]["bytes"]).to eq("182")
    expect(results["hits"]["hits"][0]["_source"]["verb"]).to eq("GET")
    expect(results["hits"]["hits"][0]["_source"]["request"]).to eq("/scripts/netcat-webserver")
    expect(results["hits"]["hits"][0]["_source"]["auth"]).to eq("-")
    expect(results["hits"]["hits"][0]["_source"]["ident"]).to eq("-")
    expect(results["hits"]["hits"][0]["_source"]["clientip"]).to eq("183.60.215.50")
    expect(results["hits"]["hits"][0]["_source"]["junkfieldaaaa"]).to eq(nil)
  end
end
