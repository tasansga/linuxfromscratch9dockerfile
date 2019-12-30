#!/bin/bash

set -e

wget --input-file=./wget-list --continue --directory-prefix=./sources
pushd ./sources
md5sum -c md5sums
popd


