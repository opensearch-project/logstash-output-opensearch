## Version 1.3.0 Release Notes

Compatible with OpenSearch 1.3.4, 2.1.0

### Features


### Enhancements

* Support for Logstash 8.x and ECS V8 compatibility [#152](https://github.com/opensearch-project/logstash-output-opensearch/pull/152)) 
 

### Bugfixes

* Use absolute path for template endpoint ('/_template' instead of '_template') ([#146](https://github.com/opensearch-project/logstash-output-opensearch/pull/146))
  * Template management fails when AWS IAM authentication is used ([issue #124](https://github.com/opensearch-project/logstash-output-opensearch/issues/124))
  * Cannot install index template ([issue #144](https://github.com/opensearch-project/logstash-output-opensearch/issues/144))
* Add Default template for OpenSearch 2.x. ([#150](https://github.com/opensearch-project/logstash-output-opensearch/pull/150))
  * Cannot install template for OpenSearch 2.x ([issue #145](https://github.com/opensearch-project/logstash-output-opensearch/issues/145)) 

### Infrastructure

* Update CI to use latest Logstash ([#152](https://github.com/opensearch-project/logstash-output-opensearch/pull/152))
* Update CI to run against OpenSearch 2.x ([#153](https://github.com/opensearch-project/logstash-output-opensearch/pull/153))

### Documentation
