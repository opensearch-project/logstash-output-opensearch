# SPDX-License-Identifier: Apache-2.0
#
#  The OpenSearch Contributors require contributions made to
#  this file be licensed under the Apache-2.0 license or a
#  compatible open source license.
#
#  Modifications Copyright OpenSearch Contributors. See
#  GitHub history for details.

module LogStash; module PluginMixins; module OpenSearch
  class NoopDistributionChecker
    INSTANCE = self.new

    def is_supported?(pool, url, major_version)
      true
    end
  end
end; end; end