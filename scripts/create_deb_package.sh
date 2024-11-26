#!/bin/bash

# Function to assign options for FPM packaging
function assign_options() {
    declare -g INPUT_TYPE OUTPUT_TYPE NAME VERSION ARCHITECTURE DESCRIPTION CHDIR PACKAGE DEPENDS PROVIDES
    INPUT_TYPE="dir"
    OUTPUT_TYPE="deb"
    NAME="${1}"
    NAME="${NAME%-t64}"
    if [[ "${NAME}" == libtorrent-rasterbar* ]]; then
        NAME="libtorrent-rasterbar"
    fi
    VERSION="${2}"
    ARCHITECTURE="${3:-amd64}"
    DESCRIPTION="${4}"
    CHDIR="${5}"
    PACKAGE="${6}"
    shift 6
    DEPENDS=("$@")
    if [[ ! "${VERSION}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo "Invalid version format. Please use the format '1.0.0' or similar."
        exit 1
    fi
    PROVIDES="${NAME%-nightly}"
}

# Function to create the .deb package using FPM
function create_deb_package() {
    fpm_args=(
        --force
        --input-type "${INPUT_TYPE}"
        --output-type "${OUTPUT_TYPE}"
        --name "${NAME}"
        --package "${PACKAGE}"
        --version "${VERSION}"
        --architecture "${ARCHITECTURE}"
        --description "${DESCRIPTION}"
        --iteration 1
        --chdir "${CHDIR}"
        --provides "${PROVIDES}"
        --maintainer "root@mediaease.dev"
    )

    # Add dependencies
    for dependency in "${DEPENDS[@]}"; do
        fpm_args+=("-d" "${dependency}")
    done

    echo "Creating package with the following arguments:"
    echo "fpm ${fpm_args[*]} ."
    echo "Package will be created in ${PACKAGE}"
    echo "Please wait..."

    # Run the fpm command using the array of arguments
    fpm "${fpm_args[@]}" .
}

# Main function to accept parameters and invoke the packaging process
function main() {
    if [[ $# -lt 6 ]]; then
        echo "Usage: $0 <name> <version> <architecture> <description> <chdir> <package> [<depends>]"
        exit 1
    fi

    assign_options "$@"
    create_deb_package
}

# Execute the main function with all arguments passed to the script
main "$@"
