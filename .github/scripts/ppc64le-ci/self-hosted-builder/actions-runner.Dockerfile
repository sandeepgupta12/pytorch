# Self-Hosted IBM Power Github Actions Runner.
FROM ubuntu:22.04

# Set non-interactive mode for apt
ENV DEBIAN_FRONTEND=noninteractive

# Fix sources to point to ports.ubuntu.com for ppc64le
RUN echo "deb [arch=ppc64el] http://ports.ubuntu.com/ubuntu-ports jammy main restricted universe multiverse" > /etc/apt/sources.list && \
    echo "deb [arch=ppc64el] http://ports.ubuntu.com/ubuntu-ports jammy-updates main restricted universe multiverse" >> /etc/apt/sources.list && \
    echo "deb [arch=ppc64el] http://ports.ubuntu.com/ubuntu-ports jammy-backports main restricted universe multiverse" >> /etc/apt/sources.list && \
    echo "deb [arch=ppc64el] http://ports.ubuntu.com/ubuntu-ports jammy-security main restricted universe multiverse" >> /etc/apt/sources.list

# Fix sources for ppc64le and update system
RUN apt-get update -o Acquire::Retries=5 -o Acquire::http::Timeout="10" && \
    apt-get -y install --no-install-recommends \
    build-essential \
    curl \
    sudo \
    jq \
    gnupg-agent \
    iptables \
    ca-certificates \
    software-properties-common \
    vim \
    zip \
    python3 \
    python3-pip && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Switch to iptables-legacy
RUN update-alternatives --set iptables /usr/sbin/iptables-legacy && \
    update-alternatives --set ip6tables /usr/sbin/ip6tables-legacy


# Install Podman and podman-docker (Docker compatibility)
RUN apt-get update && apt-get install -y podman podman-docker && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Install dotnet SDK and other dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    wget \
    git \
    dotnet-sdk-8.0 \
    cmake \
    make \
    automake \
    autoconf \
    m4 \
    libtool && \
    apt-get clean && rm -rf /var/lib/apt/lists/*


# Setup user and permissions
RUN useradd -c "Action Runner" -m runner && \
    usermod -L runner && \
    echo "runner ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/runner && \
    groupadd podman || true && \
    usermod -aG podman runner

# Configure Podman cgroup manager
RUN mkdir -p /etc/containers && \
    echo "[engine]\ncgroup_manager = \"cgroupfs\"" | sudo tee /etc/containers/containers.conf

# Add and configure GitHub Actions runner
ARG RUNNERREPO="https://github.com/actions/runner"
ARG RUNNERPATCH

ADD ${RUNNERPATCH} /tmp/runner.patch

RUN git clone -q ${RUNNERREPO} /tmp/runner && \
    cd /tmp/runner && \
    git checkout main -b build && \
    git apply /tmp/runner.patch && \
    sed -i'' -e /version/s/8......\"$/${SDK}.0.100\"/ src/global.json 

RUN  cd /tmp/runner/src && \
    ./dev.sh layout && \
    ./dev.sh package && \
    ./dev.sh test && \
    rm -rf /root/.dotnet /root/.nuget

RUN mkdir -p /opt/runner && \
    tar -xf /tmp/runner/_package/*.tar.gz -C /opt/runner && \
    chown -R  runner:runner /opt/runner && \
    su - runner -c "/opt/runner/config.sh --version"

RUN rm -rf /tmp/runner /tmp/runner.patch

# Copy custom scripts and set permissions
COPY fs/ /
RUN chmod +x /usr/bin/actions-runner /usr/bin/entrypoint

# Switch to the runner user
USER runner

# Set working directory
WORKDIR /opt/runner

COPY --chown=runner:runner manywheel-ppc64le.tar /opt/runner/manywheel-ppc64le.tar

# Define entry point and command
ENTRYPOINT ["/usr/bin/entrypoint"]
CMD ["/usr/bin/actions-runner"]

