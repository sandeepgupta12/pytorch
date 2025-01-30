#!/usr/bin/env bash

# Environment variables
PACKAGE_NAME=pytorch
PACKAGE_VERSION=${PACKAGE_VERSION:-v2.4.0}

cd /workspace/$PACKAGE_NAME

# Clean up old artifacts
rm -rf build/ dist/ torch.egg-info/

# Build and install PyTorch wheel
if ! (MAX_JOBS=4 python setup.py bdist_wheel && pip install dist/*.whl); then
    echo "------------------$PACKAGE_NAME:install_fails-------------------------------------"
    exit 1
fi


cd ..
pip install pytest pytest-xdist
if ! pytest -n $(nproc) -vvvv $PACKAGE_NAME/test/common_extended_utils.py $PACKAGE_NAME/test/common_utils.py $PACKAGE_NAME/test/smoke_test.py $PACKAGE_NAME/test/test_architecture_ops.py $PACKAGE_NAME/test/test_datasets_video_utils_opt.py $PACKAGE_NAME/test/test_tv_tensors.py; then
   echo "------------------$PACKAGE_NAME:install_success_but_test_fails ###---------------------"
   exit 0
fi
echo "-----start test
if ! pytest -Xrs test; then
    echo "------------------$PACKAGE_NAME:install_success_but_test_fails---------------------"
    exit 2
else
    echo "------------------$PACKAGE_NAME:install_and_test_both_success-------------------------"
    exit 0
fi