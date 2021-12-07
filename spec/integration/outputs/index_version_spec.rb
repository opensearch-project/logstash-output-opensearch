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

describe "Versioned indexing", :integration => true do
  require "logstash/outputs/opensearch"

  let(:client) { get_client }

  before :each do
    # Delete all templates first.
    # Clean OpenSearch of data before we start.
    client.indices.delete_template(:name => "*")
    # This can fail if there are no indexes, ignore failure.
    client.indices.delete(:index => "*") rescue nil
    client.indices.refresh
  end

  context "when index only" do
    subject { LogStash::Outputs::OpenSearch.new(settings) }

    before do
      subject.register
    end

    describe "unversioned output" do
      let(:settings) do
        {
          "manage_template" => true,
          "index" => "logstash-index",
          "template_overwrite" => true,
          "hosts" => get_host_port(),
          "action" => "index",
          "script_lang" => "groovy",
          "document_id" => "%{my_id}"
        }
      end

      it "should default to OpenSearch version" do
        subject.multi_receive([LogStash::Event.new("my_id" => "123", "message" => "foo")])
        r = client.get(:index => 'logstash-index', :type => doc_type, :id => "123", :refresh => true)
        expect(r["_version"]).to eq(1)
        expect(r["_source"]["message"]).to eq('foo')
        subject.multi_receive([LogStash::Event.new("my_id" => "123", "message" => "foobar")])
        r2 = client.get(:index => 'logstash-index', :type => doc_type, :id => "123", :refresh => true)
        expect(r2["_version"]).to eq(2)
        expect(r2["_source"]["message"]).to eq('foobar')
      end
    end

    describe "versioned output" do
      let(:settings) do
        {
          "manage_template" => true,
          "index" => "logstash-index",
          "template_overwrite" => true,
          "hosts" => get_host_port(),
          "action" => "index",
          "script_lang" => "groovy",
          "document_id" => "%{my_id}",
          "version" => "%{my_version}",
          "version_type" => "external",
        }
      end

      it "should respect the external version" do
        id = "ev1"
        subject.multi_receive([LogStash::Event.new("my_id" => id, "my_version" => "99", "message" => "foo")])
        r = client.get(:index => 'logstash-index', :type => doc_type, :id => id, :refresh => true)
        expect(r["_version"]).to eq(99)
        expect(r["_source"]["message"]).to eq('foo')
      end

      it "should ignore non-monotonic external version updates" do
        id = "ev2"
        subject.multi_receive([LogStash::Event.new("my_id" => id, "my_version" => "99", "message" => "foo")])
        r = client.get(:index => 'logstash-index', :type => doc_type, :id => id, :refresh => true)
        expect(r["_version"]).to eq(99)
        expect(r["_source"]["message"]).to eq('foo')

        subject.multi_receive([LogStash::Event.new("my_id" => id, "my_version" => "98", "message" => "foo")])
        r2 = client.get(:index => 'logstash-index', :type => doc_type, :id => id, :refresh => true)
        expect(r2["_version"]).to eq(99)
        expect(r2["_source"]["message"]).to eq('foo')
      end

      it "should commit monotonic external version updates" do
        id = "ev3"
        subject.multi_receive([LogStash::Event.new("my_id" => id, "my_version" => "99", "message" => "foo")])
        r = client.get(:index => 'logstash-index', :type => doc_type, :id => id, :refresh => true)
        expect(r["_version"]).to eq(99)
        expect(r["_source"]["message"]).to eq('foo')

        subject.multi_receive([LogStash::Event.new("my_id" => id, "my_version" => "100", "message" => "foo")])
        r2 = client.get(:index => 'logstash-index', :type => doc_type, :id => id, :refresh => true)
        expect(r2["_version"]).to eq(100)
        expect(r2["_source"]["message"]).to eq('foo')
      end
    end
  end
end

