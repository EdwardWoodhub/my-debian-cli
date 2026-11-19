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

# 预装 install-fs.sh 所需的工具，并修复容器环境下 grub-efi-amd64-signed postinst 报错
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
         fdisk parted dosfstools podman skopeo openssh-server \
    && (apt-get install -y --no-install-recommends bootupd || { \
         sed -i 's/^set -e/set -e\nexit 0/' /var/lib/dpkg/info/grub-efi-amd64-signed.postinst 2>/dev/null || true; \
         sed -i 's/^set -e/set -e\nexit 0/' /var/lib/dpkg/info/shim-signed.postinst 2>/dev/null || true; \
         dpkg --configure -a; \
       }) \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

HEALTHCHECK NONE
