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

# 1. 预装 install-fs.sh 所需的工具及 dracut 驱动打包工具，确保 bootupd 位于标准 PATH
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
         btop \
         dosfstools \
         dracut-core \
         dracut-network \
         fdisk \
         fastfetch \
         htop \
         iotop \
         iputils-ping \
         jq \
         ncdu \
         net-tools \
         openssh-server \
         open-vm-tools \
         parted \
         podman \
         rsync \
         skopeo \
         tmux \
         tree \
         vim \
    && BOOTUPD_BIN=$(find /usr -name bootupd -type f -executable 2>/dev/null | head -n1) \
    && if [ -n "$BOOTUPD_BIN" ] && ! command -v bootupd >/dev/null 2>&1; then \
         ln -sf "$BOOTUPD_BIN" /usr/local/bin/bootupd; \
       fi \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

HEALTHCHECK NONE

# 2. 强制关闭 hostonly 模式，确保 XFS 文件系统及 VMware/NVMe/VirtIO 块设备驱动打入 initramfs
RUN mkdir -p /etc/dracut.conf.d \
    && printf 'hostonly="no"\nadd_drivers+=" xfs ext4 btrfs mptspi mptsas vmw_pvscsi nvme ahci virtio_blk virtio_pci sd_mod "\n' > /etc/dracut.conf.d/99-universal-boot.conf \
    && KVER=$(ls -1 /usr/lib/modules | head -n 1) \
    && test -n "$KVER" \
    && dracut --force --no-hostonly --add "ostree" --kver "$KVER" "/usr/lib/modules/$KVER/initramfs.img" \
    && rm -rf /boot/* /var/tmp/* \
    && bootc container lint
