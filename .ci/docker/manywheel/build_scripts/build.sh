#!/bin/bash
set -ex

# Install required dependencies
yum -y install bzip2 make git patch unzip bison yasm diffutils \
    automake which file autoconf automake libtool \
    zlib-devel bzip2-devel ncurses-devel sqlite-devel \
    readline-devel tk-devel gdbm-devel libpcap-devel xz-devel \
    libffi-devel openssl-devel
# Get build utilities
MY_DIR=$(dirname "${BASH_SOURCE[0]}")
source $MY_DIR/build_utils.sh

# Install the latest autoconf
AUTOCONF_ROOT=autoconf-2.69
AUTOCONF_HASH=954bd69b391edc12d6a4a51a2dd1476543da5c6bbf05a95b59dc0dd6fd4c2969
build_autoconf "$AUTOCONF_ROOT" "$AUTOCONF_HASH"
autoconf --version

# Build Python
/build_scripts/install_cpython.sh

PY39_BIN=/opt/python/cp39-cp39/bin

# Fix SSL certificate issues
$PY39_BIN/pip install certifi
ln -s "$($PY39_BIN/python -c 'import certifi; print(certifi.where())')" /opt/_internal/certs.pem
export SSL_CERT_FILE=/opt/_internal/certs.pem

# Install latest pypi release of auditwheel
$PY39_BIN/pip install auditwheel

# Cleanup unnecessary packages
yum -y erase wireless-tools gtk2 libX11 hicolor-icon-theme \
    avahi freetype bitstream-vera-fonts \
    zlib-devel bzip2-devel ncurses-devel sqlite-devel \
    readline-devel tk-devel gdbm-devel libpcap-devel xz-devel \
    libffi-devel || true > /dev/null 2>&1
yum -y clean all > /dev/null 2>&1

# Run tests to verify Python installation
for PYTHON in /opt/python/*/bin/python; do
    $PYTHON /build_scripts/manylinux1-check.py
    $PYTHON /build_scripts/ssl-check.py
done
