# SPDX-License-Identifier: Apache-2.0
#
# The OpenSearch Contributors require contributions made to
# this file be licensed under the Apache-2.0 license or a
# compatible open source license.
#
# Modifications Copyright OpenSearch Contributors. See
# GitHub history for details.


# Build arguments:
#   VERSION: Optional. Specify the label for image. Defaults to 7.13.2

ARG VERSION
FROM docker.elastic.co/logstash/logstash-oss:${VERSION}
USER logstash
COPY --chown=logstash:logstash ./logstash-output-opensearch-*.gem /tmp/logstash-output-opensearch.gem
COPY --chown=logstash:logstash ./logstash-opensearch-sample.conf /usr/share/logstash/config/
RUN /usr/share/logstash/bin/logstash-plugin install /tmp/logstash-output-opensearch.gem
