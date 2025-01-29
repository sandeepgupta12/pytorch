#!/usr/bin/env bash

# Environment variables
PACKAGE_NAME=pytorch
PACKAGE_VERSION=${PACKAGE_VERSION:-v2.4.0}
export PYTORCH_BUILD_VERSION=2.6.0

cd /workspace/$PACKAGE_NAME

# Build and install PyTorch wheel
if ! (MAX_JOBS=4 python setup.py bdist_wheel); then
    echo "------------------$PACKAGE_NAME:install_fails-------------------------------------"
    exit 1
fi

# List all the wheels in the dist directory
echo "Listing all generated wheel files:"
ls dist/*.whl

# Get the single wheel file to install (you can adjust this to get only one wheel if multiple are generated)
WHEEL_FILE=$(ls dist/*.whl | head -n 1)

# Ensure that only one wheel file is present, exit if there are multiple wheels
WHEEL_COUNT=$(ls dist/*.whl | wc -l)
if [ "$WHEEL_COUNT" -gt 1 ]; then
    echo "------------------$PACKAGE_NAME:multiple_wheels_detected-------------------------"
    exit 1
fi

# Install the generated wheel
if ! pip install "$WHEEL_FILE" --force-reinstall; then
    echo "------------------$PACKAGE_NAME:install_fails--------------------------------------"
    exit 1
fi
# Basic test to ensure installation success



# register PrivateUse1HooksInterface
#python test/test_utils.py TestDeviceUtilsCPU.test_device_mode_ops_sparse_mm_reduce_cpu_bfloat16
#python test/test_utils.py TestDeviceUtilsCPU.test_device_mode_ops_sparse_mm_reduce_cpu_float16
#python test/test_utils.py TestDeviceUtilsCPU.test_device_mode_ops_sparse_mm_reduce_cpu_float32
#python test/test_utils.py TestDeviceUtilsCPU.test_device_mode_ops_sparse_mm_reduce_cpu_float64

cd ..
pip install pytest pytest-xdist
#if ! pytest -n $(nproc) -vvvv $PACKAGE_NAME/test/common_extended_utils.py $PACKAGE_NAME/test/common_utils.py $PACKAGE_NAME/test/smoke_test.py $PACKAGE_NAME/test/test_architecture_ops.py $PACKAGE_NAME/test/test_datasets_video_utils_opt.py $PACKAGE_NAME/test/test_tv_tensors.py; then
#    echo "------------------$PACKAGE_NAME:install_success_but_test_fails ###---------------------"
#    exit 0
#fi
echo "-----start test
if ! pytest "$PACKAGE_NAME/test/test_utils.py"; then
    echo "------------------$PACKAGE_NAME:install_success_but_test_fails---------------------"
    exit 2
else
    echo "------------------$PACKAGE_NAME:install_&_test_both_success-------------------------"
    exit 0
fi