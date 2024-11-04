- [Overview](#overview)
- [Branching](#branching)
  - [Release Branching](#release-branching)
  - [Feature Branches](#feature-branches)
- [Release Labels](#release-labels)
- [Releasing](#releasing)

## Overview

This document explains the release strategy for artifacts in this organization.

## Branching

### Release Branching

This project currently releases only from `main`.

### Feature Branches

Do not creating branches in the upstream repo, use your fork, for the exception of long lasting feature branches that require active collaboration from multiple developers. Name feature branches `feature/<thing>`. Once the work is merged to `main`, please make sure to delete the feature branch.

## Release Labels

Repositories create consistent release labels, such as `1.0.0`, `1.1.0` and `2.0.0`, as well as `backport`. Use release labels to target an issue or a PR for a given release. See [MAINTAINERS](MAINTAINERS.md#triage-open-issues) for more information on triaging issues.

## Releasing

The release process is standard across repositories in this org and is run by a release manager volunteering from amongst [MAINTAINERS](MAINTAINERS.md).

1. Create a tag, e.g. `1.0.0`, and push it to this GitHub repository. You can do this from your local fork:
   1. `git fetch upstream --tags`
   1. `git tag 2.0.3`
   1. `git push --tags upstream`
1. The [release-drafter.yml](.github/workflows/release-drafter.yml) will be automatically kicked off and a draft release will be created.
1. This draft release triggers the [jenkins release workflow](https://build.ci.opensearch.org/job/logstash-output-opensearch-release) as a As a result of which the logstash-output-plugin is released on [rubygems.org](https://rubygems.org/gems/logstash-output-opensearch). Please note that the release workflow is triggered only if created release is in draft state.
1. Once the above release workflow is successful, the drafted release on GitHub is published automatically.
1. Increment "version" in [logstash-output-opensearch.gemspec](./logstash-output-opensearch.gemspec) to the next iteration, e.g. 1.0.1.
