#!/bin/bash
set -ex

export PATH=$BUILD_DIR/gradle/bin:$PATH

SERVICE_URL="http://integration:9200"

if [[ "$SECURE_INTEGRATION" == "true" ]]; then
  OPENSEARCH_REQUIRED_VERSION="2.12.0"
  # Starting in 2.12.0, security demo configuration script requires an initial admin password
  COMPARE_VERSION=`echo $OPENSEARCH_REQUIRED_VERSION $OPENSEARCH_VERSION | tr ' ' '\n' | sort -V | uniq | head -n 1`
  if [ -n "$OPENDISTRO_VERSION" ] || [ "$COMPARE_VERSION" != "$OPENSEARCH_REQUIRED_VERSION" ]; then
    CREDENTIAL="admin:admin"
  else
    CREDENTIAL="admin:myStrongPassword123!"
  fi

  SERVICE_URL="https://integration:9200 -k -u $CREDENTIAL"
fi

wait_for_es() {
  count=5
  while ! curl -s $SERVICE_URL >/dev/null && [[ $count -ne 0 ]]; do
    count=$(( $count - 1 ))
    [[ $count -eq 0 ]] && exit 1
    sleep 20
  done
  echo $(curl -s $SERVICE_URL | grep -oP '"number"[^"]+"\K[^"]+')
}

if [[ "$SECURE_INTEGRATION" == "true" ]]; then
  extra_tag_args="--tag secure_integration"
else
  extra_tag_args="--tag ~secure_integration --tag integration"
fi

echo "Waiting for cluster to respond..."
VERSION=$(wait_for_es)
echo "Integration test cluster $VERSION is Up!"
bundle exec rspec -fd $extra_tag_args --tag update_tests:painless --tag version:$VERSION spec/integration
