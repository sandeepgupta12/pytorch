#!/usr/bin/env bash

# Environment variables
PACKAGE_NAME=pytorch
PACKAGE_VERSION=${PACKAGE_VERSION:-v2.4.0}

cd /workspace/$PACKAGE_NAME

# Build and install PyTorch wheel
if ! (MAX_JOBS=$(nproc) python setup.py bdist_wheel && pip install dist/*.whl); then
    echo "------------------$PACKAGE_NAME:install_fails-------------------------------------"
    exit 1
fi

# Basic test to ensure installation success
cd ..

pip install pytest
if ! pytest "$PACKAGE_NAME/test/test_utils.py"; then
    echo "------------------$PACKAGE_NAME:install_success_but_test_fails---------------------"
    exit 2
else
    echo "------------------$PACKAGE_NAME:install_&_test_both_success-------------------------"
    exit 0
fi
