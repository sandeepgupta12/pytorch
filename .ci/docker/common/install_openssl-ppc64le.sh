#!/bin/bash
set -e

# Define OpenSSL version
OPENSSL_VERSION="1.1.1k"

# Download and extract OpenSSL
wget https://www.openssl.org/source/openssl-${OPENSSL_VERSION}.tar.gz
tar -xzf openssl-${OPENSSL_VERSION}.tar.gz
cd openssl-${OPENSSL_VERSION}

# Configure OpenSSL (configure with static libraries)
./config no-shared --prefix=/opt/openssl

# Build and install OpenSSL
make -j$(nproc)
make install

# Clean up the build directory
cd ..
rm -rf openssl-${OPENSSL_VERSION} openssl-${OPENSSL_VERSION}.tar.gz

echo "OpenSSL ${OPENSSL_VERSION} installed successfully."
