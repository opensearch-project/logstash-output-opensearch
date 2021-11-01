# SPDX-License-Identifier: Apache-2.0
#
# The OpenSearch Contributors require contributions made to
# this file be licensed under the Apache-2.0 license or a
# compatible open source license.
#
# Modifications Copyright OpenSearch Contributors. See
# GitHub history for details.


# Build arguments:
#   VERSION: Required. Specify the label for image.

ARG VERSION
FROM docker.elastic.co/logstash/logstash-oss:${VERSION}
RUN localedef -v -c -i en_US -f UTF-8 en_US.UTF-8 || echo set locale
USER logstash
COPY --chown=logstash:logstash ./logstash-opensearch-sample.conf /usr/share/logstash/config/
RUN /usr/share/logstash/bin/logstash-plugin install logstash-output-opensearch
