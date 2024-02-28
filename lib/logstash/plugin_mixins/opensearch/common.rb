# SPDX-License-Identifier: Apache-2.0
#
#  The OpenSearch Contributors require contributions made to
#  this file be licensed under the Apache-2.0 license or a
#  compatible open source license.
#
#  Modifications Copyright OpenSearch Contributors. See
#  GitHub history for details.

require "logstash/outputs/opensearch/template_manager"

module LogStash; module PluginMixins; module OpenSearch
  module Common

    # This module defines common methods that can be reused by alternate opensearch output plugins.

    attr_reader :hosts

    # These codes apply to documents, not at the request level
    DOC_DLQ_CODES = [400, 404]
    DOC_SUCCESS_CODES = [200, 201]
    DOC_CONFLICT_CODE = 409

    # Perform some OpenSearch options validations and Build the HttpClient.
    # Note that this methods may sets the @user, @password, @hosts and @client ivars as a side effect.
    # @return [HttpClient] the new http client
    def build_client

      # the following 3 options validation & setup methods are called inside build_client
      # because they must be executed prior to building the client and logstash
      # monitoring and management rely on directly calling build_client
      setup_hosts

      params["metric"] = metric
      if @proxy.eql?('')
        @logger.warn "Supplied proxy setting (proxy => '') has no effect"
      end
      ::LogStash::Outputs::OpenSearch::HttpClientBuilder.build(@logger, @hosts, params)
    end

    def setup_hosts
      @hosts = Array(@hosts)
      if @hosts.empty?
        @logger.info("No 'host' set in opensearch output. Defaulting to localhost")
        @hosts.replace(["localhost"])
      end
    end

    def hosts_default?(hosts)
      # NOTE: would be nice if pipeline allowed us a clean way to detect a config default :
      hosts.is_a?(Array) && hosts.size == 1 && hosts.first.equal?(LogStash::PluginMixins::OpenSearch::APIConfigs::DEFAULT_HOST)
    end
    private :hosts_default?


    # Plugin initialization extension point (after a successful OpenSearch connection).
    def finish_register
    end
    protected :finish_register

    def last_version
      client.last_version
    end

    def maximum_seen_major_version
      client.maximum_seen_major_version
    end

    def successful_connection?
      !!maximum_seen_major_version
    end

    # launch a thread that waits for an initial successful connection to the OpenSearch cluster to call the given block
    # @param block [Proc] the block to execute upon initial successful connection
    # @return [Thread] the successful connection wait thread
    def after_successful_connection(&block)
      Thread.new do
        sleep_interval = @retry_initial_interval
        until successful_connection? || @stopping.true?
          @logger.debug("Waiting for connectivity to OpenSearch cluster, retrying in #{sleep_interval}s")
          sleep_interval = sleep_for_interval(sleep_interval)
        end
        block.call if successful_connection?
      end
    end
    private :after_successful_connection

    def discover_cluster_uuid
      return unless defined?(plugin_metadata)
      return if params && params['auth_type'] && params['auth_type']['service_name'] == "aoss" # AOSS doesn't support GET /
      cluster_info = client.get('/')
      plugin_metadata.set(:cluster_uuid, cluster_info['cluster_uuid'])
    rescue => e
      @logger.error("Unable to retrieve OpenSearch cluster uuid", message: e.message, exception: e.class, backtrace: e.backtrace)
    end

    def retrying_submit(actions)
      # Initially we submit the full list of actions
      submit_actions = actions

      sleep_interval = @retry_initial_interval

      while submit_actions && submit_actions.length > 0

        # We retry with whatever is didn't succeed
        begin
          submit_actions = submit(submit_actions)
          if submit_actions && submit_actions.size > 0
            @logger.info("Retrying individual bulk actions that failed or were rejected by the previous bulk request", count: submit_actions.size)
          end
        rescue => e
          @logger.error("Encountered an unexpected error submitting a bulk request, will retry",
                        message: e.message, exception: e.class, backtrace: e.backtrace)
        end

        # Everything was a success!
        break if !submit_actions || submit_actions.empty?

        # If we're retrying the action sleep for the recommended interval
        # Double the interval for the next time through to achieve exponential backoff
        sleep_interval = sleep_for_interval(sleep_interval)
      end
    end

    def sleep_for_interval(sleep_interval)
      stoppable_sleep(sleep_interval)
      next_sleep_interval(sleep_interval)
    end

    def stoppable_sleep(interval)
      Stud.stoppable_sleep(interval) { @stopping.true? }
    end

    def next_sleep_interval(current_interval)
      doubled = current_interval * 2
      doubled > @retry_max_interval ? @retry_max_interval : doubled
    end

    def handle_dlq_status(message, action, status, response)
      # To support bwc, we check if DLQ exists. otherwise we log and drop event (previous behavior)
      if @dlq_writer
        event, action = action.event, [action[0], action[1], action[2]]
        # TODO: Change this to send a map with { :status => status, :action => action } in the future
        @dlq_writer.write(event, "#{message} status: #{status}, action: #{action}, response: #{response}")
      else
        if dig_value(response, 'index', 'error', 'type') == 'invalid_index_name_exception'
          level = :error
        else
          level = :warn
        end
        @logger.send level, message, status: status, action: action, response: response
      end
    end

    private

    def submit(actions)
      bulk_response = safe_bulk(actions)

      # If the response is nil that means we were in a retry loop
      # and aborted since we're shutting down
      return if bulk_response.nil?

      # If it did return and there are no errors we're good as well
      if bulk_response["errors"]
        @bulk_request_metrics.increment(:with_errors)
      else
        @bulk_request_metrics.increment(:successes)
        @document_level_metrics.increment(:successes, actions.size)
        return
      end

      responses = bulk_response["items"]
      if responses.size != actions.size # can not map action -> response reliably
        # an ES bug (on 7.10.2, 7.11.1) where a _bulk request to index X documents would return Y (> X) items
        msg = "Sent #{actions.size} documents but OpenSearch returned #{responses.size} responses"
        @logger.warn(msg, actions: actions, responses: responses)
        fail("#{msg} (likely a bug with _bulk endpoint)")
      end

      actions_to_retry = []
      responses.each_with_index do |response,idx|
        action_type, action_props = response.first

        status = action_props["status"]
        error  = action_props["error"]
        action = actions[idx]
        action_params = action[1]

        # Retry logic: If it is success, we move on. If it is a failure, we have 3 paths:
        # - For 409, we log and drop. there is nothing we can do
        # - For a mapping error, we send to dead letter queue for a human to intervene at a later point.
        # - For everything else there's mastercard. Yep, and we retry indefinitely. This should fix #572 and other transient network issues
        if DOC_SUCCESS_CODES.include?(status)
          @document_level_metrics.increment(:successes)
          next
        elsif DOC_CONFLICT_CODE == status
          @document_level_metrics.increment(:non_retryable_failures)
          @logger.warn "Failed action", status: status, action: action, response: response if log_failure_type?(error)
          next
        elsif DOC_DLQ_CODES.include?(status)
          handle_dlq_status("Could not index event to OpenSearch.", action, status, response)
          @document_level_metrics.increment(:non_retryable_failures)
          next
        else
          # only log what the user whitelisted
          @document_level_metrics.increment(:retryable_failures)
          @logger.info "Retrying failed action", status: status, action: action, error: error if log_failure_type?(error)
          actions_to_retry << action
        end
      end

      actions_to_retry
    end

    def log_failure_type?(failure)
      !failure_type_logging_whitelist.include?(failure["type"])
    end

    # Rescue retryable errors during bulk submission
    # @param actions a [action, params, event.to_hash] tuple
    # @return response [Hash] which contains 'errors' and processed 'items' entries
    def safe_bulk(actions)
      sleep_interval = @retry_initial_interval
      begin
        @client.bulk(actions) # returns { 'errors': ..., 'items': ... }
      rescue ::LogStash::Outputs::OpenSearch::HttpClient::Pool::HostUnreachableError => e
        # If we can't even connect to the server let's just print out the URL (:hosts is actually a URL)
        # and let the user sort it out from there
        @logger.error(
          "Attempted to send a bulk request but OpenSearch appears to be unreachable or down",
          message: e.message, exception: e.class, will_retry_in_seconds: sleep_interval
        )
        @logger.debug? && @logger.debug("Failed actions for last bad bulk request", :actions => actions)

        # We retry until there are no errors! Errors should all go to the retry queue
        sleep_interval = sleep_for_interval(sleep_interval)
        @bulk_request_metrics.increment(:failures)
        retry unless @stopping.true?
      rescue ::LogStash::Outputs::OpenSearch::HttpClient::Pool::NoConnectionAvailableError => e
        @logger.error(
          "Attempted to send a bulk request but there are no living connections in the pool " +
          "(perhaps OpenSearch is unreachable or down?)",
          message: e.message, exception: e.class, will_retry_in_seconds: sleep_interval
        )

        sleep_interval = sleep_for_interval(sleep_interval)
        @bulk_request_metrics.increment(:failures)
        retry unless @stopping.true?
      rescue ::LogStash::Outputs::OpenSearch::HttpClient::Pool::BadResponseCodeError => e
        @bulk_request_metrics.increment(:failures)
        log_hash = {:code => e.response_code, :url => e.url.sanitized.to_s, :content_length => e.request_body.bytesize}
        log_hash[:body] = e.response_body if @logger.debug? # Generally this is too verbose
        message = "Encountered a retryable error (will retry with exponential backoff)"

        # We treat 429s as a special case because these really aren't errors, but
        # rather just OpenSearch telling us to back off a bit, which we do.
        # The other retryable code is 503, which are true errors
        # Even though we retry the user should be made aware of these
        if e.response_code == 429
          logger.debug(message, log_hash)
        else
          logger.error(message, log_hash)
        end

        sleep_interval = sleep_for_interval(sleep_interval)
        retry
      rescue => e # Stuff that should never happen - print out full connection issues
        @logger.error(
          "An unknown error occurred sending a bulk request to OpenSearch (will retry indefinitely)",
          message: e.message, exception: e.class, backtrace: e.backtrace
        )
        @logger.debug? && @logger.debug("Failed actions for last bad bulk request", :actions => actions)

        sleep_interval = sleep_for_interval(sleep_interval)
        @bulk_request_metrics.increment(:failures)
        retry unless @stopping.true?
      end
    end

    def dlq_enabled?
      # TODO there should be a better way to query if DLQ is enabled
      # See more in: https://github.com/elastic/logstash/issues/8064
      respond_to?(:execution_context) && execution_context.respond_to?(:dlq_writer) &&
        !execution_context.dlq_writer.inner_writer.is_a?(::LogStash::Util::DummyDeadLetterQueueWriter)
    end

    def dig_value(val, first_key, *rest_keys)
      fail(TypeError, "cannot dig value from #{val.class}") unless val.kind_of?(Hash)
      val = val[first_key]
      return val if rest_keys.empty? || val == nil
      dig_value(val, *rest_keys)
    end
  end
end; end; end
