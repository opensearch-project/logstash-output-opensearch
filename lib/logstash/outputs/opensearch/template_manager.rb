# SPDX-License-Identifier: Apache-2.0
#
#  The OpenSearch Contributors require contributions made to
#  this file be licensed under the Apache-2.0 license or a
#  compatible open source license.
#
#  Modifications Copyright OpenSearch Contributors. See
#  GitHub history for details.

module LogStash; module Outputs; class ElasticSearch
  class TemplateManager
    # To be mixed into the elasticsearch plugin base
    def self.install_template(plugin)
      return unless plugin.manage_template
      if plugin.template
        plugin.logger.info("Using mapping template from", :path => plugin.template)
        template = read_template_file(plugin.template)
      else
        plugin.logger.info("Using a default mapping template", :es_version => plugin.maximum_seen_major_version,
                                                               :ecs_compatibility => plugin.ecs_compatibility)
        template = load_default_template(plugin.maximum_seen_major_version, plugin.ecs_compatibility)
      end

      plugin.logger.debug("Attempting to install template", template: template)
      install(plugin.client, template_name(plugin), template, plugin.template_overwrite)
    end

    private
    def self.load_default_template(es_major_version, ecs_compatibility)
      template_path = default_template_path(es_major_version, ecs_compatibility)
      read_template_file(template_path)
    rescue => e
      fail "Failed to load default template for Elasticsearch v#{es_major_version} with ECS #{ecs_compatibility}; caused by: #{e.inspect}"
    end

    def self.install(client, template_name, template, template_overwrite)
      client.template_install(template_name, template, template_overwrite)
    end

    def self.template_settings(plugin, template)
      template['settings']
    end

    def self.template_name(plugin)
      plugin.template_name
    end

    def self.default_template_path(es_major_version, ecs_compatibility=:disabled)
      template_version = es_major_version
      default_template_name = "templates/ecs-#{ecs_compatibility}/elasticsearch-#{template_version}x.json"
      ::File.expand_path(default_template_name, ::File.dirname(__FILE__))
    end

    def self.read_template_file(template_path)
      raise ArgumentError, "Template file '#{template_path}' could not be found" unless ::File.exists?(template_path)
      template_data = ::IO.read(template_path)
      LogStash::Json.load(template_data)
    end
  end
end end end
