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

describe "target_bulk_bytes", :integration => true do
  let(:event_count) { 1000 }
  let(:events) { event_count.times.map { event }.to_a }
  let(:config) {
      {
        "hosts" => get_host_port,
        "index" => index
      }
  }
  let(:index) { 10.times.collect { rand(10).to_s }.join("") }
  let(:type) { "_doc" }

  subject { LogStash::Outputs::OpenSearch.new(config) }

  before do
    subject.register
    allow(subject.client).to receive(:bulk_send).with(any_args).and_call_original
    subject.multi_receive(events)
  end

  describe "batches that are too large for one" do
    let(:event) { LogStash::Event.new("message" => "a " * (((subject.client.target_bulk_bytes/2) / event_count)+1)) }

    it "should send in two batches" do
      expect(subject.client).to have_received(:bulk_send).twice do |payload|
        expect(payload.size).to be <= subject.client.target_bulk_bytes
      end
    end

    describe "batches that fit in one" do
      # Normally you'd want to generate a request that's just 1 byte below the limit, but it's
      # impossible to know how many bytes an event will serialize as with bulk proto overhead
      let(:event) { LogStash::Event.new("message" => "a") }

      it "should send in one batch" do
        expect(subject.client).to have_received(:bulk_send).once do |payload|
          expect(payload.size).to be <= subject.client.target_bulk_bytes
        end
      end
    end
  end
end

describe "indexing" do
  let(:event) { LogStash::Event.new("message" => "Hello World!", "type" => type) }
  let(:index) { 10.times.collect { rand(10).to_s }.join("") }
  let(:type) { "_doc" }
  let(:event_count) { 1 + rand(2) }
  let(:config) { "not implemented" }
  let(:events) { event_count.times.map { event }.to_a }
  subject { LogStash::Outputs::OpenSearch.new(config) }
  
  let(:es_url) { "http://#{get_host_port}" }
  let(:index_url) {"#{es_url}/#{index}"}
  let(:http_client_options) { {} }
  let(:http_client) do
    Manticore::Client.new(http_client_options)
  end

  before do
    subject.register
    subject.multi_receive([])
  end
  
  shared_examples "an indexer" do |secure|
    it "ships events" do
      subject.multi_receive(events)

      http_client.post("#{es_url}/_refresh").call

      response = http_client.get("#{index_url}/_count?q=*")
      result = LogStash::Json.load(response.body)
      cur_count = result["count"]
      expect(cur_count).to eq(event_count)

      response = http_client.get("#{index_url}/_search?q=*&size=1000")
      result = LogStash::Json.load(response.body)
      result["hits"]["hits"].each do |doc|
        expect(doc["_type"]).to eq(type)
        expect(doc["_index"]).to eq(index)
      end
    end
    
    it "sets the correct content-type header" do
      expected_manticore_opts = {:headers => {"content-type" => "application/json"}, :body => anything}
      if secure
        expected_manticore_opts = {
          :headers => {"content-type" => "application/json"},
          :body => anything, 
          :auth => {
            :user => user,
            :password => password,
            :eager => true
          }}
      end
      expect(subject.client.pool.adapter.client).to receive(:send).
        with(anything, anything, expected_manticore_opts).at_least(:once).
        and_call_original
      subject.multi_receive(events)
    end
  end

  describe "an indexer with custom index_type", :integration => true do
    let(:config) {
      {
        "hosts" => get_host_port,
        "index" => index
      }
    }
    it_behaves_like("an indexer")
  end

  describe "an indexer with no type value set (default to doc)", :integration => true do
    let(:type) { "_doc" }
    let(:config) {
      {
        "hosts" => get_host_port,
        "index" => index
      }
    }
    it_behaves_like("an indexer")
  end
  describe "a secured indexer", :secure_integration => true do
    let(:user) { "admin" }
    let(:password) { "admin" }
    let(:es_url) {"https://integration:9200"}
    let(:config) do
      {
        "hosts" => ["integration:9200"],
        "user" => user,
        "password" => password,
        "ssl" => true,
        "ssl_certificate_verification" => false,
        "index" => index
      }
    end
    let(:http_client_options) do
      {
        :auth => {
          :user => user,
          :password => password
        },
        :ssl => {
          :enabled => true,
          :verify => false
        }
      }
    end
    it_behaves_like("an indexer", true)
  end
end
