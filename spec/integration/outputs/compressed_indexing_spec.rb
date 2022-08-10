# SPDX-License-Identifier: Apache-2.0
#
#  The OpenSearch Contributors require contributions made to
#  this file be licensed under the Apache-2.0 license or a
#  compatible open source license.
#
#  Modifications Copyright OpenSearch Contributors. See
#  GitHub history for details.

require_relative "../../../spec/opensearch_spec_helper"
require "logstash/outputs/opensearch"
require "stringio"

RSpec::Matchers.define :a_valid_gzip_encoded_string do
  match { |data|
    expect { Zlib::GzipReader.new(StringIO.new(data)).read }.not_to raise_error
  }
end


describe "indexing with http_compression turned on", :integration => true do
  let(:event) { LogStash::Event.new("message" => "Hello World!", "type" => type) }
  let(:index) { 10.times.collect { rand(10).to_s }.join("") }
  let(:type) { "_doc" }
  let(:event_count) { 10000 + rand(500) }
  let(:events) { event_count.times.map { event }.to_a }
  let(:config) {
    {
      "hosts" => get_host_port,
      "index" => index,
      "http_compression" => true
    }
  }
  subject { LogStash::Outputs::OpenSearch.new(config) }

  let(:opensearch_url) { "http://#{get_host_port}" }
  let(:index_url) {"#{opensearch_url}/#{index}"}
  let(:http_client_options) { {} }
  let(:http_client) do
    Manticore::Client.new(http_client_options)
  end

  before do
    subject.register
    subject.multi_receive([])
  end

  shared_examples "an indexer" do
    it "ships events" do
      subject.multi_receive(events)

      http_client.post("#{opensearch_url}/_refresh").call

      response = http_client.get("#{index_url}/_count?q=*")
      result = LogStash::Json.load(response.body)
      cur_count = result["count"]
      expect(cur_count).to eq(event_count)

      response = http_client.get("#{index_url}/_search?q=*&size=1000")
      result = LogStash::Json.load(response.body)
      result["hits"]["hits"].each do |doc|
        # FIXME This checks for OpenSearch 1.x or OpenDistro which has version 7.10.x
        # need a cleaner way to check this.
        if OpenSearchHelper.check_version?("< 2") || OpenSearchHelper.check_version?("> 7")
          expect(doc["_type"]).to eq(type)
        else
          expect(doc).not_to include("_type")
        end
        expect(doc["_index"]).to eq(index)
      end
    end
  end

  it "sets the correct content-encoding header and body is compressed" do
    expect(subject.client.pool.adapter.client).to receive(:send).
      with(anything, anything, {:headers=>{"Content-Encoding"=>"gzip", "content-type"=>"application/json"}, :body => a_valid_gzip_encoded_string}).
      and_call_original
    subject.multi_receive(events)
  end

  it_behaves_like("an indexer")
end
