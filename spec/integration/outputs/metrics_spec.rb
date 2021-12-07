# SPDX-License-Identifier: Apache-2.0
#
#  The OpenSearch Contributors require contributions made to
#  this file be licensed under the Apache-2.0 license or a
#  compatible open source license.
#
#  Modifications Copyright OpenSearch Contributors. See
#  GitHub history for details.

require_relative "../../../spec/opensearch_spec_helper"

describe "metrics", :integration => true do
  subject! do
    require "logstash/outputs/opensearch"
    settings = {
      "manage_template" => false,
      "hosts" => "#{get_host_port()}"
    }
    plugin = LogStash::Outputs::OpenSearch.new(settings)
  end

  let(:metric) { subject.metric }
  let(:bulk_request_metrics) { subject.instance_variable_get(:@bulk_request_metrics) }
  let(:document_level_metrics) { subject.instance_variable_get(:@document_level_metrics) }

  before :each do
    # Clean OpenSearch of data before we start.
    @client = get_client
    clean(@client)
    subject.register
  end

  context "after a succesful bulk insert" do
    let(:bulk) { [
      LogStash::Event.new("message" => "sample message here"),
      LogStash::Event.new("somemessage" => { "message" => "sample nested message here" }),
      LogStash::Event.new("somevalue" => 100),
      LogStash::Event.new("somevalue" => 10),
      LogStash::Event.new("somevalue" => 1),
      LogStash::Event.new("country" => "us"),
      LogStash::Event.new("country" => "at"),
      LogStash::Event.new("geoip" => { "location" => [ 0.0, 0.0 ] })
    ]}

    it "increases successful bulk request metric" do
      expect(bulk_request_metrics).to receive(:increment).with(:successes).once
      subject.multi_receive(bulk)
    end

    it "increases number of successful inserted documents" do
      expect(document_level_metrics).to receive(:increment).with(:successes, bulk.size).once
      subject.multi_receive(bulk)
    end
  end

  context "after a bulk insert that generates errors" do
    let(:bulk) { [
      LogStash::Event.new("message" => "sample message here"),
      LogStash::Event.new("message" => { "message" => "sample nested message here" }),
    ]}
    it "increases bulk request with error metric" do
      expect(bulk_request_metrics).to receive(:increment).with(:with_errors).once
      expect(bulk_request_metrics).to_not receive(:increment).with(:successes)
      subject.multi_receive(bulk)
    end

    it "increases number of successful and non retryable documents" do
      expect(document_level_metrics).to receive(:increment).with(:non_retryable_failures).once
      expect(document_level_metrics).to receive(:increment).with(:successes).once
      subject.multi_receive(bulk)
    end
  end
end
