- [Developer Guide](#developer-guide)
    - [Getting Started](#getting-started)
        - [Git Clone logstash-output-opensearch](#git-clone-logstash-output-opensearch-repo)
        - [Install Prerequisites](#install-prerequisites)
            - [JRuby](#JRuby)
            - [Docker](#docker)
        - [Run Tests](#run-tests)
        - [Run plugin](#run-plugin-in-logstash)
        - [Configuration for Logstash Output OpenSearch Plugin](#configuration-for-logstash-output-opensearch-plugin)
    - [Submitting Changes](#submitting-changes)
    - [Backports](#backports) 
- [Building Custom Docker Images](docs/building_custom_docker_images.md)

# Developer Guide

So you want to contribute code to logstash-output-opensearch? Excellent! We're glad you're here. Here's what you need to do.

## Getting Started

### Fork the logstash-output-opensearch Repo

Fork [opensearch-project/logstash-output-opensearch](https://github.com/opensearch-project/logstash-output-opensearch) and clone locally.

Example:
```bash
    git clone https://github.com/[your username]/logstash-output-opensearch.git.
```

### Install Prerequisites

#### JRuby

This plugin builds using [JRuby](https://www.jruby.org/). This means you'll need JRuby with the Bundler gem installed.

One easy way to get JRuby on is to use [rvm](https://rvm.io/rvm). Please check [here](https://rvm.io/rvm/install) on how to install rvm on your system. 
If you use [rvm](https://rvm.io/rvm), then installing JRuby is also a piece of cake:
```bash
#Installing Jruby
rvm install jruby

# Use JRuby as interpreter for current shell
rvm use jruby

# If you want to set JRuby as default interpreter, use below command
rvm --default use jruby

#Installing bundler
gem install bundler
```

#### Docker

[Docker](https://docs.docker.com/install/) is required for executing unit and integration tests.

### Run Tests

Unit tests and integration tests are executed inside Docker environment. 
Perform the following from your project root directory eg: `~/workspace/logstash-output-opensearch`

#### Run Unit Tests

```bash
# Set up Environment variable for docker to pull your test environment
export LOGSTASH_VERSION=7.13.2 # will use 7.13.2 version if not specified.

# Set up docker ( this will build, install into Logstash )
scripts/unit-test/docker-setup.sh

# Run tests
scripts/unit-test/docker-run.sh
```

#### Run Integration Tests
1. Tests against OpenSearch clusters.

```bash
# Set up Environment variable for Docker to pull your test environment
export LOGSTASH_VERSION=7.13.2 # will use 7.13.2 version if not specified.
export OPENSEARCH_VERSION=1.0.0 # will use latest if not specified.

# Set up docker ( this will build, install into Logstash )
scripts/opensearch/docker-setup.sh

# Run tests
scripts/opensearch/docker-run.sh
```

2. Tests against Secured OpenSearch clusters

```bash
# Set up Environment variable for Docker to pull your test environment
export LOGSTASH_VERSION=7.13.2 # will use 7.13.2 version if not specified.
export OPENSEARCH_VERSION=1.0.0 # will use latest if not specified.
export SECURE_INTEGRATION=true # to run against cluster with security plugin
# Set up docker ( this will build, install into Logstash )
scripts/opensearch/docker-setup.sh

# Run tests
scripts/opensearch/docker-run.sh
```

3. Tests against OpenDistro clusters.

```bash
# Set up Environment variable for docker to pull your test environment
export LOGSTASH_VERSION=7.13.2 # will use 7.13.2 version if not specified.
export OPENDISTRO_VERSION=1.13.2 # will use latest if not specified.

# Set up docker ( this will build, install into Logstash )
scripts/opendistro/docker-setup.sh

# Run tests
scripts/opendistro/docker-run.sh
```

### Run plugin in Logstash

#### 2.1 Run in a local Logstash clone

1. Edit Logstash `Gemfile` and add the local plugin path, for example:

   ```ruby
   gem "logstash-output-opensearch", :path => "/your/local/logstash-output-opensearch"
   ```

2. Install the plugin:

   ```sh
   # Logstash 2.3 and higher
   bin/logstash-plugin install --no-verify

   # Prior to Logstash 2.3
   bin/plugin install --no-verify
   ```

3. Run Logstash with your plugin:

   ```sh
   bin/logstash -e 'output {opensearch {}}'
   ```

At this point any modifications to the plugin code will be applied to this local Logstash setup. After modifying the plugin, run Logstash again.

#### 2.2 Run in an installed Logstash

Build the gem locally and install it using:

1. Build your plugin gem:

   ```sh
    gem build logstash-output-opensearch.gemspec
   ```
   That’s it! Your gem should be built and be in the same path with the name
    ```
    Successfully built RubyGem
    Name: logstash-output-opensearch
    Version: 1.0.0
    File: logstash-output-opensearch-1.0.0.gem
    ```
   s.version number from your gemspec file will provide the gem version, in this case, 1.0.0.


2. Install the plugin from the Logstash home:

   ```sh
   # Logstash 2.3 and higher
   bin/logstash-plugin install ~/workspace/logstash-output-opensearch/logstash-output-opensearch-1.0.0.gem

   # Prior to Logstash 2.3
   bin/plugin install ~/workspace/logstash-output-opensearch/logstash-output-opensearch-1.0.0.gem
   ```
   
   After running this, you should see the following feedback from Logstash to test the installation:
    ```bash
    validating ~/workspace/logstash-output-opensearch/logstash-output-opensearch-1.0.0.gem >= 0
    Valid logstash plugin. Continuing...
    Successfully installed 'logstash-output-opensearch' with version '1.0.0' 
   ```

3. Start Logstash and test the plugin.

    ```bash
   bin/logstash-plugin list 
   ```

## Configuration for Logstash Output OpenSearch Plugin

To run the Logstash Output Opensearch plugin, add following configuration in your logstash.conf file.
Note: For logstash running with OpenSearch 2.12.0 and higher the admin password needs to be a custom strong password supplied during cluster setup.

```
output {
    opensearch {
        hosts       => ["hostname:port"]
        user        => "admin"
        password    => "<your-admin-password>"
        index       => "logstash-logs-%{+YYYY.MM.dd}"
    }
}
```

### Authentication
Authentication to a secure OpenSearch cluster is possible by using username/password.

### Authorization

Authorization to a secure OpenSearch cluster requires read permission at [index level](https://opensearch.org/docs/security-plugin/access-control/default-action-groups/#index-level).

## Submitting Changes

See [CONTRIBUTING](CONTRIBUTING.md).

## Backports

The Github workflow in [`backport.yml`](.github/workflows/backport.yml) creates backport PRs automatically when the
original PR with an appropriate label `backport <backport-branch-name>` is merged to main with the backport workflow
run successfully on the PR. For example, if a PR on main needs to be backported to `1.x` branch, add a label
`backport 1.x` to the PR and make sure the backport workflow runs on the PR along with other checks. Once this PR is
merged to main, the workflow will create a backport PR to the `1.x` branch.

# [Building Custom Docker Images](docs/building_custom_docker_images.md)

