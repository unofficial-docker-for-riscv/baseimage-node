#!/bin/bash
ALPINE_VERSION=${ALPINE_VERSION:-3.21}
NODE_USE_CURRENT=${NODE_USE_CURRENT:-false}

get_version() {
  local package=$1
  local prefix=$2
  local repo=${3:-main}
  local apkbuild=$(curl -s "https://gitlab.alpinelinux.org/alpine/aports/-/raw/${ALPINE_VERSION}-stable/${repo}/${package}/APKBUILD")
  export ${prefix}_VERSION=$(echo "${apkbuild}" | grep pkgver= | cut -d= -f2)
  export ${prefix}_RELEASE=$(echo "${apkbuild}" | grep pkgrel= | cut -d= -f2)
}

if [[ "${NODE_USE_CURRENT}" == "true" ]]; then
  get_version "nodejs-current" "NODE" "community"
  export NODE="nodejs-current"
else
  get_version "nodejs" "NODE"
  export NODE="nodejs"
fi
echo "node.js: ${NODE_VERSION}-r${NODE_RELEASE}"
NODE_VERSION_MAJOR=$(echo "${NODE_VERSION}" | cut -d. -f1)
NODE_VERSION_MINOR=$(echo "${NODE_VERSION}" | cut -d. -f2)

get_version "yarn" "YARN" "community"
echo "yarn: ${YARN_VERSION}-r${YARN_RELEASE}"

REPOS=(${REPOS:-ngc7331/riscv-baseimage-node})
TAGS=()
for repo in ${REPOS[@]}; do
  for suffix in "" "${ALPINE_VERSION}"; do
    VERSIONS=("${NODE_VERSION_MAJOR}" "${NODE_VERSION_MAJOR}.${NODE_VERSION_MINOR}" "${NODE_VERSION}")
    if [[ "${NODE_VERSION_MAJOR}" == "23" ]]; then
      VERSIONS+=("current")
      TAGS+=("-t ${repo}:alpine${suffix}")
    elif [[ "${NODE_VERSION_MAJOR}" == "22" ]]; then
      VERSIONS+=("lts" "jod")
    elif [[ "${NODE_VERSION_MAJOR}" == "20" ]]; then
      VERSIONS+=("iron")
    fi

    for version in ${VERSIONS[@]}; do
      TAGS+=("-t ${repo}:${version}-alpine${suffix}")
    done
  done
done

echo "Building with tags: ${TAGS[@]}"

docker buildx build \
  ${TAGS[@]} \
  --push \
  --build-arg ALPINE_VERSION=${ALPINE_VERSION} \
  --build-arg NODE=${NODE} \
  --build-arg NODE_VERSION=${NODE_VERSION} \
  --build-arg NODE_RELEASE=${NODE_RELEASE} \
  --build-arg YARN_VERSION=${YARN_VERSION} \
  --build-arg YARN_RELEASE=${YARN_RELEASE} \
  --platform linux/riscv64 \
  -f Dockerfile.alpine .
