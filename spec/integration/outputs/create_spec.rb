# SPDX-License-Identifier: Apache-2.0
#
#  The OpenSearch Contributors require contributions made to
#  this file be licensed under the Apache-2.0 license or a
#  compatible open source license.
#
#  Modifications Copyright OpenSearch Contributors. See
#  GitHub history for details.

require_relative "../../../spec/opensearch_spec_helper"

describe "client create actions", :integration => true do
  require "logstash/outputs/opensearch"

  def get_output(action, id, version=nil, version_type=nil)
    settings = {
      "manage_template" => true,
      "index" => "logstash-create",
      "template_overwrite" => true,
      "hosts" => get_host_port(),
      "action" => action
    }
    settings['document_id'] = id
    settings['version'] = version if version
    settings['version_type'] = version_type if version_type
    LogStash::Outputs::OpenSearch.new(settings)
  end

  before :each do
    @client = get_client
    # Delete all templates first.
    # Clean OpenSearch of data before we start.
    @client.indices.delete_template(:name => "*")
    # This can fail if there are no indexes, ignore failure.
    @client.indices.delete(:index => "*") rescue nil
  end

  context "when action => create" do
    it "should create new documents with or without id" do
      subject = get_output("create", "id123")
      subject.register
      subject.multi_receive([LogStash::Event.new("message" => "sample message here")])
      @client.indices.refresh
      # Wait or fail until everything's indexed.
      Stud::try(3.times) do
        r = @client.search(index: 'logstash-*')
        expect(r).to have_hits(1)
      end
    end

    it "should allow default (internal) version" do
      subject = get_output("create", "id123", 43)
      subject.register
    end

    it "should allow internal version" do
      subject = get_output("create", "id123", 43, "internal")
      subject.register
    end

    it "should not allow external version" do
      subject = get_output("create", "id123", 43, "external")
      expect { subject.register }.to raise_error(LogStash::ConfigurationError)
    end

    it "should not allow external_gt version" do
      subject = get_output("create", "id123", 43, "external_gt")
      expect { subject.register }.to raise_error(LogStash::ConfigurationError)
    end

    it "should not allow external_gte version" do
      subject = get_output("create", "id123", 43, "external_gte")
      expect { subject.register }.to raise_error(LogStash::ConfigurationError)
    end
  end
end
