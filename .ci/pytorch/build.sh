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




if [[ "$BUILD_ENVIRONMENT" == *-bazel-* ]]; then
  set -e -o pipefail

  get_bazel

  # Leave 1 CPU free and use only up to 80% of memory to reduce the change of crashing
  # the runner
  BAZEL_MEM_LIMIT="--local_ram_resources=HOST_RAM*.8"
  BAZEL_CPU_LIMIT="--local_cpu_resources=HOST_CPUS-1"

  if [[ "$CUDA_VERSION" == "cpu" ]]; then
    # Build torch, the Python module, and tests for CPU-only
    tools/bazel build --config=no-tty "${BAZEL_MEM_LIMIT}" "${BAZEL_CPU_LIMIT}" --config=cpu-only :torch :torch/_C.so :all_tests
  else
    tools/bazel build --config=no-tty "${BAZEL_MEM_LIMIT}" "${BAZEL_CPU_LIMIT}" //...
  fi
else
  # check that setup.py would fail with bad arguments
  echo "The next three invocations are expected to fail with invalid command error messages."
  ( ! get_exit_code python setup.py bad_argument )
  ( ! get_exit_code python setup.py clean] )
  ( ! get_exit_code python setup.py clean bad_argument )

  if [[ "$BUILD_ENVIRONMENT" != *libtorch* ]]; then
    # rocm builds fail when WERROR=1
    # XLA test build fails when WERROR=1
    # set only when building other architectures
    # or building non-XLA tests.
    if [[ "$BUILD_ENVIRONMENT" != *rocm*  &&
          "$BUILD_ENVIRONMENT" != *xla* ]]; then
      if [[ "$BUILD_ENVIRONMENT" != *py3.8* ]]; then
        # Install numpy-2.0.2 for builds which are backward compatible with 1.X
        python -mpip install numpy==2.0.2
      fi

      WERROR=1 python setup.py clean

      if [[ "$USE_SPLIT_BUILD" == "true" ]]; then
        python3 tools/packaging/split_wheel.py bdist_wheel
      else
        echo "build wheel"
        python setup.py bdist_wheel
      fi
    
    fi
 
  else
    # Test no-Python build
    echo "Building libtorch"

    # This is an attempt to mitigate flaky libtorch build OOM error. By default, the build parallelization
    # is set to be the number of CPU minus 2. So, let's try a more conservative value here. A 4xlarge has
    # 16 CPUs
    if [ -z "$MAX_JOBS_OVERRIDE" ]; then
      MAX_JOBS=$(nproc --ignore=4)
      export MAX_JOBS
    fi

    # NB: Install outside of source directory (at the same level as the root
    # pytorch folder) so that it doesn't get cleaned away prior to docker push.
    BUILD_LIBTORCH_PY=$PWD/tools/build_libtorch.py
    mkdir -p ../cpp-build/caffe2
    pushd ../cpp-build/caffe2
    WERROR=1 VERBOSE=1 DEBUG=1 python "$BUILD_LIBTORCH_PY"
    popd
  fi
fi

