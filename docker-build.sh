#!/usr/bin/env bash

platforms="linux/amd64,linux/arm64"
version=${VERSION:-6.8.48}
agentVersion=${AGENT_VERSION:-6.7.4}
downloadUrlPrefix="https://downloads.datastax.com"

downloadServerUrlTemplate="${downloadUrlPrefix}/enterprise/dse-${version}-bin.tar.gz"
downloadAgentUrlTemplate="${downloadUrlPrefix}/enterprise/datastax-agent-${agentVersion}.tar.gz"
downloadOpscenterUrlTemplate="${downloadUrlPrefix}/enterprise/opscenter-${version}.tar.gz"
downloadStudioUrlTemplate="${downloadUrlPrefix}/datastax-studio/datastax-studio-${version}.tar.gz"
downloadDdacUrlTemplate="${downloadUrlPrefix}/ddac/ddac-${version}-bin.tar.gz"

echo "Running Gradle task to template Dockerfiles..."

if ./gradlew buildServer${version}Image; then
  echo "Completed Gradle task successfully"
else
  echo "Failed to run Gradle task!"
  exit 1
fi

docker run --privileged --rm tonistiigi/binfmt --install all
docker buildx create --use --name builder
docker buildx inspect --bootstrap builder

echo "Building and pushing dse base image..."
cd base
docker buildx build \
  --platform "$platforms" \
  -t "datacatering/dse-base:$version" --push .
if [ $? -ne 0 ]; then
  echo "Failed to build base image!"
  exit 1
fi
cd ..

echo "Building and pushing dse-server docker image..."
cd build/server/$version
docker buildx build \
  --platform "$platforms" \
  --build-arg "VERSION=$version" \
  --build-arg "DOWNLOAD_URL=$downloadServerUrlTemplate" \
  --build-arg "TARBALL=dse-${version}-bin.tar.gz" \
  --build-arg "DSE_AGENT_VERSION=$agentVersion" \
  --build-arg "DSE_AGENT_DOWNLOAD_URL=$downloadAgentUrlTemplate" \
  --build-arg "DSE_AGENT_TARBALL=datastax-agent-${agentVersion}.tar.gz" \
  -t "datacatering/dse-server:$version" --push .
if [ $? -ne 0 ]; then
  echo "Failed to build dse-server image!"
  exit 1
fi
cd ../../..
