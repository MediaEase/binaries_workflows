#!/bin/bash
set -e

########################################
# 1. Configuration variables
########################################
if [ "$#" -ne 6 ]; then
    echo "Usage: $0 <ARCHITECTURE> <FULL_VERSION> <RUNTIME_PKG> <DEV_PKG> <INSTALL_DIR>"
    exit 1
fi

ARCHITECTURE="$1"
FULL_VERSION="$2"
RUNTIME_PKG="$3"
DEV_PKG="$4"
INSTALL_DIR="$5"
TAG="$6"

MAINTAINER="Jose Luis Rivas <ghostbar@debian.org>, Thomas Chauveau <contact.tomc@yahoo.fr>"

########################################
# 4. Download libtorrent-dev and libtorrent21t64
########################################
echo "Downloading libtorrent-dev and libtorrent21t64..."
sudo apt-get update -qq
sudo apt-get download libtorrent-dev libtorrent21t64

deb_dev=$(find . -maxdepth 3 -name 'libtorrent-dev_*.deb' | head -n 1)
echo "Downloaded libtorrent-dev : $deb_dev"
doc_extract_dir=$(mktemp -d)
sudo dpkg-deb -x "$deb_dev" "$doc_extract_dir"
DOC_SRC="${doc_extract_dir}/usr/share/doc/libtorrent-dev"
if [ ! -d "$DOC_SRC" ]; then
    echo "Error: Documentation directory not found in $deb_dev"
    exit 1
fi

# Extraction du paquet libtorrent21t64 pour récupérer la structure officielle
deb_rt21=$(find . -maxdepth 3 -name 'libtorrent21t64_*.deb' | head -n 1)
echo "Downloaded libtorrent21t64 : $deb_rt21"
runtime_extract_dir=$(mktemp -d)
sudo dpkg-deb -x "$deb_rt21" "$runtime_extract_dir"

########################################
# Build the runtime package (RUNTIME_PKG)
########################################
pkg_runtime=$(mktemp -d)
echo "Create runtime package structure ($RUNTIME_PKG)..."
mkdir -p "$pkg_runtime/usr"
rsync -a --exclude='*.deb' "$runtime_extract_dir/usr/" "$pkg_runtime/usr/"
rt_lib_dir="$pkg_runtime/usr/lib/x86_64-linux-gnu"
LIB_FILE=$(find "$INSTALL_DIR/usr/lib" -maxdepth 1 -type f -name "libtorrent.so.*" | sort | tail -n 1)
if [ -z "$LIB_FILE" ]; then
    echo "Erreur : fichier libtorrent.so non trouvé dans $INSTALL_DIR/usr/lib"
    exit 1
fi
LIB_FILENAME=$(basename "$LIB_FILE")
MAJOR_VERSION=$(echo "$LIB_FILENAME" | cut -d'.' -f2)
echo "Bibliothèque détectée : $LIB_FILENAME (version majeure : $MAJOR_VERSION)"
rt_lib_dir="$pkg_runtime/usr/lib/x86_64-linux-gnu"
rm -f "$rt_lib_dir"/libtorrent.so*
cp "$INSTALL_DIR/usr/lib/$LIB_FILENAME" "$rt_lib_dir/"
cd "$rt_lib_dir"
ln -s "$LIB_FILENAME" "libtorrent.so.${MAJOR_VERSION}"
doc_dir="$pkg_runtime/usr/share/doc/libtorrent21t64"
if [ -d "$doc_dir" ]; then
    mv "$doc_dir" "$pkg_runtime/usr/share/doc/$RUNTIME_PKG"
else
    mkdir -p "$pkg_runtime/usr/share/doc/$RUNTIME_PKG"
    cp -r "$DOC_SRC/." "$pkg_runtime/usr/share/doc/$RUNTIME_PKG/"
fi
runtime_size=$(du -s -k "$pkg_runtime/usr" | cut -f1)

mkdir -p "$pkg_runtime/DEBIAN"
cat > "$pkg_runtime/DEBIAN/control" <<EOF
Package: $RUNTIME_PKG
Source: libtorrent ($FULL_VERSION)
Version: $FULL_VERSION
Architecture: $ARCHITECTURE
Maintainer: $MAINTAINER
Installed-Size: $runtime_size
Depends: libc6 (>= 2.33), libgcc-s1 (>= 3.4), libssl3 (>= 3.0.0), libstdc++6 (>= 11), zlib1g (>= 1:1.1.4)
Section: libs
Priority: optional
Multi-Arch: same
Homepage: https://rakshasa.github.io/rtorrent/
Description: C++ BitTorrent library by Rakshasa
 LibTorrent is a BitTorrent library written in C++ for *nix.
 It is designed to avoid redundant copying and storing of data that other
 clients and libraries suffer from.
 .
 This package is not official, it is built for MediaEase.
EOF

########################################
# Build the dev package (DEV_PKG)
########################################
pkg_dev=$(mktemp -d)
echo "Create dev package structure ($DEV_PKG)..."
mkdir -p "$pkg_dev/usr/include"
cp -r "$INSTALL_DIR/usr/include/torrent" "$pkg_dev/usr/include/"
mkdir -p "$pkg_dev/usr/lib/x86_64-linux-gnu/pkgconfig"
cp "$INSTALL_DIR/usr/lib/pkgconfig/libtorrent.pc" "$pkg_dev/usr/lib/x86_64-linux-gnu/pkgconfig/"
mkdir -p "$pkg_dev/usr/share/doc/$DEV_PKG"
cp -r "$DOC_SRC/." "$pkg_dev/usr/share/doc/$DEV_PKG/"
mkdir -p "$pkg_dev/usr/lib/x86_64-linux-gnu"
cd "$pkg_dev/usr/lib/x86_64-linux-gnu"
rm -f libtorrent.so*
ln -s "$LIB_FILENAME" libtorrent.so
dev_size=$(du -s -k "$pkg_dev/usr" | cut -f1)

mkdir -p "$pkg_dev/DEBIAN"
cat > "$pkg_dev/DEBIAN/control" <<EOF
Package: $DEV_PKG
Source: libtorrent ($FULL_VERSION)
Version: $FULL_VERSION
Architecture: $ARCHITECTURE
Maintainer: $MAINTAINER
Installed-Size: $dev_size
Depends: libsigc++-2.0-dev, $RUNTIME_PKG (= $FULL_VERSION)
Section: libdevel
Priority: optional
Multi-Arch: same
Homepage: https://rakshasa.github.io/rtorrent/
Description: C++ BitTorrent library by Rakshasa (development files)
 LibTorrent is a BitTorrent library written in C++ for *nix.
 It is designed to avoid redundant copying and storing of data that other
 clients and libraries suffer from.
 .
 This package contains the files needed to compile and link programs
 which use LibTorrent.
 .
 This package is not official, it is built for MediaEase.
EOF

########################################
# Build the packages (.deb) and move them to the packaging directory
########################################
packaging_dir=$(mktemp -d)
echo "Building packages..."
sudo dpkg-deb --build "$pkg_runtime" "$packaging_dir/${RUNTIME_PKG}-${TAG}_${FULL_VERSION}_${ARCHITECTURE}.deb"
sudo dpkg-deb --build "$pkg_dev" "$packaging_dir/${DEV_PKG}-${TAG}_${FULL_VERSION}_${ARCHITECTURE}.deb"
rm -rf "$pkg_runtime" "$pkg_dev"
