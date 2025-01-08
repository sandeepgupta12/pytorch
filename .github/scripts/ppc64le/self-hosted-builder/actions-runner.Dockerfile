# Self-Hosted IBM Power Github Actions Runner.


# Stage 1: Main image for ppc64le Ubuntu
FROM ubuntu:22.04

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
    jq \
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

# Set up Python virtual environment
RUN virtualenv --system-site-packages venv

# Copy custom scripts
COPY fs/ /
RUN chmod 777 /usr/bin/actions-runner /usr/bin/entrypoint


#installing and configuring the runner

ARG RUNNERREPO="https://github.com/actions/runner" RUNNERPATCH

RUN     apt-get -qq update -y && \
        apt-get -qq -y install wget git sudo curl dotnet-sdk-8.0 && \
        apt autoclean

RUN     echo "Using SDK - `dotnet --version`"

ADD     ${RUNNERPATCH} /tmp/runner.patch

RUN     cd /tmp && \
        git clone -q ${RUNNERREPO} && \
        cd runner && \
        git checkout main -b build && \
        git apply /tmp/runner.patch && \
        sed -i'' -e /version/s/8......\"$/${SDK}.0.100\"/ src/global.json


RUN     cd /tmp/runner/src && \
        ./dev.sh layout && \
        ./dev.sh package && \
        ./dev.sh test && \
        rm -rf /root/.dotnet /root/.nuget

RUN     useradd -c "Action Runner" -m runner && \
        usermod -L runner && \
        echo " runner  ALL=(ALL)       NOPASSWD: ALL" >/etc/sudoers.d/runner

RUN     mkdir -p /opt/runner && \
        tar -xf /tmp/runner/_package/*.tar.gz -C /opt/runner && \
        chown -R  runner:runner /opt/runner && \
        su -c "/opt/runner/config.sh --version" runner

RUN     apt-get -qq -y install cmake make automake autoconf m4 gcc-12-base libtool

RUN     rm -rf /tmp/runner /tmp/runner.patch

USER    runner

ENTRYPOINT ["/usr/bin/entrypoint"]
CMD ["/usr/bin/actions-runner"]

