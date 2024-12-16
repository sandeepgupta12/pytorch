# Stage 1: Temporary image for amd64 dependencies
FROM docker.io/amd64/ubuntu:22.04 as ld-prefix
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get -y install \
    ca-certificates \
    libicu70 \
    libssl3

# Main image: ppc64le Ubuntu
FROM --platform=linux/ppc64le ubuntu:22.04

# Set non-interactive mode for apt
ENV DEBIAN_FRONTEND=noninteractive

# Install dependencies for building and testing PyTorch
RUN apt-get update && apt-get -y install --no-install-recommends \
    build-essential \
    cmake \
    curl \
    gcc \
    git \
    jq \
    zip \
    libxml2-dev \
    libxslt-dev \
    ninja-build \
    python-is-python3 \
    python3 \
    python3-dev \
    python3-pip \
    pybind11-dev \
    python3-numpy \
    libopenblas-dev \
    liblapack-dev \
    libgloo-dev \
    python3-yaml \
    python3-scipy \
    virtualenv \
    wget \
    ca-certificates \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Copy amd64 dependencies from the ld-prefix stage
COPY --from=ld-prefix / /usr/x86_64-linux-gnu/
RUN ln -fs ../lib/x86_64-linux-gnu/ld-linux-x86-64.so.2 /usr/x86_64-linux-gnu/lib64/
RUN ln -fs /etc/resolv.conf /usr/x86_64-linux-gnu/etc/
ENV QEMU_LD_PREFIX=/usr/x86_64-linux-gnu

# Copy custom scripts
COPY fs/ /
RUN chmod +x /usr/bin/actions-runner /usr/bin/entrypoint

# Install Go (v1.21.1) for ppc64le
RUN curl -LO https://golang.org/dl/go1.21.1.linux-ppc64le.tar.gz && \
echo "eddf018206f8a5589bda75252b72716d26611efebabdca5d0083ec15e9e41ab7  go1.21.1.linux-ppc64le.tar.gz" | sha256sum -c - && \
    tar --strip-components=1 -C /usr/local -xzf go1.21.1.linux-ppc64le.tar.gz && \
    rm go1.21.1.linux-ppc64le.tar.gz && \
    ls -l /usr/local && \
    ls -l /usr/local/go && \
    ls -l /usr/local/go/bin && \
    /usr/local/go/bin/go version && \
    ln -s /usr/local/go/bin/go /usr/bin/go
ENV PATH="/usr/local/go/bin:${PATH}"
RUN go version

# Install Podman (v4.6.0) for container management
RUN apt-get update && apt-get install -y \
    make \
    gcc \
    libseccomp-dev \
    libapparmor-dev \
    && apt-get clean && rm -rf /var/lib/apt/lists/*
RUN git clone https://github.com/containers/podman.git && \
    cd podman && \
    git checkout v4.6.0 && \
    make BUILDTAGS="seccomp apparmor" && \
    make install && \
    cd .. && rm -rf podman

# Configure GitHub Actions Runner for amd64
RUN useradd -m actions-runner
USER actions-runner
WORKDIR /home/actions-runner

# Set up Python virtual environment
RUN virtualenv --system-site-packages venv

# Copy prebuilt manywheel docker image for builds and tests
COPY --chown=actions-runner:actions-runner manywheel-ppc64le.tar /home/actions-runner/manywheel-ppc64le.tar

# Download and extract GitHub Actions Runner
RUN curl -L https://github.com/actions/runner/releases/download/v2.317.0/actions-runner-linux-x64-2.317.0.tar.gz | tar -xz

# Entry point and default command
ENTRYPOINT ["/usr/bin/entrypoint"]
CMD ["/usr/bin/actions-runner"]
