# SPDX-License-Identifier: Apache-2.0
#
#  The OpenSearch Contributors require contributions made to
#  this file be licensed under the Apache-2.0 license or a
#  compatible open source license.
#
#  Modifications Copyright OpenSearch Contributors. See
#  GitHub history for details.

require "logstash/devutils/rspec/spec_helper"
require "logstash/outputs/opensearch/template_manager"

describe LogStash::Outputs::OpenSearch::TemplateManager do

  describe ".default_template_path" do
    context 'when ECS v1 is requested' do
      it 'resolves' do
        expect(described_class.default_template_path(7, :v1)).to end_with("/templates/ecs-v1/elasticsearch-7x.json")
      end
    end
  end

  describe "index template" do
    let(:plugin_settings) { {"manage_template" => true, "template_overwrite" => true} }
    let(:plugin) { LogStash::Outputs::OpenSearch.new(plugin_settings) }

    describe "in version 8+" do
      let(:file_path) { described_class.default_template_path(7) }
      let(:template) { described_class.read_template_file(file_path)}

      it "should update settings" do
        expect(template.include?('template')).to be_falsey
      end
    end
  end
end