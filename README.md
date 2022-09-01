[![Build and Test logstash-output-opensearch plugin](https://github.com/opensearch-project/logstash-output-opensearch/actions/workflows/CI.yml/badge.svg)](https://github.com/opensearch-project/logstash-output-opensearch/actions/workflows/CI.yml)
![PRs welcome!](https://img.shields.io/badge/PRs-welcome!-success)
# Logstash Output OpenSearch

- [Welcome!](#welcome)
- [Project Resources](#project-resources)
- [Configuration for Logstash Output Opensearch Plugin](#configuration-for-logstash-output-opensearch-plugin)
- [Code of Conduct](#code-of-conduct)
- [License](#license)
- [Copyright](#copyright)

## Welcome!

**logstash-output-opensearch** is a community-driven, open source fork logstash-output-elasticsearch licensed under the [Apache v2.0 License](LICENSE). For more information, see [opensearch.org](https://opensearch.org/).

The logstash-output-opensearch plugin helps to ship events from Logstash to OpenSearch cluster.

## Project Resources

* [Project Website](https://opensearch.org/)
* [Detailed Documentation](https://opensearch.org/docs/latest/clients/logstash/ship-to-opensearch/#opensearch-output-plugin)
* [Logstash Overview](https://opensearch.org/docs/clients/logstash/index/)
* [Developer Guide](DEVELOPER_GUIDE.md)
* Need help? Try [Forums](https://discuss.opendistrocommunity.dev/)
* [Project Principles](https://opensearch.org/#principles)
* [Contributing to OpenSearch](CONTRIBUTING.md)
* [Maintainer Responsibilities](MAINTAINERS.md)
* [Release Management](RELEASING.md)
* [Admin Responsibilities](ADMINS.md)
* [Security](SECURITY.md)

## Configuration for Logstash Output Opensearch Plugin

To run the Logstash Output Opensearch plugin, add following configuration in your logstash.conf file.
```
output {
    opensearch {
        hosts       => ["hostname:port"]
        user        => "admin"
        password    => "admin"
        index       => "logstash-logs-%{+YYYY.MM.dd}"
    }
}
```

To run the Logstash Output Opensearch plugin using aws_iam authentication, refer to the sample configuration shown below:
```
output {
   opensearch {
          hosts => ["hostname:port"]
          auth_type => {
              type => 'aws_iam'
              aws_access_key_id => 'ACCESS_KEY'
              aws_secret_access_key => 'SECRET_KEY'
              region => 'us-west-2'
          }
          index  => "logstash-logs-%{+YYYY.MM.dd}"
   }
}
```

In addition to the existing authentication mechanisms, if we want to add new authentication then we will be adding them in the configuration by using auth_type.

Example Configuration for basic authentication:
```
output {
    opensearch {
          hosts  => ["hostname:port"]
          auth_type => {
              type => 'basic'
              user => 'admin'
              password => 'admin'
          }
          index => "logstash-logs-%{+YYYY.MM.dd}"
   }
}
```

To ingest data into a `data stream` through logstash, we need to create the data stream and specify the name of data stream and the `op_type` of `create` in the output configuration. The sample configuration is shown below:

```yml
output {
    opensearch {
          hosts  => ["https://hostname:port"]
          auth_type => {
              type => 'basic'
              user => 'admin'
              password => 'admin'
          }
          index => "my-data-stream"
          action => "create"
   }
}
```

Starting in 2.0.0, the aws sdk version is bumped to v3. In order for all other AWS plugins to work together, please remove pre-installed aws plugins and install logstash-integration-aws plugin as follows. See also https://github.com/logstash-plugins/logstash-mixin-aws/issues/38
```
# Remove existing logstash aws plugins and install logstash-integration-aws to keep sdk dependency the same
# https://github.com/logstash-plugins/logstash-mixin-aws/issues/38
/usr/share/logstash/bin/logstash-plugin remove logstash-input-s3
/usr/share/logstash/bin/logstash-plugin remove logstash-input-sqs
/usr/share/logstash/bin/logstash-plugin remove logstash-output-s3
/usr/share/logstash/bin/logstash-plugin remove logstash-output-sns
/usr/share/logstash/bin/logstash-plugin remove logstash-output-sqs
/usr/share/logstash/bin/logstash-plugin remove logstash-output-cloudwatch

/usr/share/logstash/bin/logstash-plugin install --version 0.1.0.pre logstash-integration-aws
bin/logstash-plugin install --version 2.0.0 logstash-output-opensearch
```
## ECS Compatibility
[Elastic Common Schema(ECS)](https://www.elastic.co/guide/en/ecs/current/index.html]) compatibility for V8 was added in 1.3.0. For more details on ECS support refer to this [documentation](docs/ecs_compatibility.md).


## Code of Conduct

This project has adopted the [Amazon Open Source Code of Conduct](CODE_OF_CONDUCT.md). For more information see the [Code of Conduct FAQ](https://aws.github.io/code-of-conduct-faq), or contact [opensource-codeofconduct@amazon.com](mailto:opensource-codeofconduct@amazon.com) with any additional questions or comments.

## License

This project is licensed under the [Apache v2.0 License](LICENSE).

## Copyright

Copyright OpenSearch Contributors. See [NOTICE](NOTICE) for details.
