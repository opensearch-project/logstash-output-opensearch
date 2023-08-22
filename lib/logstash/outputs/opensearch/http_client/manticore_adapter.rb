# SPDX-License-Identifier: Apache-2.0
#
#  The OpenSearch Contributors require contributions made to
#  this file be licensed under the Apache-2.0 license or a
#  compatible open source license.
#
#  Modifications Copyright OpenSearch Contributors. See
#  GitHub history for details.

require 'aws-sdk-core'
require 'cgi'
require 'manticore'
require 'uri'

java_import 'org.apache.http.util.EntityUtils'
java_import 'org.apache.http.entity.StringEntity'

module LogStash; module Outputs; class OpenSearch; class HttpClient;
  AWS_DEFAULT_PORT = 443
  AWS_DEFAULT_PROFILE = 'default'
  AWS_DEFAULT_PROFILE_CREDENTIAL_RETRY = 0
  AWS_DEFAULT_PROFILE_CREDENTIAL_TIMEOUT = 1
  AWS_DEFAULT_REGION = 'us-east-1'
  AWS_IAM_AUTH_TYPE = "aws_iam"
  AWS_SERVICE = 'es'
  BASIC_AUTH_TYPE = 'basic'
  DEFAULT_HEADERS = { "content-type" => "application/json" }

  AWSIAMCredential = Struct.new(
    :access_key_id,
    :secret_access_key,
    :session_token,
    :profile,
    :instance_profile_credentials_retries,
    :instance_profile_credentials_timeout,
    :region)

  class ManticoreAdapter
    attr_reader :manticore, :logger

    def initialize(logger, options={})
      @logger = logger
      options = options.clone || {}
      options[:ssl] = options[:ssl] || {}

      # We manage our own retries directly, so let's disable them here
      options[:automatic_retries] = 0
      # We definitely don't need cookies
      options[:cookies] = false

      @client_params = {:headers => DEFAULT_HEADERS.merge(options[:headers] || {})}
      @type = get_auth_type(options) || nil

      if @type == AWS_IAM_AUTH_TYPE
        aws_iam_auth_initialization(options)
      elsif @type == BASIC_AUTH_TYPE
        basic_auth_initialization(options)
      end

      if options[:proxy]
        options[:proxy] = manticore_proxy_hash(options[:proxy])
      end

      @manticore = ::Manticore::Client.new(options)
    end

    def get_auth_type(options)
      if options[:auth_type] != nil
        options[:auth_type]["type"]
      end
    end

    def aws_iam_auth_initialization(options)
      aws_access_key_id =  options[:auth_type]["aws_access_key_id"] || nil
      aws_secret_access_key = options[:auth_type]["aws_secret_access_key"] || nil
      session_token = options[:auth_type]["session_token"] || nil
      profile = options[:auth_type]["profile"] || AWS_DEFAULT_PROFILE
      instance_cred_retries = options[:auth_type]["instance_profile_credentials_retries"] || AWS_DEFAULT_PROFILE_CREDENTIAL_RETRY
      instance_cred_timeout = options[:auth_type]["instance_profile_credentials_timeout"] || AWS_DEFAULT_PROFILE_CREDENTIAL_TIMEOUT
      region = options[:auth_type]["region"] || AWS_DEFAULT_REGION
      set_aws_region(region)
      set_service_name(options[:auth_type]["service_name"] || AWS_SERVICE)

      credential_config = AWSIAMCredential.new(aws_access_key_id, aws_secret_access_key, session_token, profile, instance_cred_retries, instance_cred_timeout, region)
      @credentials = Aws::CredentialProviderChain.new(credential_config).resolve
    end

    def basic_auth_initialization(options)
      set_user_password(options)
    end

    def set_aws_region(region)
      @region = region
    end

    def get_aws_region()
      @region
    end

    def set_service_name(service_name)
      @service_name = service_name
    end

    def get_service_name()
      @service_name
    end

    def set_user_password(options)
      @user = options[:auth_type]["user"]
      @password = options[:auth_type]["password"]
    end

    def get_user()
      @user
    end

    def get_password()
      @password
    end

    # Transform the proxy option to a hash. Manticore's support for non-hash
    # proxy options is broken. This was fixed in https://github.com/cheald/manticore/commit/34a00cee57a56148629ed0a47c329181e7319af5
    # but this is not yet released
    def manticore_proxy_hash(proxy_uri)
      [:scheme, :port, :user, :password, :path].reduce(:host => proxy_uri.host) do |acc,opt|
        value = proxy_uri.send(opt)
        acc[opt] = value unless value.nil? || (value.is_a?(String) && value.empty?)
        acc
      end
    end

    def client
      @manticore
    end

    # Performs the request by invoking {Transport::Base#perform_request} with a block.
    #
    # @return [Response]
    # @see    Transport::Base#perform_request
    #
    def perform_request(url, method, path, params={}, body=nil)
      # Perform 2-level deep merge on the params, so if the passed params and client params will both have hashes stored on a key they
      # will be merged as well, instead of choosing just one of the values
      params = (params || {}).merge(@client_params) { |key, oldval, newval|
        (oldval.is_a?(Hash) && newval.is_a?(Hash)) ? oldval.merge(newval) : newval
      }

      params[:headers] = params[:headers].clone
      params[:body] = body if body

      if url.user
        params[:auth] = {
          :user => CGI.unescape(url.user),
          # We have to unescape the password here since manticore won't do it
          # for us unless its part of the URL
          :password => CGI.unescape(url.password),
          :eager => true
        }
      elsif @type == BASIC_AUTH_TYPE
        add_basic_auth_to_params(params)
      end

      request_uri = format_url(url, path)

      if @type == AWS_IAM_AUTH_TYPE
        sign_aws_request(request_uri, path, method, params)
      end

      request_uri_as_string = remove_double_escaping(request_uri.to_s)
      resp = @manticore.send(method.downcase, request_uri_as_string, params)

      # Manticore returns lazy responses by default
      # We want to block for our usage, this will wait for the repsonse
      # to finish
      resp.call

      # 404s are excluded because they are valid codes in the case of
      # template installation. We might need a better story around this later
      # but for our current purposes this is correct
      if resp.code < 200 || resp.code > 299 && resp.code != 404
        raise ::LogStash::Outputs::OpenSearch::HttpClient::Pool::BadResponseCodeError.new(resp.code, request_uri, body, resp.body)
      end

      resp
    end

    # from Manticore, https://github.com/cheald/manticore/blob/acc25cac2999f4658a77a0f39f60ddbca8fe14a4/lib/manticore/client.rb#L536
    ISO_8859_1 = "ISO-8859-1".freeze

    def minimum_encoding_for(string)
      if string.ascii_only?
        ISO_8859_1
      else
        string.encoding.to_s
      end
    end

    def sign_aws_request(request_uri, path, method, params)
      url = URI::HTTPS.build({:host=>URI(request_uri.to_s).host, :port=>AWS_DEFAULT_PORT.to_s, :path=>path})

      request = Seahorse::Client::Http::Request.new(options={:endpoint=>url, :http_method => method.to_s.upcase,
        :headers => params[:headers],:body => params[:body]})

      aws_signer = Aws::Sigv4::Signer.new(service: @service_name, region: @region, credentials_provider: @credentials)
      signed_key = aws_signer.sign_request(
        http_method: request.http_method,
        url: url,
        headers: params[:headers],
        # match encoding of the HTTP adapter, see https://github.com/opensearch-project/logstash-output-opensearch/issues/207
        body: params[:body] ? EntityUtils.toString(StringEntity.new(params[:body], minimum_encoding_for(params[:body]))) : nil
      )
      params[:headers] = params[:headers].merge(signed_key.headers)
    end

    def add_basic_auth_to_params(params)
      params[:auth] = {
        :user => get_user(),
        :password => get_password(),
        :eager => true
      }
    end

    # Returned urls from this method should be checked for double escaping.
    def format_url(url, path_and_query=nil)
      request_uri = url.clone

      # We excise auth info from the URL in case manticore itself tries to stick
      # sensitive data in a thrown exception or log data
      request_uri.user = nil
      request_uri.password = nil

      return request_uri.to_s if path_and_query.nil?

      parsed_path_and_query = java.net.URI.new(path_and_query)

      query = request_uri.query
      parsed_query = parsed_path_and_query.query

      new_query_parts = [request_uri.query, parsed_path_and_query.query].select do |part|
        part && !part.empty? # Skip empty nil and ""
      end

      request_uri.query = new_query_parts.join("&") unless new_query_parts.empty?

      # use `raw_path`` as `path` will unescape any escaped '/' in the path
      request_uri.path = "#{request_uri.path}/#{parsed_path_and_query.raw_path}".gsub(/\/{2,}/, "/")
      request_uri
    end

    # Later versions of SafeURI will also escape the '%' sign in an already escaped URI.
    # (If the path variable is used, it constructs a new java.net.URI object using the multi-arg constructor,
    # which will escape any '%' characters in the path, as opposed to the single-arg constructor which requires illegal
    # characters to be already escaped, and will throw otherwise)
    # The URI needs to have been previously escaped, as it does not play nice with an escaped '/' in the
    # middle of a URI, as required by date math, treating it as a path separator
    def remove_double_escaping(url)
      url.gsub(/%25([0-9A-F]{2})/i, '%\1')
    end

    def close
      @manticore.close
    end

    def host_unreachable_exceptions
      [::Manticore::Timeout,::Manticore::SocketException, ::Manticore::ClientProtocolException, ::Manticore::ResolutionFailure, Manticore::SocketTimeout]
    end
  end
end; end; end; end
