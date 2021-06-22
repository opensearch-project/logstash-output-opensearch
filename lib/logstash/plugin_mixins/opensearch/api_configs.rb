# SPDX-License-Identifier: Apache-2.0
#
#  The OpenSearch Contributors require contributions made to
#  this file be licensed under the Apache-2.0 license or a
#  compatible open source license.
#
#  Modifications Copyright OpenSearch Contributors. See
#  GitHub history for details.

module LogStash; module PluginMixins; module OpenSearch
  module APIConfigs

    # This module defines common options that can be reused by alternate OpenSearch output plugins.

    DEFAULT_HOST = ::LogStash::Util::SafeURI.new("//127.0.0.1")

    CONFIG_PARAMS = {
        # Username to authenticate to a secure OpenSearch cluster
        :user => { :validate => :string },
        # Password to authenticate to a secure OpenSearch cluster
        :password => { :validate => :password },

        # The document ID for the index. Useful for overwriting existing entries in
        # OpenSearch with the same ID.
        :document_id => { :validate => :string },

        # HTTP Path at which the OpenSearch server lives. Use this if you must run OpenSearch behind a proxy that remaps
        # the root path for the OpenSearch HTTP API lives.
        # Note that if you use paths as components of URLs in the 'hosts' field you may
        # not also set this field. That will raise an error at startup
        :path => { :validate => :string },

        # HTTP Path to perform the _bulk requests to
        # this defaults to a concatenation of the path parameter and "_bulk"
        :bulk_path => { :validate => :string },

        # Pass a set of key value pairs as the URL query string. This query string is added
        # to every host listed in the 'hosts' configuration. If the 'hosts' list contains
        # urls that already have query strings, the one specified here will be appended.
        :parameters => { :validate => :hash },

        # Enable SSL/TLS secured communication to OpenSearch cluster. Leaving this unspecified will use whatever scheme
        # is specified in the URLs listed in 'hosts'. If no explicit protocol is specified plain HTTP will be used.
        # If SSL is explicitly disabled here the plugin will refuse to start if an HTTPS URL is given in 'hosts'
        :ssl => { :validate => :boolean },

        # Option to validate the server's certificate. Disabling this severely compromises security.
        # For more information on disabling certificate verification please read
        # https://www.cs.utexas.edu/~shmat/shmat_ccs12.pdf
        :ssl_certificate_verification => { :validate => :boolean, :default => true },

        # The .cer or .pem file to validate the server's certificate
        :cacert => { :validate => :path },

        # The JKS truststore to validate the server's certificate.
        # Use either `:truststore` or `:cacert`
        :truststore => { :validate => :path },

        # Set the truststore password
        :truststore_password => { :validate => :password },

        # The keystore used to present a certificate to the server.
        # It can be either .jks or .p12
        :keystore => { :validate => :path },

        # Set the keystore password
        :keystore_password => { :validate => :password },

        # This setting asks OpenSearch for the list of all cluster nodes and adds them to the hosts list.
        # Note: This will return ALL nodes with HTTP enabled (including master nodes!). If you use
        # this with master nodes, you probably want to disable HTTP on them by setting
        # `http.enabled` to false in their OpenSearch.yml. You can either use the `sniffing` option or
        # manually enter multiple OpenSearch hosts using the `hosts` parameter.
        :sniffing => { :validate => :boolean, :default => false },

        # How long to wait, in seconds, between sniffing attempts
        :sniffing_delay => { :validate => :number, :default => 5 },

        # HTTP Path to be used for the sniffing requests
        # the default value is computed by concatenating the path value and "_nodes/http"
        # if sniffing_path is set it will be used as an absolute path
        # do not use full URL here, only paths, e.g. "/sniff/_nodes/http"
        :sniffing_path => { :validate => :string },

        # Set the address of a forward HTTP proxy.
        # This used to accept hashes as arguments but now only accepts
        # arguments of the URI type to prevent leaking credentials.
        :proxy => { :validate => :uri }, # but empty string is allowed

        # Set the timeout, in seconds, for network operations and requests sent OpenSearch. If
        # a timeout occurs, the request will be retried.
        :timeout => { :validate => :number, :default => 60 },

        # Set the OpenSearch errors in the whitelist that you don't want to log.
        # A useful example is when you want to skip all 409 errors
        # which are `document_already_exists_exception`.
        :failure_type_logging_whitelist => { :validate => :array, :default => [] },

        # While the output tries to reuse connections efficiently we have a maximum.
        # This sets the maximum number of open connections the output will create.
        # Setting this too low may mean frequently closing / opening connections
        # which is bad.
        :pool_max => { :validate => :number, :default => 1000 },

        # While the output tries to reuse connections efficiently we have a maximum per endpoint.
        # This sets the maximum number of open connections per endpoint the output will create.
        # Setting this too low may mean frequently closing / opening connections
        # which is bad.
        :pool_max_per_route => { :validate => :number, :default => 100 },

        # HTTP Path where a HEAD request is sent when a backend is marked down
        # the request is sent in the background to see if it has come back again
        # before it is once again eligible to service requests.
        # If you have custom firewall rules you may need to change this
        :healthcheck_path => { :validate => :string },

        # How frequently, in seconds, to wait between resurrection attempts.
        # Resurrection is the process by which backend endpoints marked 'down' are checked
        # to see if they have come back to life
        :resurrect_delay => { :validate => :number, :default => 5 },

        # How long to wait before checking if the connection is stale before executing a request on a connection using keepalive.
        # You may want to set this lower, if you get connection errors regularly
        # Quoting the Apache commons docs (this client is based Apache Commmons):
        # 'Defines period of inactivity in milliseconds after which persistent connections must
        # be re-validated prior to being leased to the consumer. Non-positive value passed to
        # this method disables connection validation. This check helps detect connections that
        # have become stale (half-closed) while kept inactive in the pool.'
        # See https://hc.apache.org/httpcomponents-client-ga/httpclient/apidocs/org/apache/http/impl/conn/PoolingHttpClientConnectionManager.html#setValidateAfterInactivity(int)[these docs for more info]
        :validate_after_inactivity => { :validate => :number, :default => 10000 },

        # Enable gzip compression on requests.
        :http_compression => { :validate => :boolean, :default => false },

        # Custom Headers to send on each request to OpenSearch nodes
        :custom_headers => { :validate => :hash, :default => {} },

        # Sets the host(s) of the remote instance. If given an array it will load balance requests across the hosts specified in the `hosts` parameter.
        # Remember the `http` protocol uses the http address (eg. 9200, not 9300).
        #     `"127.0.0.1"`
        #     `["127.0.0.1:9200","127.0.0.2:9200"]`
        #     `["http://127.0.0.1"]`
        #     `["https://127.0.0.1:9200"]`
        #     `["https://127.0.0.1:9200/mypath"]` (If using a proxy on a subpath)
        # It is important to exclude dedicated master nodes from the `hosts` list
        # to prevent LS from sending bulk requests to the master nodes.  So this parameter should only reference either data or client nodes in OpenSearch.
        #
        # Any special characters present in the URLs here MUST be URL escaped! This means `#` should be put in as `%23` for instance.
        :hosts => { :validate => :uri, :default => [ DEFAULT_HOST ], :list => true },

        # Set initial interval in seconds between bulk retries. Doubled on each retry up to `retry_max_interval`
        :retry_initial_interval => { :validate => :number, :default => 2 },

        # Set max interval in seconds between bulk retries.
        :retry_max_interval => { :validate => :number, :default => 64 }
    }.freeze

    def self.included(base)
      CONFIG_PARAMS.each { |name, opts| base.config(name, opts) }
    end
  end
end; end; end
