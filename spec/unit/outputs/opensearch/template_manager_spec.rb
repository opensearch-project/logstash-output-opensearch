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
    [1, 2].each do |major_version|
      context "when ECS is disabled with OpenSearch #{major_version}.x" do
        it 'resolves' do
          expect(described_class.default_template_path(major_version)).to end_with("/templates/ecs-disabled/#{major_version}x.json")
        end
        it 'resolves' do
          expect(described_class.default_template_path(major_version, :disabled)).to end_with("/templates/ecs-disabled/#{major_version}x.json")
        end
      end
    end
    [7, 1, 2].each do |major_version|
      context "when ECS v1 is requested with OpenSearch #{major_version}.x" do
        it 'resolves' do
          expect(described_class.default_template_path(major_version, :v1)).to end_with("/templates/ecs-v1/#{major_version}x.json")
        end
      end
    end
    [1, 2].each do |major_version|
      context "when ECS v8 is requested with OpenSearch #{major_version}.x" do
        it 'resolves' do
          expect(described_class.default_template_path(major_version, :v8)).to end_with("/templates/ecs-v8/#{major_version}x.json")
        end
      end
    end
  end

  describe "index template settings" do
    let(:plugin_settings) { {"manage_template" => true, "template_overwrite" => true} }
    let(:plugin) { LogStash::Outputs::OpenSearch.new(plugin_settings) }

    describe "use template api" do
      let(:file_path) { described_class.default_template_path(7) }
      let(:template) { described_class.read_template_file(file_path)}

      it "should update settings" do
        expect(template.include?('template')).to be_falsey
      end
    end
  end
end
