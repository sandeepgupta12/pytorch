# Self-Hosted IBM Power Github Actions Runner
FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

# Correct ports for ppc64le (jammy)
RUN echo "deb [arch=ppc64el] http://ports.ubuntu.com/ubuntu-ports jammy main restricted universe multiverse" > /etc/apt/sources.list && \
    echo "deb [arch=ppc64el] http://ports.ubuntu.com/ubuntu-ports jammy-updates main restricted universe multiverse" >> /etc/apt/sources.list && \
    echo "deb [arch=ppc64el] http://ports.ubuntu.com/ubuntu-ports jammy-backports main restricted universe multiverse" >> /etc/apt/sources.list && \
    echo "deb [arch=ppc64el] http://ports.ubuntu.com/ubuntu-ports jammy-security main restricted universe multiverse" >> /etc/apt/sources.list

# Base dependencies (NO sudo)
RUN apt-get update -o Acquire::Retries=5 -o Acquire::http::Timeout="10" && \
    apt-get install -y --no-install-recommends \
        build-essential \
        curl \
        jq \
        gnupg-agent \
        iptables \
        ca-certificates \
        software-properties-common \
        vim \
        zip \
        python3 \
        python3-pip \
        wget \
        git \
        cmake \
        make \
        automake \
        autoconf \
        m4 \
        libtool \
        dotnet-sdk-8.0 && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Switch to iptables-legacy
RUN update-alternatives --set iptables /usr/sbin/iptables-legacy && \
    update-alternatives --set ip6tables /usr/sbin/ip6tables-legacy

# Install Podman + Docker compatibility
RUN apt-get update && \
    apt-get install -y podman podman-docker && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Create runner user (NO sudo, NO privilege escalation)
RUN useradd -c "Action Runner" -m runner && \
    groupadd podman || true && \
    usermod -aG podman runner

# Podman config
RUN mkdir -p /etc/containers && \
    echo "[engine]\ncgroup_manager = \"cgroupfs\"" > /etc/containers/containers.conf

# GitHub Actions runner build
ARG RUNNERREPO="https://github.com/actions/runner"
ARG RUNNERPATCH

ADD ${RUNNERPATCH} /tmp/runner.patch

RUN git clone -q ${RUNNERREPO} /tmp/runner && \
    cd /tmp/runner && \
    git checkout main -b build && \
    git apply /tmp/runner.patch

RUN cd /tmp/runner/src && \
    ./dev.sh layout && \
    ./dev.sh package && \
    ./dev.sh test && \
    rm -rf /root/.dotnet /root/.nuget

RUN mkdir -p /opt/runner && \
    tar -xf /tmp/runner/_package/*.tar.gz -C /opt/runner && \
    chown -R runner:runner /opt/runner

RUN rm -rf /tmp/runner /tmp/runner.patch

# Custom scripts
COPY fs/ /
RUN chmod +x /usr/bin/actions-runner /usr/bin/entrypoint

USER runner
WORKDIR /opt/runner

COPY --chown=runner:runner manywheel-ppc64le.tar /opt/runner/manywheel-ppc64le.tar

ENTRYPOINT ["/usr/bin/entrypoint"]
CMD ["/usr/bin/actions-runner"]
