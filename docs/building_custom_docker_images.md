- [Building Custom Docker Images](#building-custom-docker-images)
  - [Logstash 8.x](#logstash-8x)
  - [Logstash 7.x](#logstash-7x)
    - [Build Logstash Output OpenSearch Plugin Gem](#build-logstash-output-opensearch-plugin-gem)
    - [Dockerfile](#dockerfile)


# Building Custom Docker Images

To build an image that is not available in the [official Docker repository tags](https://hub.docker.com/r/opensearchproject/logstash-oss-with-opensearch-output-plugin/tags), or to add specific plugins to your image, you can create a custom Dockerfile.

The process varies depending on whether you want to build an image with `Logstash 8.x` versions or `Logstash 7.x` versions

## Logstash 8.x

Create this `Dockerfile` to build an image with `OpenSearch 2.0.2` for **`Logstash 8.x`**

``` Dockerfile
ARG APP_VERSION

FROM docker.elastic.co/logstash/logstash-oss:${APP_VERSION}
RUN logstash-plugin install --version 7.1.1 logstash-integration-aws
RUN logstash-plugin install --version 2.0.2 logstash-output-opensearch
```

## Logstash 7.x

For **`Logstash 7.x`** , the Logstash output OpenSearch gem needs to be build.

### Build Logstash Output OpenSearch Plugin Gem

1. Clone `logstash-output-opensearch repo` 

    ```sh
    git clone https://github.com/opensearch-project/logstash-output-opensearch.git
    ```

2. Checkout the tag for the plugin version you want to build. For the version [2.0.2](https://github.com/opensearch-project/logstash-output-opensearch/tree/2.0.2) for example

    ```sh
    git checkout 2.0.2
    ```


3. Remove [this line that adds the json version spec](https://github.com/opensearch-project/logstash-output-opensearch/blob/2.0.2/logstash-output-opensearch.gemspec#L49). This version of the JSON gem is incompatible with `Logstash version 7.x`.

4. Build the gem by running the following command:

    ```sh
    gem build logstash-output-opensearch.gemspec
    ```

    The Gemfile `logstash-output-opensearch-2.0.2-x86_64-linux.gem` will be generated.

### Dockerfile

Create this Dockerfile to build an image with `logstash version 7.x` and the previously generated `Gemfile` :

```Dockerfile
ARG APP_VERSION

FROM docker.elastic.co/logstash/logstash-oss:${APP_VERSION}

USER logstash
# Remove existing logstash aws plugins and install logstash-integration-aws to keep sdk dependency the same
# https://github.com/logstash-plugins/logstash-mixin-aws/issues/38
# https://github.com/opensearch-project/logstash-output-opensearch#configuration-for-logstash-output-opensearch-plugin
RUN logstash-plugin remove logstash-input-s3
RUN logstash-plugin remove logstash-input-sqs
RUN logstash-plugin remove logstash-output-s3
RUN logstash-plugin remove logstash-output-sns
RUN logstash-plugin remove logstash-output-sqs
RUN logstash-plugin remove logstash-output-cloudwatch

RUN logstash-plugin install --version 7.1.1 logstash-integration-aws

COPY logstash-output-opensearch-2.0.2-x86_64-linux.gem /usr/share
RUN logstash-plugin install /usr/share/logstash-output-opensearch-2.0.2-x86_64-linux.gem
```
