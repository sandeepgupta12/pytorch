# Stage 1: Temporary image for amd64 dependencies
#FROM docker.io/amd64/ubuntu:22.04 AS ld-prefix
#ENV DEBIAN_FRONTEND=noninteractive

# Install amd64-specific dependencies
#RUN apt-get update -o Acquire::Retries=3 && apt-get install -y \
 #   ca-certificates \
 #   libicu70 \
  #  libssl3 && \
   # apt-get clean && rm -rf /var/lib/apt/lists/*

# Stage 2: Main image for ppc64le Ubuntu
FROM --platform=linux/ppc64le ubuntu:22.04

# Set non-interactive mode for apt
ENV DEBIAN_FRONTEND=noninteractive

# Fix sources to point to ports.ubuntu.com for ppc64le
RUN echo "deb [arch=ppc64el] http://ports.ubuntu.com/ubuntu-ports jammy main restricted universe multiverse" > /etc/apt/sources.list && \
    echo "deb [arch=ppc64el] http://ports.ubuntu.com/ubuntu-ports jammy-updates main restricted universe multiverse" >> /etc/apt/sources.list && \
    echo "deb [arch=ppc64el] http://ports.ubuntu.com/ubuntu-ports jammy-backports main restricted universe multiverse" >> /etc/apt/sources.list && \
    echo "deb [arch=ppc64el] http://ports.ubuntu.com/ubuntu-ports jammy-security main restricted universe multiverse" >> /etc/apt/sources.list

# Update and clean apt
RUN apt-get clean && rm -rf /var/lib/apt/lists/* && \
    apt-get update -o Acquire::Retries=5 -o Acquire::http::Timeout="10"

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
    ca-certificates && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Replace apt sources for ppc64el
RUN sed -i 's|http://archive.ubuntu.com/ubuntu|http://ports.ubuntu.com/ubuntu-ports|g' /etc/apt/sources.list && \
    sed -i 's|http://security.ubuntu.com/ubuntu|http://ports.ubuntu.com/ubuntu-ports|g' /etc/apt/sources.list

# Install additional dependencies
RUN apt-get update && apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg-agent \
    software-properties-common && \
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add - && \
    echo "deb [arch=ppc64el] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" > /etc/apt/sources.list.d/docker.list && \
    apt-get update && apt-get install -y \
    docker-ce \
    docker-ce-cli \
    containerd.io && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Copy amd64 dependencies from the ld-prefix stage
#COPY --from=ld-prefix / /usr/x86_64-linux-gnu/
#RUN ln -fs ../lib/x86_64-linux-gnu/ld-linux-x86-64.so.2 /usr/x86_64-linux-gnu/lib64/
#RUN ln -fs /etc/resolv.conf /usr/x86_64-linux-gnu/etc/
#ENV QEMU_LD_PREFIX=/usr/x86_64-linux-gnu

# Copy custom scripts
COPY fs/ /
RUN chmod +x /usr/bin/actions-runner /usr/bin/entrypoint

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

