# syntax=docker/dockerfile:1.5

ARG debugger_base=debian:13
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

ARG rr_version="5.9.0"

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update && \
    wget "https://github.com/rr-debugger/rr/releases/download/${rr_version}/rr-${rr_version}-Linux-x86_64.deb" && \
    apt-get install -y "./rr-${rr_version}-Linux-x86_64.deb" && \
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

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update && \
    apt-get install -y \
        lldb \
    && \
    rm -rf /tmp/*

#--------
# xmlrunner

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update && \
    apt-get install -y \
        python3-xmlrunner \
    && \
    rm -rf /tmp/*

#--------
# utils

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update && \
    apt-get install -y \
        vim \
        nano \
        tig \
        coreutils \
        python3-pexpect \
        iproute2 \
        file \
        psmisc \
        procps \
        less \
    && \
    rm -rf /tmp/*

# Debian does not include glibc-tools (needed for catchsegv)
# Let's grab it from Ubuntu instead.

ARG glibctools_version="0.0~git3.23fd2b9-0ubuntu1"

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update && \
    wget "http://archive.ubuntu.com/ubuntu/pool/universe/g/glibc-tools/glibc-tools_${glibctools_version}_amd64.deb" && \
    apt-get install -y "./glibc-tools_${glibctools_version}_amd64.deb" && \
    rm -rf /tmp/*

