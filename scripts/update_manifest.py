#!/usr/bin/env python3

import yaml
import sys
import os
import argparse
import json
import copy

def load_yaml(yaml_path):
    """Charge le fichier YAML."""
    print(f"Chargement du fichier YAML depuis '{yaml_path}'...")
    with open(yaml_path, 'r') as f:
        data = yaml.safe_load(f)
    print("Fichier YAML chargé avec succès.")
    return data

def save_yaml_if_changed(original_data, updated_data, yaml_path):
    """Sauvegarde le fichier YAML uniquement s'il y a des changements."""
    if original_data != updated_data:
        print(f"Changements détectés. Sauvegarde du manifest mis à jour dans '{yaml_path}'...")
        with open(yaml_path, 'w') as f:
            yaml.dump(updated_data, f, sort_keys=False)
        print("Manifest sauvegardé avec succès.")
    else:
        print("Aucun changement détecté. Opération de sauvegarde ignorée.")

def update_package_entry(manifest, package_id, checksum, build_date, package_version, category, tag=None, build=None):
    """
    Met à jour ou ajoute une entrée de package dans le manifest en utilisant
    une structure plate, sans distinction runtime/development.
    
    La structure attendue est :
    packages:
      <package_id>:
        <version>: { checksum_sha256, build_date, build, category, tag, distribution }
    """
    print(f"Mise à jour de l'entrée pour le package '{package_id}', version '{package_version}', build '{build}'...")
    if 'packages' not in manifest or not isinstance(manifest['packages'], dict):
        manifest['packages'] = {}
        print("Clé 'packages' initialisée dans le manifest.")
    
    if package_id not in manifest['packages']:
        manifest['packages'][package_id] = {}
        print(f"Nouvelle entrée créée pour le package '{package_id}'.")
    
    manifest['packages'][package_id][package_version] = {
        'checksum_sha256': checksum,
        'build_date': build_date,
        'build': build,
        'category': category,
        'tag': tag,  # Ce champ peut être None si non précisé
        'distribution': ['bookworm']
    }
    print(f"Package '{package_id}', version '{package_version}', build '{build}' mis à jour.")

def update_application_entry(manifest, application_id, build_date, application_info):
    """
    Met à jour ou ajoute une entrée d'application dans le manifest.
    """
    print(f"Mise à jour de l'entrée pour l'application '{application_id}'...")
    if 'applications' not in manifest:
        manifest['applications'] = {}
        print("Clé 'applications' initialisée dans le manifest.")
    
    manifest['applications'][application_id] = {
        'build_date': build_date,
        'dependencies': application_info.get('dependencies', []),
        'packages': application_info.get('packages', {})
    }
    print(f"Application '{application_id}' mise à jour.")

def main():
    print("Démarrage du script update_manifest.py...")
    parser = argparse.ArgumentParser(description='Met à jour manifest.yaml pour les packages ou applications.')
    parser.add_argument('repo_path', help='Chemin vers le répertoire des binaires.')
    parser.add_argument('updates', help='Chaîne JSON contenant les mises à jour des packages ou applications.')
    args = parser.parse_args()

    repo_path = args.repo_path
    updates_json = args.updates

    print("Arguments parsés :")
    print(f"  repo_path: {repo_path}")
    print(f"  updates: {updates_json}")

    try:
        updates = json.loads(updates_json)
    except json.JSONDecodeError as e:
        print(f"Erreur lors du parsing du JSON de mise à jour : {e}")
        sys.exit(1)

    manifest_path = os.path.join(repo_path, "manifest.yaml")
    if not os.path.isfile(manifest_path):
        print(f"Erreur : le fichier manifest '{manifest_path}' n'existe pas.")
        sys.exit(1)
    else:
        print(f"Manifest trouvé : '{manifest_path}'.")

    original_manifest = load_yaml(manifest_path)
    updated_manifest = copy.deepcopy(original_manifest)

    # Traitement des mises à jour pour les packages
    if 'package_updates' in updates:
        print("Traitement des mises à jour de packages...")
        package_updates = updates['package_updates']
        # Première boucle sur la catégorie (clé : libtorrent ou libtorrent-dev)
        for category_key, versions in package_updates.items():
            # Boucle sur chaque version dans la catégorie
            for package_version, package_info in versions.items():
                # Extraction des informations dans le niveau le plus profond
                checksum = package_info.get('checksum_sha256')
                package_id = package_info.get('package_id')
                build_date = package_info.get('build_date')
                tag = package_info.get('tag')
                category = package_info.get('category')
                build = package_info.get('build')
                if package_id in ["libtorrent21", "libtorrent22", "libtorrent24"]:
                    package_id = "libtorrent"
                if not checksum:
                    print(f"Erreur : aucun checksum fourni pour le package '{package_id}'.")
                    sys.exit(1)
                if not package_version:
                    print(f"Erreur : aucune version fournie pour le package '{package_id}'.")
                    sys.exit(1)
                if not build_date:
                    print(f"Erreur : aucune date de build fournie pour le package '{package_id}'.")
                    sys.exit(1)
                if not build:
                    print(f"Erreur : aucun build fourni pour le package '{package_id}'.")
                    sys.exit(1)
                update_package_entry(
                    manifest=updated_manifest,
                    package_id=package_id,
                    checksum=checksum,
                    build_date=build_date,
                    package_version=package_version,
                    category=category,
                    tag=tag,
                    build=build
                )

    # Traitement des mises à jour pour les applications
    if 'application_updates' in updates:
        print("Traitement des mises à jour d'applications...")
        application_updates = updates['application_updates']
        for application_id, application_info in application_updates.items():
            build_date = application_info.get('build_date', None)
            update_application_entry(
                manifest=updated_manifest,
                application_id=application_id,
                build_date=build_date,
                application_info=application_info
            )

    save_yaml_if_changed(original_manifest, updated_manifest, manifest_path)
    print("Manifest mis à jour avec succès.")

if __name__ == "__main__":
    main()
