require "logstash/devutils/rspec/spec_helper"
require "logstash/outputs/opensearch/template_manager"

describe LogStash::Outputs::ElasticSearch::TemplateManager do

  context 'when ECS v1 is requested' do
    it 'resolves' do
      expect(described_class.default_template_path(7, :v1)).to end_with("/templates/ecs-v1/elasticsearch-7x.json")
    end
  end
end
