## Version 1.2.0 Release Notes

Compatible with OpenSearch 1.2.0

### Features

* Support AWS IAM authentication ([#68](https://github.com/opensearch-project/logstash-output-opensearch/pull/68))

### Enhancements

* Make default "target_bulk_bytes" below AWS limit, but make it configurable ([#71](https://github.com/opensearch-project/logstash-output-opensearch/pull/71))
* Add basic_auth authentication ([#75](https://github.com/opensearch-project/logstash-output-opensearch/pull/75))
* Add optional parameters required for authentication inside auth_type ([#84](https://github.com/opensearch-project/logstash-output-opensearch/pull/84))

### Infrastructure

* Add unit tests for AWS IAM authentication ([#77](https://github.com/opensearch-project/logstash-output-opensearch/pull/77))
* Add DCO check to workflow ([#87](https://github.com/opensearch-project/logstash-output-opensearch/pull/87))
* Update docker build script ([#88](https://github.com/opensearch-project/logstash-output-opensearch/pull/88))
* Parameterize docker hub repository name ([#90](https://github.com/opensearch-project/logstash-output-opensearch/pull/90))
* Update copyright license header ([#92](https://github.com/opensearch-project/logstash-output-opensearch/pull/92))
* Add support for code owners to repo ([#93](https://github.com/opensearch-project/logstash-output-opensearch/pull/93))
* Update version on main to 1.2.0 ([#97](https://github.com/opensearch-project/logstash-output-opensearch/pull/97))
* Run integration tests against the latest version ([#99](https://github.com/opensearch-project/logstash-output-opensearch/pull/99))

### Documentation

* Fix documentation bug in README ([#78](https://github.com/opensearch-project/logstash-output-opensearch/pull/78))
* Comment docs ([#81](https://github.com/opensearch-project/logstash-output-opensearch/pull/81))