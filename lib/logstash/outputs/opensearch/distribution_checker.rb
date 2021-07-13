# SPDX-License-Identifier: Apache-2.0
#
#  The OpenSearch Contributors require contributions made to
#  this file be licensed under the Apache-2.0 license or a
#  compatible open source license.
#
#  Modifications Copyright OpenSearch Contributors. See
#  GitHub history for details.
#
module LogStash; module Outputs; class OpenSearch
  class DistributionChecker

    def initialize(logger)
      @logger = logger
    end

    # Checks whether connecting cluster is one of supported distribution or not
    # @param pool
    # @param url [LogStash::Util::SafeURI] OpenSearch node URL
    # @param major_version OpenSearch major version number
    # @return [Boolean] true if supported
    def is_supported?(pool, url, major_version)
      case get_distribution(pool, url)
      when 'opensearch'
        return true
      when 'oss'
        if major_version == 7
          return true
        end
      end
      log_incompatible_version(url)
      false
    end

    def get_distribution(pool, url)
      pool.get_distribution(url)
    end

    def log_incompatible_version(url)
      @logger.error("Could not connect to cluster: incompatible version", url: url.sanitized.to_s)
    end
  end
end; end; end