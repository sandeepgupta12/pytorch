#!/bin/bash
# Top-level build script called from Dockerfile
# Script used only in CD pipeline

# Stop at any error, show all commands
set -ex

# openssl version to build, with expected sha256 hash of .tar.gz
# archive
OPENSSL_ROOT=openssl-1.1.1l
OPENSSL_HASH=0b7a3e5e59c34827fe0c3a74b7ec8baef302b98fa80088d7f9153aa16fa76bd1
DEVTOOLS_HASH=a8ebeb4bed624700f727179e6ef771dafe47651131a00a78b342251415646acc
PATCHELF_HASH=d9afdff4baeacfbc64861454f368b7f2c15c44d245293f7587bbf726bfe722fb
CURL_ROOT=curl-7.73.0
CURL_HASH=cf34fe0b07b800f1c01a499a6e8b2af548f6d0e044dca4a29d88a4bee146d131
AUTOCONF_ROOT=autoconf-2.69
AUTOCONF_HASH=954bd69b391edc12d6a4a51a2dd1476543da5c6bbf05a95b59dc0dd6fd4c2969

# Dependencies for compiling Python that we want to remove from
# the final image after compiling Python
PYTHON_COMPILE_DEPS="zlib-devel bzip2-devel ncurses-devel sqlite-devel readline-devel tk-devel gdbm-devel libpcap-devel xz-devel libffi-devel"

if [ "$(uname -m)" != "s390x" ] ; then
    PYTHON_COMPILE_DEPS="${PYTHON_COMPILE_DEPS} db4-devel"
else
    PYTHON_COMPILE_DEPS="${PYTHON_COMPILE_DEPS} libdb-devel"
fi

# Libraries that are allowed as part of the manylinux1 profile
MANYLINUX1_DEPS="glibc-devel libstdc++-devel glib2-devel libX11-devel libXext-devel libXrender-devel  mesa-libGL-devel libICE-devel libSM-devel ncurses-devel"
