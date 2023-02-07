# syntax=docker/dockerfile:1.2

ARG debugger_base=ubuntu:16.04
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
        texinfo \
        libncurses5-dev \
        pkg-config \
        g++ \
        g++-multilib \
        wget \
        make \
        python-dev \
        manpages-dev \
        ccache \
        coreutils \
        python3-pexpect \
    && \
    apt-get remove -y python3-dev && \
    rm -rf /tmp/*

ARG gdb_version="8.3.1"

RUN wget "http://ftp.gnu.org/gnu/gdb/gdb-${gdb_version}.tar.gz" && \
    tar xzf "gdb-${gdb_version}.tar.gz" && \
    cd "gdb-${gdb_version}" && \
    export CCACHE_DISABLE=1 && \
    ./configure --prefix=${tools_prefix} --with-python --with-curses --enable-tui && \
    make -j${parallelism} && \
    make install && \
    cd .. && \
    rm -rf "gdb-${gdb_version}.tar.gz" "gdb-${gdb_version}"

#--------
# rr

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update && \
    apt-get install -y \
        python3-urllib3 \
        binutils \
    && \
    rm -rf /tmp/*

ARG rr_version="5.6.0"

RUN wget "https://github.com/rr-debugger/rr/releases/download/${rr_version}/rr-${rr_version}-Linux-x86_64.deb" && \
    dpkg -i "rr-${rr_version}-Linux-x86_64.deb" && \
    rm -rf /tmp/*

#--------
# valgrind

ARG valgrind_version="3.15.0"

RUN wget "https://sourceware.org/pub/valgrind/valgrind-${valgrind_version}.tar.bz2" && \
    tar xjf "valgrind-${valgrind_version}.tar.bz2" && \
    cd "valgrind-${valgrind_version}" && \
    export CCACHE_DISABLE=1 && \
    ./configure --prefix=${tools_prefix} && \
    make -j${parallelism} install && \
    cd .. && \
    rm -rf "valgrind-${valgrind_version}.tar.bz2" "valgrind-${valgrind_version}"

#--------
# lldb

ARG lldb_version="12"

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update && \
    apt-get install -y \
        apt-transport-https \
    && \
    wget -qO - https://apt.llvm.org/llvm-snapshot.gpg.key | apt-key add - && \
    echo "deb https://apt.llvm.org/xenial/ llvm-toolchain-xenial-${lldb_version} main" > /etc/apt/sources.list.d/llvm.list && \
    apt-get update && \
    apt-get install -y \
        lldb-${lldb_version} \
    && \
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
    && \
    rm -rf /tmp/*
