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

# 1. 预装 install-fs.sh 所需的工具，并确保 bootupd 位于标准 PATH (/usr/local/bin/bootupd)
#    使 install-fs.sh 的 `command -v bootupd` 直接命中，不再触发 apt-get install 升级 bootupd 到有缺陷的 0.4.0
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
         fdisk parted dosfstools podman skopeo openssh-server \
    && BOOTUPD_BIN=$(find /usr -name bootupd -type f -executable 2>/dev/null | head -n1) \
    && if [ -n "$BOOTUPD_BIN" ] && ! command -v bootupd >/dev/null 2>&1; then \
         ln -sf "$BOOTUPD_BIN" /usr/local/bin/bootupd; \
       fi \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

HEALTHCHECK NONE
