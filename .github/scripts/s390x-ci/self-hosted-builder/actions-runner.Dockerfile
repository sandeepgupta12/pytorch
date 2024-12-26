# Self-Hosted IBM Power Github Actions Runner.

# Temporary image: amd64 dependencies.
FROM docker.io/amd64/ubuntu:22.04 AS ld-prefix
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get -y install ca-certificates libicu70 libssl3

# Stage 1: Main image for ppc64le Ubuntu
FROM --platform=linux/ppc64le ubuntu:22.04

# Set non-interactive mode for apt
ENV DEBIAN_FRONTEND=noninteractive

# Fix sources to point to ports.ubuntu.com for ppc64le
RUN echo "deb [arch=ppc64el] http://ports.ubuntu.com/ubuntu-ports jammy main restricted universe multiverse" > /etc/apt/sources.list && \
    echo "deb [arch=ppc64el] http://ports.ubuntu.com/ubuntu-ports jammy-updates main restricted universe multiverse" >> /etc/apt/sources.list && \
    echo "deb [arch=ppc64el] http://ports.ubuntu.com/ubuntu-ports jammy-backports main restricted universe multiverse" >> /etc/apt/sources.list && \
    echo "deb [arch=ppc64el] http://ports.ubuntu.com/ubuntu-ports jammy-security main restricted universe multiverse" >> /etc/apt/sources.list

# Update and install basic tools
RUN apt-get clean && rm -rf /var/lib/apt/lists/* && \
    apt-get update -o Acquire::Retries=5 -o Acquire::http::Timeout="10" && \
    apt-get -y install --no-install-recommends \
    build-essential \
    curl \
    sudo \
    gnupg-agent \
    iptables \
    ca-certificates \
    software-properties-common && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Switch to iptables-legacy
RUN update-alternatives --set iptables /usr/sbin/iptables-legacy && \
    update-alternatives --set ip6tables /usr/sbin/ip6tables-legacy

# Add Docker GPG key and repository
RUN curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg && \
    echo "deb [arch=ppc64el signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" > /etc/apt/sources.list.d/docker.list && \
    apt-get update && apt-get install -y \
    docker-ce \
    docker-ce-cli \
    containerd.io && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Replace apt sources for ppc64el
RUN sed -i 's|http://archive.ubuntu.com/ubuntu|http://ports.ubuntu.com/ubuntu-ports|g' /etc/apt/sources.list && \
    sed -i 's|http://security.ubuntu.com/ubuntu|http://ports.ubuntu.com/ubuntu-ports|g' /etc/apt/sources.list

# Install additional dependencies
RUN apt-get update && apt-get install -y \
    vim \
    python3 \
    python3-dev \
    python3-pip \
    virtualenv && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# amd64 dependencies.
COPY --from=ld-prefix / /usr/x86_64-linux-gnu/
RUN ln -fs ../lib/x86_64-linux-gnu/ld-linux-x86-64.so.2 /usr/x86_64-linux-gnu/lib64/
RUN ln -fs /etc/resolv.conf /usr/x86_64-linux-gnu/etc/
ENV QEMU_LD_PREFIX=/usr/x86_64-linux-gnu

# Set up Python virtual environment
RUN virtualenv --system-site-packages venv

# Copy custom scripts
COPY fs/ /
RUN chmod 777 /usr/bin/actions-runner /usr/bin/entrypoint

# Download and extract GitHub Actions Runner
RUN curl -L https://github.com/actions/runner/releases/download/v2.317.0/actions-runner-linux-x64-2.317.0.tar.gz | tar -xz
