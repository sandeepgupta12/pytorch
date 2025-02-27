#!/bin/bash

set -ex -o pipefail

# Required environment variable: $BUILD_ENVIRONMENT
# (This is set by default in the Docker images we build, so you don't
# need to set it yourself.

# shellcheck source=./common.sh
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
# shellcheck source=./common-build.sh
source "$(dirname "${BASH_SOURCE[0]}")/common-build.sh"

if [[ "$BUILD_ENVIRONMENT" == *-mobile-*build* ]]; then
  exec "$(dirname "${BASH_SOURCE[0]}")/build-mobile.sh" "$@"
fi

echo "Python version:"
python --version

echo "GCC version:"
gcc --version

echo "CMake version:"
cmake --version

echo "Environment variables:"
env







# Enable LLVM dependency for TensorExpr testing
export USE_LLVM=/opt/llvm
export LLVM_DIR=/opt/llvm/lib/cmake/llvm



if ! which conda; then
  # In ROCm CIs, we are doing cross compilation on build machines with
  # intel cpu and later run tests on machines with amd cpu.
  # Also leave out two builds to make sure non-mkldnn builds still work.
  if [[ "$BUILD_ENVIRONMENT" != *rocm* ]]; then
    export USE_MKLDNN=1
  else
    export USE_MKLDNN=0
  fi
else
  # CMAKE_PREFIX_PATH precedences
  # 1. $CONDA_PREFIX, if defined. This follows the pytorch official build instructions.
  # 2. /opt/conda/envs/py_${ANACONDA_PYTHON_VERSION}, if ANACONDA_PYTHON_VERSION defined.
  #    This is for CI, which defines ANACONDA_PYTHON_VERSION but not CONDA_PREFIX.
  # 3. $(conda info --base). The fallback value of pytorch official build
  #    instructions actually refers to this.
  #    Commonly this is /opt/conda/
  if [[ -v CONDA_PREFIX ]]; then
    export CMAKE_PREFIX_PATH=${CONDA_PREFIX}
  elif [[ -v ANACONDA_PYTHON_VERSION ]]; then
    export CMAKE_PREFIX_PATH="/opt/conda/envs/py_${ANACONDA_PYTHON_VERSION}"
  else
    # already checked by `! which conda`
    CMAKE_PREFIX_PATH="$(conda info --base)"
    export CMAKE_PREFIX_PATH
  fi

  # Workaround required for MKL library linkage
  # https://github.com/pytorch/pytorch/issues/119557
  if [[ "$ANACONDA_PYTHON_VERSION" = "3.12" || "$ANACONDA_PYTHON_VERSION" = "3.13" ]]; then
    export CMAKE_LIBRARY_PATH="/opt/conda/envs/py_$ANACONDA_PYTHON_VERSION/lib/"
    export CMAKE_INCLUDE_PATH="/opt/conda/envs/py_$ANACONDA_PYTHON_VERSION/include/"
  fi
fi




if [[ "${BUILD_ENVIRONMENT}" != *android* && "${BUILD_ENVIRONMENT}" != *cuda* ]]; then
  export BUILD_STATIC_RUNTIME_BENCHMARK=ON
fi

if [[ "$BUILD_ENVIRONMENT" == *-debug* ]]; then
  export CMAKE_BUILD_TYPE=RelWithAssert
fi



