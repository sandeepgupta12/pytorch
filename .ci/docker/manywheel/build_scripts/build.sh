#!/bin/bash
# Top-level build script called from Dockerfile
# Script used only in CD pipeline

# Stop at any error, show all commands
set -ex

# openssl version to build, with expected sha256 hash of .tar.gz archive
OPENSSL_ROOT=openssl-1.1.1l
OPENSSL_HASH=0b7a3e5e59c34827fe0c3a74b7ec8baef302b98fa80088d7f9153aa16fa76bd1
DEVTOOLS_HASH=a8ebeb4bed624700f727179e6ef771dafe47651131a00a78b342251415646acc
PATCHELF_HASH=d9afdff4baeacfbc64861454f368b7f2c15c44d245293f7587bbf726bfe722fb
CURL_ROOT=curl-7.73.0
CURL_HASH=cf34fe0b07b800f1c01a499a6e8b2af548f6d0e044dca4a29d88a4bee146d131
AUTOCONF_ROOT=autoconf-2.69
AUTOCONF_HASH=954bd69b391edc12d6a4a51a2dd1476543da5c6bbf05a95b59dc0dd6fd4c2969

# Dependencies for compiling Python that we want to remove from final image
PYTHON_COMPILE_DEPS="zlib-devel bzip2-devel ncurses-devel sqlite-devel readline-devel tk-devel gdbm-devel libpcap-devel xz-devel libffi-devel"

if [ "$(uname -m)" != "s390x" ] && [ "$(uname -m)" != "ppc64le" ]; then
    PYTHON_COMPILE_DEPS="${PYTHON_COMPILE_DEPS} db4-devel"
else
    PYTHON_COMPILE_DEPS="${PYTHON_COMPILE_DEPS} libdb-devel"
fi

# Libraries allowed in the manylinux1 profile
MANYLINUX1_DEPS="glibc-devel libstdc++-devel glib2-devel libX11-devel libXext-devel libXrender-devel mesa-libGL-devel libICE-devel libSM-devel ncurses-devel"

# Get build utilities
MY_DIR=$(dirname "${BASH_SOURCE[0]}")
source "$MY_DIR/build_utils.sh"

# Install required dependencies
yum -y install bzip2 make git patch unzip bison yasm diffutils \
    automake which file autoconf automake libtool \
    ${PYTHON_COMPILE_DEPS}

# Install newest autoconf
build_autoconf "$AUTOCONF_ROOT" "$AUTOCONF_HASH"
autoconf --version

# Update config.guess and config.sub before running configure
mkdir -p build-aux
wget -O build-aux/config.guess https://git.savannah.gnu.org/cgit/config.git/plain/config.guess || { echo "Failed to download config.guess"; exit 1; }
wget -O build-aux/config.sub https://git.savannah.gnu.org/cgit/config.git/plain/config.sub || { echo "Failed to download config.sub"; exit 1; }
chmod +x build-aux/config.guess build-aux/config.sub

# Regenerate configure scripts
autoreconf -fi

# Build OpenSSL
build_openssl "$OPENSSL_ROOT" "$OPENSSL_HASH"

/build_scripts/install_cpython.sh

PY39_BIN=/opt/python/cp39-cp39/bin

# Fix SSL certificate issues
$PY39_BIN/pip install certifi
ln -s "$($PY39_BIN/python -c 'import certifi; print(certifi.where())')" \
      /opt/_internal/certs.pem
export SSL_CERT_FILE=/opt/_internal/certs.pem

# Install and clean up Curl
build_curl "$CURL_ROOT" "$CURL_HASH"
rm -rf /usr/local/include/curl /usr/local/lib/libcurl* /usr/local/lib/pkgconfig/libcurl.pc
hash -r
curl --version
curl-config --features

# Install patchelf
curl -sLOk https://nixos.org/releases/patchelf/patchelf-0.10/patchelf-0.10.tar.gz
tar -xzf patchelf-0.10.tar.gz
(cd patchelf-0.10 && ./configure --build=powerpc64le-unknown-linux-gnu && make && make install)
rm -rf patchelf-0.10.tar.gz patchelf-0.10

# Install latest pypi release of auditwheel
$PY39_BIN/pip install auditwheel
ln -s "$PY39_BIN/auditwheel" /usr/local/bin/auditwheel

# Cleanup unnecessary packages
yum -y erase wireless-tools gtk2 libX11 hicolor-icon-theme \
    avahi freetype bitstream-vera-fonts \
    ${PYTHON_COMPILE_DEPS} || true > /dev/null 2>&1
yum -y install ${MANYLINUX1_DEPS}
yum -y clean all > /dev/null 2>&1
yum list installed

# Remove unnecessary files
find /opt/_internal -name '*.a' -print0 | xargs -0 rm -f
find /opt/_internal -type f -print0 | xargs -0 -n1 strip --strip-unneeded 2>/dev/null || true
find /opt/_internal \
     \( -type d -a -name test -o -name tests \) \
  -o \( -type f -a -name '*.pyc' -o -name '*.pyo' \) \
  -print0 | xargs -0 rm -f

# Run tests to verify Python installation
for PYTHON in /opt/python/*/bin/python; do
    $PYTHON "$MY_DIR/manylinux1-check.py"
    $PYTHON "$MY_DIR/ssl-check.py"
done

# Fix libc headers to remain compatible with C99 compilers
find /usr/include/ -type f -exec sed -i 's/\bextern _*inline_*\b/extern __inline __attribute__ ((__gnu_inline__))/g' {} +

# Remove OpenSSL build artifacts
rm -rf /usr/local/ssl
