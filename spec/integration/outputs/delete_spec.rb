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


describe "Versioned delete", :integration => true do
  require "logstash/outputs/opensearch"

  let(:es) { get_client }

  before :each do
    # Delete all templates first.
    # Clean ES of data before we start.
    es.indices.delete_template(:name => "*")
    # This can fail if there are no indexes, ignore failure.
    es.indices.delete(:index => "*") rescue nil
    es.indices.refresh
  end

  context "when delete only" do
    subject { LogStash::Outputs::OpenSearch.new(settings) }

    before do
      subject.register
    end

    let(:settings) do
      {
        "manage_template" => true,
        "index" => "logstash-delete",
        "template_overwrite" => true,
        "hosts" => get_host_port(),
        "document_id" => "%{my_id}",
        "version" => "%{my_version}",
        "version_type" => "external",
        "action" => "%{my_action}"
      }
    end

    it "should ignore non-monotonic external version updates" do
      id = "ev2"
      subject.multi_receive([LogStash::Event.new("my_id" => id, "my_action" => "index", "message" => "foo", "my_version" => 99)])
      r = es.get(:index => 'logstash-delete', :type => doc_type, :id => id, :refresh => true)
      expect(r['_version']).to eq(99)
      expect(r['_source']['message']).to eq('foo')

      subject.multi_receive([LogStash::Event.new("my_id" => id, "my_action" => "delete", "message" => "foo", "my_version" => 98)])
      r2 = es.get(:index => 'logstash-delete', :type => doc_type, :id => id, :refresh => true)
      expect(r2['_version']).to eq(99)
      expect(r2['_source']['message']).to eq('foo')
    end

    it "should commit monotonic external version updates" do
      id = "ev3"
      subject.multi_receive([LogStash::Event.new("my_id" => id, "my_action" => "index", "message" => "foo", "my_version" => 99)])
      r = es.get(:index => 'logstash-delete', :type => doc_type, :id => id, :refresh => true)
      expect(r['_version']).to eq(99)
      expect(r['_source']['message']).to eq('foo')

      subject.multi_receive([LogStash::Event.new("my_id" => id, "my_action" => "delete", "message" => "foo", "my_version" => 100)])
      expect { es.get(:index => 'logstash-delete', :type => doc_type, :id => id, :refresh => true) }.to raise_error(OpenSearch::Transport::Transport::Errors::NotFound)
    end
  end
end
