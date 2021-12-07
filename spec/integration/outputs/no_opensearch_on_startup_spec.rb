# SPDX-License-Identifier: Apache-2.0
#
#  The OpenSearch Contributors require contributions made to
#  this file be licensed under the Apache-2.0 license or a
#  compatible open source license.
#
#  Modifications Copyright OpenSearch Contributors. See
#  GitHub history for details.

require "logstash/outputs/opensearch"
require_relative "../../../spec/opensearch_spec_helper"

describe "opensearch is down on startup", :integration => true do
  let(:event1) { LogStash::Event.new("somevalue" => 100, "@timestamp" => "2014-11-17T20:37:17.223Z", "@metadata" => {"retry_count" => 0}) }
  let(:event2) { LogStash::Event.new("message" => "a") }

  subject {
    LogStash::Outputs::OpenSearch.new({
                                           "manage_template" => true,
                                           "index" => "logstash-2014.11.17",
                                           "template_overwrite" => true,
                                           "hosts" => get_host_port(),
                                           "retry_max_interval" => 64,
                                           "retry_initial_interval" => 2
                                       })
  }

  before :each do
    # Delete all templates first.
    allow(Stud).to receive(:stoppable_sleep)

    # Clean OpenSearch of data before we start.
    @client = get_client
    @client.indices.delete_template(:name => "*")
    @client.indices.delete(:index => "*")
    @client.indices.refresh
  end

  after :each do
    subject.close
  end

  it 'should ingest events when OpenSearch recovers before documents are sent' do
    allow_any_instance_of(LogStash::Outputs::OpenSearch::HttpClient::Pool).to receive(:get_version).and_raise(::LogStash::Outputs::OpenSearch::HttpClient::Pool::HostUnreachableError.new(StandardError.new, "big fail"))
    subject.register
    allow_any_instance_of(LogStash::Outputs::OpenSearch::HttpClient::Pool).to receive(:get_version).and_return(OpenSearchHelper.version)
    subject.multi_receive([event1, event2])
    @client.indices.refresh
    r = @client.search(index: 'logstash-*')
    expect(r).to have_hits(2)
  end

  it 'should ingest events when OpenSearch recovers after documents are sent' do
    allow_any_instance_of(LogStash::Outputs::OpenSearch::HttpClient::Pool).to receive(:get_version).and_raise(::LogStash::Outputs::OpenSearch::HttpClient::Pool::HostUnreachableError.new(StandardError.new, "big fail"))
    subject.register
    Thread.new do
      sleep 4
      allow_any_instance_of(LogStash::Outputs::OpenSearch::HttpClient::Pool).to receive(:get_version).and_return(OpenSearchHelper.version)
    end
    subject.multi_receive([event1, event2])
    @client.indices.refresh
    r = @client.search(index: 'logstash-*')
    expect(r).to have_hits(2)
  end

end
