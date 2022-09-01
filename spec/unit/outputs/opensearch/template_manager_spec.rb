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
    [7, 1, 2].each do |major_version|
      [:disabled, :v1, :v8].each do |ecs_ver|
        [true, false].each do |legacy_template|
          context "when ECS is #{ecs_ver} with OpenSearch #{major_version}.x legacy_template:#{legacy_template}" do
            suffix = legacy_template ? "" : "_index"
            it 'resolves' do
              expect(described_class.default_template_path(major_version, ecs_ver, legacy_template)).to end_with("/templates/ecs-#{ecs_ver}/#{major_version}x#{suffix}.json")
            end
          end
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
