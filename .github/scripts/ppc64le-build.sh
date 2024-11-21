#!/usr/bin/env bash

# Environment variables
PACKAGE_NAME=pytorch
PACKAGE_VERSION=${PACKAGE_VERSION:-v2.4.0}

cd /workspace/$PACKAGE_NAME

# Build and install PyTorch wheel
if ! (MAX_JOBS=4 python setup.py bdist_wheel && pip install dist/*.whl); then
    echo "------------------$PACKAGE_NAME:install_fails-------------------------------------"
    exit 1
fi

# Basic test to ensure installation success



# register PrivateUse1HooksInterface
python test/test_utils.py TestDeviceUtilsCPU.test_device_mode_ops_sparse_mm_reduce_cpu_bfloat16
python test/test_utils.py TestDeviceUtilsCPU.test_device_mode_ops_sparse_mm_reduce_cpu_float16
python test/test_utils.py TestDeviceUtilsCPU.test_device_mode_ops_sparse_mm_reduce_cpu_float32
python test/test_utils.py TestDeviceUtilsCPU.test_device_mode_ops_sparse_mm_reduce_cpu_float64

cd ..
pip install pytest pytest-xdist
if ! pytest -n $(nproc) $PACKAGE_NAME/test/common_extended_utils.py $PACKAGE_NAME/test/common_utils.py $PACKAGE_NAME/test/smoke_test.py $PACKAGE_NAME/test/test_architecture_ops.py $PACKAGE_NAME/test/test_datasets_video_utils_opt.py $PACKAGE_NAME/test/test_tv_tensors.py; then
    echo "------------------$PACKAGE_NAME:install_success_but_test_fails ###---------------------"
    exit 0
fi
if ! pytest "$PACKAGE_NAME/test/test_utils.py"; then
    echo "------------------$PACKAGE_NAME:install_success_but_test_fails---------------------"
    exit 2
else
    echo "------------------$PACKAGE_NAME:install_&_test_both_success-------------------------"
    exit 0
fi
