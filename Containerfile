ARG BASE_IMAGE=localhost/debian-bootc-base
FROM ${BASE_IMAGE}
STOPSIGNAL SIGRTMIN+3

ARG PRODUCT_NAME=""
LABEL org.opencontainers.image.title="${PRODUCT_NAME}"
LABEL org.opencontainers.image.base.name="ghcr.io/daemoncores/debian-bootc:latest"
LABEL org.opencontainers.image.licenses="LGPL-2.1"
LABEL containers.bootc=1
LABEL ostree.bootable=1

ENV DEBIAN_FRONTEND=noninteractive
SHELL ["/bin/bash", "-euo", "pipefail", "-c"]

COPY ./src/overlay /

# 锁定基础镜像自带的 bootupd (0.3.2)，防止升级到有 metadata 缺陷的 0.4.0
RUN apt-mark hold bootupd \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
         fdisk parted dosfstools podman skopeo openssh-server \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

HEALTHCHECK NONE
