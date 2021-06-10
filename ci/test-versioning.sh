#!/usr/bin/env bash
set -euo pipefail

modules="$PWD"
script='
find_package(Git REQUIRED)
include(version)
determine_version("${CMAKE_CURRENT_SOURCE_DIR}" RNP)
'

_mktemp() {
    local base=${1:-/tmp}
    if [[ $(uname) = Darwin ]]; then mktemp -d $base/rnp-cmake-version.XXXXXXXXXX
    else TMPDIR="$base" mktemp -d -t rnp-cmake-version.XXXXXXXXXX
    fi
}

expect_version() {
  [[ $# -eq 7 ]] || exit 1
  output=$(_mktemp)/output
  cmake -DCMAKE_MODULE_PATH="$modules" -P /dev/stdin <<<"$script" > "$output"
  cat "$output"

  for var in RNP_VERSION \
             RNP_VERSION_NCOMMITS \
             RNP_VERSION_GIT_REV \
             RNP_VERSION_IS_DIRTY \
             RNP_VERSION_COMMIT_TIMESTAMP \
             RNP_VERSION_SUFFIX \
             RNP_VERSION_FULL;
  do
    value=$(grep -F "$var: " "$output" | cut -d : -f 2- | cut -c 2-)
    if [[ $(echo "$value" | sed "s/^$1$/XX/g") != 'XX' ]] ; then
      echo "FAILURE: $var expected $1, but found $value"
      exit 1
    fi
    shift
  done
}

TDIR=$(_mktemp)
cd ${TDIR}

git init
git config --local user.email 'test@example.com'
git config --local user.name 'test'

echo > file1
git add file1
git commit -m .
sha=$(git rev-parse --short=7 --verify HEAD)

# no tags
expect_version \
  '0\.0\.0' \
  '0' \
  "$sha" \
  'FALSE' \
  '[[:digit:]]\{10\}' \
  '+git[[:digit:]]\{8\}.'"$sha" \
  '0\.0\.0+git[[:digit:]]\{8\}.'"$sha"

# exact tag
git checkout -b release/0.x
# diverge from master
echo > release
git add release
git commit -m .
sha=$(git rev-parse --short=7 --verify HEAD)
# tag
git tag -a v0.9.0 -m ''
expect_version \
  '0\.9\.0' \
  '0' \
  "$sha" \
  'FALSE' \
  '0' \
  '' \
  '0\.9\.0'
# exact tag, dirty
echo >> file1
expect_version \
  '0\.9\.0' \
  '0' \
  "$sha" \
  'TRUE' \
  '0' \
  '+git[[:digit:]]\{8\}' \
  '0\.9\.0+git[[:digit:]]\{8\}'
# after tag
git add file1
git commit -m .
sha=$(git rev-parse --short=7 --verify HEAD)
expect_version \
  '0\.9\.0' \
  '1' \
  "$sha" \
  'FALSE' \
  '0' \
  '+git[[:digit:]]\{8\}.1.'"$sha" \
  '0\.9\.0+git[[:digit:]]\{8\}.1.'"$sha"
# after tag, dirty
echo >> file1
expect_version \
  '0\.9\.0' \
  '1' \
  "$sha" \
  'TRUE' \
  '0' \
  '+git[[:digit:]]\{8\}.1.'"$sha" \
  '0\.9\.0+git[[:digit:]]\{8\}.1.'"$sha"
# master
# add a few tags
echo >> file1
git add file1
git commit -m .
git tag -a v0.10.0 -m ''
echo >> file1
git add file1
git commit -m .
git tag -a v0.11.0 -m ''
echo >> file1
git add file1
git commit -m .
git tag -a v1.0.0 -m ''
echo >> file1
git add file1
git commit -m .
git tag -a v0.12.0 -m ''
git checkout master
sha=$(git rev-parse --short=7 --verify HEAD)
expect_version \
  '0\.0\.0' \
  '0' \
  "$sha" \
  'FALSE' \
  '[[:digit:]]\{10\}' \
  '+git[[:digit:]]\{8\}.'"$sha" \
  '0\.0\.0+git[[:digit:]]\{8\}.'"$sha"

# version.txt
cd "$(_mktemp)"
# no tags
echo 'v0.0.0-0-g3bcf934+1579104076' > version.txt
expect_version \
  '0\.0\.0' \
  '0' \
  "3bcf934" \
  'FALSE' \
  '1579104076' \
  '+git[[:digit:]]\{8\}.3bcf934' \
  '0\.0\.0+git[[:digit:]]\{8\}.3bcf934'
# exact tag
echo 'v0.9.0-0-g6db3cc7' > version.txt
expect_version \
  '0\.9\.0' \
  '0' \
  '6db3cc7' \
  'FALSE' \
  '0' \
  '' \
  '0\.9\.0'
# exact tag, dirty
echo 'v0.9.0-0-g6db3cc7-dirty' > version.txt
expect_version \
  '0\.9\.0' \
  '0' \
  '6db3cc7' \
  'TRUE' \
  '0' \
  '+git[[:digit:]]\{8\}' \
  '0\.9\.0+git[[:digit:]]\{8\}'
# after tag
echo 'v0.9.0-1-g24cc43a' > version.txt
expect_version \
  '0\.9\.0' \
  '1' \
  '24cc43a' \
  'FALSE' \
  '0' \
  '+git[[:digit:]]\{8\}\.1\.24cc43a' \
  '0\.9\.0+git[[:digit:]]\{8\}\.1\.24cc43a'
# after tag, dirty
echo 'v0.9.0-1-g24cc43a-dirty' > version.txt
expect_version \
  '0\.9\.0' \
  '1' \
  '24cc43a' \
  'TRUE' \
  '0' \
  '+git[[:digit:]]\{8\}\.1\.24cc43a' \
  '0\.9\.0+git[[:digit:]]\{8\}\.1\.24cc43a'

# we have version.txt, git commits, but no release tags
cd "$(_mktemp)"
git init
git config --local user.email 'test@example.com'
git config --local user.name 'test'

echo 'v0.15.1' > version.txt
git add version.txt
git commit -m .
echo 'hello' > world.txt
git add world.txt
git commit -m .
sha=$(git rev-parse --short=7 --verify HEAD)

expect_version \
  '0\.15\.1' \
  '0' \
  "$sha" \
  'FALSE' \
  '[[:digit:]]\{10\}' \
  '+git[[:digit:]]\{8\}.'"$sha" \
  '0\.15\.1+git[[:digit:]]\{8\}.'"$sha"
