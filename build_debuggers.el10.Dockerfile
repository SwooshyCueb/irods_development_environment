# syntax=docker/dockerfile:1.5

ARG debugger_base=rockylinux/rockylinux:10
FROM ${debugger_base}

SHELL [ "/usr/bin/bash", "-c" ]

# Make sure we're starting with an up-to-date image
RUN --mount=type=cache,target=/var/cache/dnf,sharing=locked \
    --mount=type=cache,target=/var/cache/yum,sharing=locked \
    dnf update -y || [ "$?" -eq 100 ] && \
    rm -rf /tmp/*

ARG parallelism=3
ARG tools_prefix=/opt/debug_tools

RUN mkdir -p  ${tools_prefix}

WORKDIR /tmp

#--------
# valgrind

RUN --mount=type=cache,target=/var/cache/dnf,sharing=locked \
    --mount=type=cache,target=/var/cache/yum,sharing=locked \
    dnf install -y valgrind && \
    rm -rf /tmp/*

#--------
# gdb

RUN --mount=type=cache,target=/var/cache/dnf,sharing=locked \
    --mount=type=cache,target=/var/cache/yum,sharing=locked \
    dnf install -y \
        gdb \
        gdb-gdbserver \
    && \
    rm -rf /tmp/*

#--------
# lldb

RUN --mount=type=cache,target=/var/cache/dnf,sharing=locked \
    --mount=type=cache,target=/var/cache/yum,sharing=locked \
    dnf install -y lldb && \
    rm -rf /tmp/*

#--------
# rr

# rr is not currently available in EPEL for EL10.
# The package from github is built for EL8. Due to package dependencies, it can't be installed on EL10.
# It is also no longer available in Fedora, so grabbing a build from Fedora 40 isn't an option.
# No rr for now.

#--------
# xmlrunner

RUN --mount=type=cache,target=/var/cache/dnf,sharing=locked \
    --mount=type=cache,target=/var/cache/yum,sharing=locked \
    dnf install -y \
        python3-pip \
        python3-lxml \
    && \
    rm -rf /tmp/*

RUN --mount=type=cache,target=/root/.cache/pip,sharing=locked \
    --mount=type=cache,target=/root/.cache/wheel,sharing=locked \
    python3 -m pip install \
        unittest-xml-reporting \
    && \
    rm -rf /tmp/*

#--------
# utils

RUN --mount=type=cache,target=/var/cache/dnf,sharing=locked \
    --mount=type=cache,target=/var/cache/yum,sharing=locked \
    dnf install -y \
        sudo \
        nano \
        vim-enhanced \
        lsof \
        which \
        file \
        iproute \
    && \
    rm -rf /tmp/*
