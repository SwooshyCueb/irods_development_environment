# syntax=docker/dockerfile:1.2

ARG debugger_base=ubuntu:20.04
FROM ${debugger_base}

SHELL [ "/bin/bash", "-c" ]
ENV DEBIAN_FRONTEND=noninteractive

# Re-enable apt caching for RUN --mount
RUN rm -f /etc/apt/apt.conf.d/docker-clean && \
    echo 'Binary::apt::APT::Keep-Downloaded-Packages "true";' > /etc/apt/apt.conf.d/keep-cache

# Make sure we're starting with an up-to-date image
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update && \
    apt-get upgrade -y && \
    apt-get autoremove -y --purge && \
    rm -rf /tmp/*
# To mark all installed packages as manually installed:
#apt-mark showauto | xargs -r apt-mark manual

ARG parallelism=3
ARG tools_prefix=/opt/debug_tools

RUN mkdir -p  ${tools_prefix}

WORKDIR /tmp

#--------
# gdb

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update && \
    apt-get install -y \
        gdb \
        gdbserver \
    && \
    apt-get remove -y python3-dev && \
    rm -rf /tmp/*

#--------
# rr

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update && \
    apt-get install -y \
        python3-urllib3 \
        binutils \
        wget \
    && \
    rm -rf /tmp/*

ARG rr_version="5.6.0"

RUN wget "https://github.com/rr-debugger/rr/releases/download/${rr_version}/rr-${rr_version}-Linux-x86_64.deb" && \
    dpkg -i "rr-${rr_version}-Linux-x86_64.deb" && \
    rm -rf /tmp/*

#--------
# valgrind

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update && \
    apt-get install -y \
        valgrind \
    && \
    rm -rf /tmp/*

#--------
# lldb

ARG lldb_version="13"

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update && \
    apt-get install -y \
        apt-transport-https \
    && \
    wget -qO- https://apt.llvm.org/llvm-snapshot.gpg.key > /etc/apt/trusted.gpg.d/apt.llvm.org.asc && \
    echo "deb https://apt.llvm.org/focal/ llvm-toolchain-focal-${lldb_version} main" > "/etc/apt/sources.list.d/llvm-toolchain-focal-${lldb_version}.list" && \
    apt-get update && \
    apt-get install -y \
        lldb-${lldb_version} \
    && \
    update-alternatives --install /usr/bin/lldb lldb /usr/bin/lldb-${lldb_version} 1 && \
    hash -r && \
    rm -rf /tmp/*

#--------
# clangd

ARG clangd_version="15"

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    echo "deb https://apt.llvm.org/focal/ llvm-toolchain-focal-${clangd_version} main" > "/etc/apt/sources.list.d/llvm-toolchain-focal-${clangd_version}.list" && \
    apt-get update && \
    apt-get install -y \
        clangd-${clangd_version} \
    && \
    update-alternatives --install /usr/bin/clangd clangd /usr/bin/clangd-${clangd_version} 1 && \
    hash -r && \
    rm -rf /tmp/*

#--------
# utils

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update && \
    apt-get install -y \
        tmux \
        vim \
        nano \
        tig \
        coreutils \
        python3-pexpect \
        lsof \
        sudo \
        wget \
        git \
    && \
    rm -rf /tmp/*

#--------
# other

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    --mount=type=cache,target=/root/.cache/pip,sharing=locked \
    --mount=type=cache,target=/root/.cache/wheel,sharing=locked \
    apt-get update && \
    apt-get install -y \
        apt-transport-https \
        ccache \
        g++-10 \
        gcc \
        gcc-10 \
        git \
        gnupg \
        help2man \
        libbz2-dev \
        libcurl4-gnutls-dev \
        libfuse-dev \
        libjson-perl \
        libkrb5-dev \
        libpam0g-dev \
        libssl-dev \
        libxml2-dev \
        lsb-release \
        make \
        ninja-build \
        odbc-postgresql \
        postgresql \
        python3 \
        python3-dev \
        python3-pip \
        python3-distro \
        python3-jsonschema \
        python3-packaging \
        python3-psutil \
        python3-pyodbc \
        python3-requests \
        rsyslog \
        super \
        unixodbc-dev \
        zlib1g-dev \
    && \
    pip3 install lief && \
    rm -rf /tmp/*

RUN wget -qO - https://packages.irods.org/irods-signing-key.asc | apt-key add - && \
    echo "deb [arch=amd64] https://packages.irods.org/apt/ $(lsb_release -sc) main" | tee /etc/apt/sources.list.d/renci-irods.list && \
    wget -qO - https://core-dev.irods.org/irods-core-dev-signing-key.asc | apt-key add - && \
    echo "deb [arch=amd64] https://core-dev.irods.org/apt/ $(lsb_release -sc) main" | tee /etc/apt/sources.list.d/renci-irods-core-dev.list

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update && \
    apt-get install -y \
        'irods-externals*' \
    && \
    rm -rf /tmp/*

RUN update-alternatives --install /usr/local/bin/gcc gcc /usr/bin/gcc-10 1 && \
    update-alternatives --install /usr/local/bin/g++ g++ /usr/bin/g++-10 1 && \
    hash -r

COPY ICAT.sql /

ARG IRODSUSER_UID=1000
ARG IRODSUSER_GID=1000
RUN groupadd --gid $IRODSUSER_GID \
        --non-unique \
        irodsuser && \
    useradd --uid $IRODSUSER_UID \
        --non-unique \
        --no-user-group \
        --gid irodsuser \
        --groups sys,adm,kmem,sudo,users \
        --create-home \
        --shell /bin/bash \
        irodsuser && \
    echo "irodsuser ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

# These should be overridden in qtcreator
ENV CCACHE_DIR="/var/cache/ccache-irods"
ENV CCACHE_MAXSIZE="64G"

# Allow any uid to use cache
ENV CCACHE_UMASK="000"
# Don't include the current directory when calculating hashes for the cache. This allows re-use of
# the cache across different package versions, at the cost of slightly incorrect paths in
# debugging info.
# https://ccache.dev/manual/4.4.html#_performance
ENV CCACHE_NOHASHDIR="true"
# Allow for a lot of files (1.5M files, 300 per directory)
ENV CCACHE_NLEVELS="3"
# Compression
ENV CCACHE_COMPRESS="true"
ENV CCACHE_COMPRESSLEVEL="2"
