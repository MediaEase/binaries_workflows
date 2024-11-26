#!/bin/bash

# Arguments:
# $1 - The name of the package (e.g., libtorrent-rasterbar2.0t64)
# $2 - The upstream version (e.g., 2.0.7)
# $3 - The current directory where the package is stored

PACKAGE_NAME=$1
UPSTREAM_VERSION=$2
CURRENT_DIR=$3

# Extract the highest existing build number from the current directory
LATEST_BUILD=$(find "$CURRENT_DIR" -name "${PACKAGE_NAME}_${UPSTREAM_VERSION}-*.deb" | sed -n 's/.*build\([0-9]\+\)_amd64\.deb/\1/p' | sort -n | tail -n1)

# If no existing builds are found, start with 1, otherwise increment the latest build number
if [ -z "$LATEST_BUILD" ]; then
    NEW_BUILD_NUMBER=1
else
    NEW_BUILD_NUMBER=$((LATEST_BUILD + 1))
fi

# Output the new build number
echo "build${NEW_BUILD_NUMBER}"
