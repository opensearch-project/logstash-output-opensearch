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
      distribution = get_distribution(pool, url)
      if distribution == 'opensearch' || distribution == 'humio' || major_version == 7
        return true
      end
      log_not_supported(url, major_version, distribution)
      false
    end

    def get_distribution(pool, url)
      pool.get_distribution(url)
    end

    def log_not_supported(url, major_version, distribution)
      @logger.error("Could not connect to cluster", url: url.sanitized.to_s, distribution: distribution, major_version: major_version)
    end
  end
end; end; end