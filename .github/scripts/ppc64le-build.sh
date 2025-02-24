#!/usr/bin/env bash

# Environment variables
PACKAGE_NAME=pytorch

cd /workspace/$PACKAGE_NAME

# Clean up old artifacts
rm -rf build/ dist/ torch.egg-info/

# Set CPU-specific compilation flags
export CMAKE_CXX_FLAGS="-mcpu=power9 -mtune=power9"
export CMAKE_C_FLAGS="-mcpu=power9 -mtune=power9"
export TORCH_CMAKE_ARGS="-DCMAKE_CXX_FLAGS='-mcpu=power9 -mtune=power9' -DCMAKE_C_FLAGS='-mcpu=power9 -mtune=power9'"


# Build and install PyTorch wheel
MAX_JOBS=$(nproc)
python setup.py bdist_wheel 2>&1 | tee build_log.txt

if [ $? -ne 0 ]; then
    echo "❌ Build failed! Check build_log.txt for details."
    exit 1
fi

pip install dist/*.whl

# Run individual tests
declare -a tests=(
    "TestDeviceUtilsCPU.test_device_mode_ops_sparse_mm_reduce_cpu_bfloat16"
    "TestDeviceUtilsCPU.test_device_mode_ops_sparse_mm_reduce_cpu_float16"
    "TestDeviceUtilsCPU.test_device_mode_ops_sparse_mm_reduce_cpu_float32"
    "TestDeviceUtilsCPU.test_device_mode_ops_sparse_mm_reduce_cpu_float64"
)

cd ..
pip install pytest pytest-xdist

if ! pytest "$PACKAGE_NAME/test/test_utils.py"; then
    echo "------------------$PACKAGE_NAME:install_success_but_test_fails---------------------"
    exit 2
    
else
    echo "------------------$PACKAGE_NAME:install_and_test_both_success-------------------------"
    echo "✅ All tests passed successfully!"
    exit 0
fi