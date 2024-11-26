#!/bin/bash

# Define paths
CURRENT_DIR=$1
ARCHIVE_DIR=$2
PACKAGE_PATH=$3

# Ensure the archive and current directories exist
mkdir -p "$ARCHIVE_DIR"
mkdir -p "$CURRENT_DIR"

# Get the package filename without version and architecture
PACKAGE_FILENAME=$(basename "$PACKAGE_PATH")
PACKAGE_BASE_NAME=$(echo "$PACKAGE_FILENAME" | sed -E 's/_[^_]+_[^_]+\.deb$//')

# Define the pattern to find existing packages with the same base name
PACKAGE_PATTERN="${PACKAGE_BASE_NAME}_*_*\.deb"

# Check if there's an existing package in the current directory
EXISTING_PACKAGE=$(find "$CURRENT_DIR" -maxdepth 1 -type f -name "$PACKAGE_PATTERN" -print -quit)
if [ -n "$EXISTING_PACKAGE" ]; then
    NEW_CHECKSUM=$(sha256sum "$PACKAGE_PATH" | awk '{ print $1 }')
    EXISTING_CHECKSUM=$(sha256sum "$EXISTING_PACKAGE" | awk '{ print $1 }')
    if [ "$NEW_CHECKSUM" != "$EXISTING_CHECKSUM" ]; then
        echo "Checksums differ. Archiving the existing package."
        # Archive the existing package
        mv "$EXISTING_PACKAGE" "$ARCHIVE_DIR/"
        echo "Archived existing package to $ARCHIVE_DIR."
        # Move the new package to the current directory
        mv "$PACKAGE_PATH" "$CURRENT_DIR/"
        echo "Moved new package to $CURRENT_DIR."
    else
        echo "Checksums are the same. Skipping archival and move."
    fi
else
    echo "No existing package found for $PACKAGE_BASE_NAME. Moving the new package."
    # Move the new package to the current directory
    mv "$PACKAGE_PATH" "$CURRENT_DIR/"
    echo "Moved new package to $CURRENT_DIR."
fi
