# SPDX-License-Identifier: Apache-2.0
#
#  The OpenSearch Contributors require contributions made to
#  this file be licensed under the Apache-2.0 license or a
#  compatible open source license.
#
#  Modifications Copyright OpenSearch Contributors. See
#  GitHub history for details.

# encoding: utf-8
require "logstash/namespace"
require "logstash/environment"
require "logstash/outputs/base"
require "logstash/json"
require "concurrent/atomic/atomic_boolean"
require "stud/interval"
require "socket" # for Socket.gethostname
require "thread" # for safe queueing
require "uri" # for escaping user input
require "forwardable"

# This plugin is the recommended method of storing logs in OpenSearch.
# If you plan on using the OpenSearch Dashboards web interface, you'll want to use this output.
#
# This output only speaks the HTTP protocol. HTTP is the preferred protocol for interacting with OpenSearch.
# We strongly encourage the use of HTTP over the node protocol for a number of reasons. HTTP is only marginally slower,
# yet far easier to administer and work with. When using the HTTP protocol one may upgrade OpenSearch versions without having
# to upgrade Logstash in lock-step.
#
# You can learn more about OpenSearch at <https://opensearch.org/>
#
# ==== Retry Policy
# This plugin uses the OpenSearch bulk API to optimize its imports into OpenSearch. These requests may experience
# either partial or total failures.
#
# The following errors are retried infinitely:
#
# - Network errors (inability to connect)
# - 429 (Too many requests) and
# - 503 (Service unavailable) errors
#
# NOTE: 409 exceptions are no longer retried. Please set a higher `retry_on_conflict` value if you experience 409 exceptions.
# It is more performant for OpenSearch to retry these exceptions than this plugin.
#
# ==== Batch Sizes ====
# This plugin attempts to send batches of events as a single request. However, if
# a request exceeds 20MB we will break it up until multiple batch requests. If a single document exceeds 20MB it will be sent as a single request.
#
# ==== DNS Caching
#
# This plugin uses the JVM to lookup DNS entries and is subject to the value of https://docs.oracle.com/javase/7/docs/technotes/guides/net/properties.html[networkaddress.cache.ttl],
# a global setting for the JVM.
#
# As an example, to set your DNS TTL to 1 second you would set
# the `LS_JAVA_OPTS` environment variable to `-Dnetworkaddress.cache.ttl=1`.
#
# Keep in mind that a connection with keepalive enabled will
# not reevaluate its DNS value while the keepalive is in effect.
#
# ==== HTTP Compression
#
# This plugin supports request and response compression. Response compression is enabled by default,
# the user doesn't have to set any configs in OpenSearch for it to send back compressed response.
#
# For requests compression, users have to enable `http_compression`
# setting in their Logstash config file.
#
class LogStash::Outputs::OpenSearch < LogStash::Outputs::Base
  declare_threadsafe!

  require "logstash/outputs/opensearch/http_client"
  require "logstash/outputs/opensearch/http_client_builder"
  require "logstash/plugin_mixins/opensearch/api_configs"
  require "logstash/plugin_mixins/opensearch/common"
  require 'logstash/plugin_mixins/ecs_compatibility_support'

  # Protocol agnostic methods
  include(LogStash::PluginMixins::OpenSearch::Common)

  # ecs_compatibility option, provided by Logstash core or the support adapter.
  include(LogStash::PluginMixins::ECSCompatibilitySupport)

  # Generic/API config options that any document indexer output needs
  include(LogStash::PluginMixins::OpenSearch::APIConfigs)

  config_name "opensearch"

  # The OpenSearch action to perform. Valid actions are:
  #
  # - index: indexes a document (an event from Logstash).
  # - delete: deletes a document by id (An id is required for this action)
  # - create: indexes a document, fails if a document by that id already exists in the index.
  # - update: updates a document by id. Update has a special case where you can upsert -- update a
  #   document if not already present. See the `upsert` option.
  # - A sprintf style string to change the action based on the content of the event. The value `%{[foo]}`
  #   would use the foo field for the action
  #
  # For more details on actions, check out the https://opensearch.org/docs/opensearch/rest-api/document-apis/bulk/[OpenSearch bulk API documentation]
  config :action, :validate => :string, :default => "index"

  # The index to write events to. This can be dynamic using the `%{foo}` syntax.
  # The default value will partition your indices by day so you can more easily
  # delete old data or only search specific date ranges.
  # Indexes may not contain uppercase characters.
  # For weekly indexes ISO 8601 format is recommended, eg. logstash-%{+xxxx.ww}.
  # LS uses Joda to format the index pattern from event timestamp.
  # Joda formats are defined http://www.joda.org/joda-time/apidocs/org/joda/time/format/DateTimeFormat.html[here].
  config :index, :validate => :string

  config :document_type,
    :validate => :string,
    :deprecated => "Document types are removed entirely. You should avoid this feature"

  # From Logstash 1.3 onwards, a template is applied to OpenSearch during
  # Logstash's startup if one with the name `template_name` does not already exist.
  # By default, the contents of this template is the default template for
  # `logstash-%{+YYYY.MM.dd}` which always matches indices based on the pattern
  # `logstash-*`.  Should you require support for other index names, or would like
  # to change the mappings in the template in general, a custom template can be
  # specified by setting `template` to the path of a template file.
  #
  # Setting `manage_template` to false disables this feature.  If you require more
  # control over template creation, (e.g. creating indices dynamically based on
  # field names) you should set `manage_template` to false and use the REST
  # API to apply your templates manually.
  config :manage_template, :validate => :boolean, :default => true

  # This configuration option defines how the template is named inside OpenSearch.
  # Note that if you have used the template management features and subsequently
  # change this, you will need to prune the old template manually, e.g.
  #
  # `curl -XDELETE <http://localhost:9200/_template/OldTemplateName?pretty>`
  #
  # where `OldTemplateName` is whatever the former setting was.
  config :template_name, :validate => :string

  # You can set the path to your own template here, if you so desire.
  # If not set, the included template will be used.
  config :template, :validate => :path

  # The template_overwrite option will always overwrite the indicated template
  # in OpenSearch with either the one indicated by template or the included one.
  # This option is set to false by default. If you always want to stay up to date
  # with the template provided by Logstash, this option could be very useful to you.
  # Likewise, if you have your own template file managed by puppet, for example, and
  # you wanted to be able to update it regularly, this option could help there as well.
  #
  # Please note that if you are using your own customized version of the Logstash
  # template (logstash), setting this to true will make Logstash to overwrite
  # the "logstash" template (i.e. removing all customized settings)
  config :template_overwrite, :validate => :boolean, :default => false

  # The legacy_template option will use the old /_template
      # path for creating index templates.
      # It will also construct the ilm configurations for the template in a manner
      # which is compatible with legacy templates
      mod.config :legacy_template, :validate => :boolean, :default => true
    
  # The version to use for indexing. Use sprintf syntax like `%{my_version}` to use a field value here.
  config :version, :validate => :string

  # The version_type to use for indexing.
  config :version_type, :validate => ["internal", 'external', "external_gt", "external_gte", "force"]

  # A routing override to be applied to all processed events.
  # This can be dynamic using the `%{foo}` syntax.
  config :routing, :validate => :string

  # For child documents, ID of the associated parent.
  # This can be dynamic using the `%{foo}` syntax.
  config :parent, :validate => :string, :default => nil

  # For child documents, name of the join field
  config :join_field, :validate => :string, :default => nil

  # Set upsert content for update mode.s
  # Create a new document with this parameter as json string if `document_id` doesn't exists
  config :upsert, :validate => :string, :default => ""

  # Enable `doc_as_upsert` for update mode.
  # Create a new document with source if `document_id` doesn't exist in OpenSearch
  config :doc_as_upsert, :validate => :boolean, :default => false

  # Set script name for scripted update mode
  config :script, :validate => :string, :default => ""

  # Define the type of script referenced by "script" variable
  #  inline : "script" contains inline script
  #  indexed : "script" contains the name of script directly indexed in opensearch
  #  file    : "script" contains the name of script stored in opensearch's config directory
  config :script_type, :validate => ["inline", 'indexed', "file"], :default => ["inline"]

  # Set the language of the used script. If not set, this defaults to painless
  config :script_lang, :validate => :string, :default => "painless"

  # Set variable name passed to script (scripted update)
  config :script_var_name, :validate => :string, :default => "event"

  # if enabled, script is in charge of creating non-existent document (scripted update)
  config :scripted_upsert, :validate => :boolean, :default => false

  # The number of times OpenSearch should internally retry an update/upserted document
  config :retry_on_conflict, :validate => :number, :default => 1

  # Set which ingest pipeline you wish to execute for an event. You can also use event dependent configuration
  # here like `pipeline => "%{INGEST_PIPELINE}"`
  config :pipeline, :validate => :string, :default => nil

  attr_reader :client
  attr_reader :default_index
  attr_reader :default_template_name

  def initialize(*params)
    super
    setup_ecs_compatibility_related_defaults
  end

  def register
    @after_successful_connection_done = Concurrent::AtomicBoolean.new(false)
    @stopping = Concurrent::AtomicBoolean.new(false)

    check_action_validity

    @logger.info("New OpenSearch output", :class => self.class.name, :hosts => @hosts.map(&:sanitized).map(&:to_s))

    @client = build_client

    @after_successful_connection_thread = after_successful_connection do
      begin
        finish_register
        true # thread.value
      rescue => e
        # we do not want to halt the thread with an exception as that has consequences for LS
        e # thread.value
      ensure
        @after_successful_connection_done.make_true
      end
    end

    # To support BWC, we check if DLQ exists in core (< 5.4). If it doesn't, we use nil to resort to previous behavior.
    @dlq_writer = dlq_enabled? ? execution_context.dlq_writer : nil

    @event_mapper = -> (e) { event_action_tuple(e) }
    @event_target = -> (e) { e.sprintf(@index) }

    @bulk_request_metrics = metric.namespace(:bulk_requests)
    @document_level_metrics = metric.namespace(:documents)
  end

  # @override post-register when OpenSearch connection established
  def finish_register
    discover_cluster_uuid
    install_template
    super
  end

  # @override to handle proxy => '' as if none was set
  def config_init(params)
    proxy = params['proxy']
    if proxy.is_a?(String)
      # environment variables references aren't yet resolved
      proxy = deep_replace(proxy)
      if proxy.empty?
        params.delete('proxy')
        @proxy = ''
      else
        params['proxy'] = proxy # do not do resolving again
      end
    end
    super(params)
  end

  # Receive an array of events and immediately attempt to index them (no buffering)
  def multi_receive(events)
    wait_for_successful_connection if @after_successful_connection_done
    retrying_submit map_events(events)
  end

  def map_events(events)
    events.map(&@event_mapper)
  end

  def wait_for_successful_connection
    after_successful_connection_done = @after_successful_connection_done
    return unless after_successful_connection_done
    stoppable_sleep 1 until after_successful_connection_done.true?

    status = @after_successful_connection_thread && @after_successful_connection_thread.value
    if status.is_a?(Exception) # check if thread 'halted' with an error
      # keep logging that something isn't right (from every #multi_receive)
      @logger.error "OpenSearch setup did not complete normally, please review previously logged errors",
                    message: status.message, exception: status.class
    else
      @after_successful_connection_done = nil # do not execute __method__ again if all went well
    end
  end
  private :wait_for_successful_connection

  def close
    @stopping.make_true if @stopping
    stop_after_successful_connection_thread
    @client.close if @client
  end

  private

  def stop_after_successful_connection_thread
    @after_successful_connection_thread.join unless @after_successful_connection_thread.nil?
  end

  # Convert the event into a 3-tuple of action, params and event hash
  def event_action_tuple(event)
    params = common_event_params(event)
    params[:_type] = get_event_type(event) if use_event_type?(nil)

    if @parent
      if @join_field
        join_value = event.get(@join_field)
        parent_value = event.sprintf(@parent)
        event.set(@join_field, { "name" => join_value, "parent" => parent_value })
        params[routing_field_name] = event.sprintf(@parent)
      else
        params[:parent] = event.sprintf(@parent)
      end
    end

    action = event.sprintf(@action || 'index')

    if action == 'update'
      params[:_upsert] = LogStash::Json.load(event.sprintf(@upsert)) if @upsert != ""
      params[:_script] = event.sprintf(@script) if @script != ""
      params[retry_on_conflict_action_name] = @retry_on_conflict
    end

    params[:version] = event.sprintf(@version) if @version
    params[:version_type] = event.sprintf(@version_type) if @version_type

    EventActionTuple.new(action, params, event)
  end

  class EventActionTuple < Array # TODO: acting as an array for compatibility

    def initialize(action, params, event, event_data = nil)
      super(3)
      self[0] = action
      self[1] = params
      self[2] = event_data || event.to_hash
      @event = event
    end

    attr_reader :event

  end

  # @return Hash (initial) parameters for given event
  # @private shared event params factory between index and data_stream mode
  def common_event_params(event)
    params = {
        :_id => @document_id ? event.sprintf(@document_id) : nil,
        :_index => @event_target.call(event),
        routing_field_name => @routing ? event.sprintf(@routing) : nil
    }

    if @pipeline
      value = event.sprintf(@pipeline)
      # convention: empty string equates to not using a pipeline
      # this is useful when using a field reference in the pipeline setting, e.g.
      #      opensearch {
      #        pipeline => "%{[@metadata][pipeline]}"
      #      }
      params[:pipeline] = value unless value.empty?
    end

    params
  end

  @@plugins = Gem::Specification.find_all{|spec| spec.name =~ /logstash-output-opensearch-/ }

  @@plugins.each do |plugin|
    name = plugin.name.split('-')[-1]
    require "logstash/outputs/opensearch/#{name}"
  end

  def retry_on_conflict_action_name
    :retry_on_conflict
  end

  def routing_field_name
    :routing
  end

  DEFAULT_EVENT_TYPE_ES = "_doc".freeze

  def get_event_type(event)
    # Set the 'type' value for the index.
    type = if @document_type
             event.sprintf(@document_type)
           else
             DEFAULT_EVENT_TYPE_ES
           end

    type.to_s
  end

  ##
  # WARNING: This method is overridden in a subclass in Logstash Core 7.7-7.8's monitoring,
  #          where a `client` argument is both required and ignored. In later versions of
  #          Logstash Core it is optional and ignored, but to make it optional here would
  #          allow us to accidentally break compatibility with Logstashes where it was required.
  # @param noop_required_client [nil]: required `nil` for legacy reasons.
  # @return [Boolean]
  def use_event_type?(noop_required_client)
    # only if the user defined it
    @document_type
  end

  def install_template
    TemplateManager.install_template(self)
  rescue => e
    @logger.error("Failed to install template", message: e.message, exception: e.class, backtrace: e.backtrace)
  end

  def setup_ecs_compatibility_related_defaults
    case ecs_compatibility
    when :disabled
      @default_index = "logstash-%{+yyyy.MM.dd}"
      @default_template_name = 'logstash'
    when :v1
      @default_index = "ecs-logstash-%{+yyyy.MM.dd}"
      @default_template_name = 'ecs-logstash'
    else
      fail("unsupported ECS Compatibility `#{ecs_compatibility}`")
    end
    @index ||= default_index
    @template_name ||= default_template_name
  end

  # To be overidden by the -java version
  VALID_HTTP_ACTIONS = ["index", "delete", "create", "update"]
  def valid_actions
    VALID_HTTP_ACTIONS
  end

  def check_action_validity
    return if @action.nil? # not set
    raise LogStash::ConfigurationError, "No action specified!" if @action.empty?

    # If we're using string interpolation, we're good!
    return if @action =~ /%{.+}/
    return if valid_actions.include?(@action)

    raise LogStash::ConfigurationError, "Action '#{@action}' is invalid! Pick one of #{valid_actions} or use a sprintf style statement"
  end
end
