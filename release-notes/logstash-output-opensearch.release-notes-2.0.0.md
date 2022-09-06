## Version 2.0.0 Release Notes

Compatible with OpenSearch 1.3.4, 2.1.0

### Features

* Configuration parameter `service_name` to specify the service name for Signature Version 4 (SigV4) signing. ([#168](https://github.com/opensearch-project/logstash-output-opensearch/pull/168))
* Configuration parameter `legacy_template` to support index templates. ([#169](https://github.com/opensearch-project/logstash-output-opensearch/pull/169))
* Configuration parameter `default_server_major_version` to use when the version number can't be fetched from the host's root URL. ([#170](https://github.com/opensearch-project/logstash-output-opensearch/pull/170))

### Enhancements

* AWS SDK dependency updated to 3.0 to work with Logstash 8.4.0 ([#171](https://github.com/opensearch-project/logstash-output-opensearch/pull/171))


