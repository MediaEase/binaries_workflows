#!/usr/bin/env python3

import yaml
import sys
import os
import argparse
import json
import copy

def load_yaml(yaml_path):
    """Load YAML file."""
    print(f"Loading YAML file from '{yaml_path}'...")
    with open(yaml_path, 'r') as f:
        data = yaml.safe_load(f)
    print("YAML file loaded successfully.")
    return data

def save_yaml_if_changed(original_data, updated_data, yaml_path):
    """Save YAML file only if there are changes."""
    if original_data != updated_data:
        print(f"Changes detected. Saving updated YAML data to '{yaml_path}'...")
        with open(yaml_path, 'w') as f:
            yaml.dump(updated_data, f, sort_keys=False)
        print("YAML file saved successfully.")
    else:
        print("No changes detected. Skipping save operation.")

def update_package_entry(manifest, package_id, checksum, build_date, package_version, category):
    """
    Update or add a package entry in the manifest.

    Args:
        manifest (dict): The YAML manifest data.
        package_id (str): The package identifier (e.g., 'xmlrpc-c-advanced').
        checksum (str): The SHA256 checksum.
        build_date (str): The build date.
        package_version (str): The version of the package.
        category (str): The category of the package.
    """
    print(f"Updating package entry for '{package_id}' in the manifest...")
    if 'packages' not in manifest:
        manifest['packages'] = {}
        print("No 'packages' key found in manifest. Initialized 'packages' dictionary.")

    if package_id not in manifest['packages']:
        # Create a new package entry
        manifest['packages'][package_id] = {
            'version': package_version,
            'checksum_sha256': checksum,
            'category': category,
            'build_date': build_date,
            'distribution': ['bookworm']
        }
        print(f"Added new package '{package_id}' to manifest.")
    else:
        # Update existing package entry
        print(f"Package '{package_id}' already exists in manifest. Updating its information...")
        manifest['packages'][package_id]['version'] = package_version
        manifest['packages'][package_id]['checksum_sha256'] = checksum
        manifest['packages'][package_id]['build_date'] = build_date
        manifest['packages'][package_id]['category'] = category
        print(f"Updated existing package '{package_id}' in manifest.")

def update_application_entry(manifest, application_id, build_date, application_info):
    """
    Update or add an application entry in the manifest.

    Args:
        manifest (dict): The YAML manifest data.
        application_id (str): The application identifier (e.g., 'deluge').
        build_date (str): The build date.
        application_info (dict): The application details with dependencies and package info.
    """
    print(f"Updating application entry for '{application_id}' in the manifest...")
    if 'applications' not in manifest:
        manifest['applications'] = {}
        print("No 'applications' key found in manifest. Initialized 'applications' dictionary.")

    # Add or update the application entry
    manifest['applications'][application_id] = {
        'build_date': build_date,
        'dependencies': application_info.get('dependencies', []),
        'packages': application_info.get('packages', {})
    }

    print(f"Updated or added application '{application_id}' in the manifest.")

def main():
    print("Starting update_manifest.py script...")
    parser = argparse.ArgumentParser(description='Update manifest.yaml for packages or applications.')
    parser.add_argument('repo_path', help='Path to the binaries repository.')
    parser.add_argument('updates', help='JSON string of package or application updates.')
    args = parser.parse_args()

    repo_path = args.repo_path
    updates_json = args.updates

    print("Parsed arguments:")
    print(f"  repo_path: {repo_path}")
    print(f"  updates: {updates_json}")

    try:
        updates = json.loads(updates_json)
    except json.JSONDecodeError as e:
        print(f"Error parsing updates JSON: {e}")
        sys.exit(1)

    manifest_path = os.path.join(repo_path, "manifest.yaml")
    if not os.path.isfile(manifest_path):
        print(f"Error: Manifest file '{manifest_path}' does not exist.")
        sys.exit(1)
    else:
        print(f"Manifest file '{manifest_path}' found.")

    # Load original manifest data
    original_manifest = load_yaml(manifest_path)
    
    # Make a copy to update
    updated_manifest = copy.deepcopy(original_manifest)

    # Handle package updates
    if 'package_updates' in updates:
        print("Processing package updates...")
        package_updates = updates['package_updates']
        for package_id, package_info in package_updates.items():
            checksum = package_info.get('checksum')
            category = package_info.get('category')
            package_version = package_info.get('version')
            build_date = package_info.get('build_date')

            if not checksum:
                print(f"Error: No checksum provided for package '{package_id}'.")
                sys.exit(1)
            if not package_version:
                print(f"Error: No version provided for package '{package_id}'.")
                sys.exit(1)
            if not build_date:
                print(f"Error: No build date provided for package '{package_id}'.")
                sys.exit(1)

            update_package_entry(
                manifest=updated_manifest,
                package_id=package_id,
                checksum=checksum,
                build_date=build_date,
                package_version=package_version,
                category=category
            )

    # Handle application updates
    if 'application_updates' in updates:
        print("Processing application updates...")
        application_updates = updates['application_updates']
        for application_id, application_info in application_updates.items():
            build_date = application_info.get('build_date', None)
            update_application_entry(
                manifest=updated_manifest,
                application_id=application_id,
                build_date=build_date,
                application_info=application_info
            )

    # Save the manifest only if there are changes
    save_yaml_if_changed(original_manifest, updated_manifest, manifest_path)
    print(f"Successfully updated manifest.yaml for packages or applications.")

if __name__ == "__main__":
    main()
