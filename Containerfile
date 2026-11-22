ARG BASE_IMAGE=localhost/debian-bootc-base
FROM ${BASE_IMAGE}
STOPSIGNAL SIGRTMIN+3

ARG PRODUCT_NAME=""
LABEL org.opencontainers.image.title="${PRODUCT_NAME}"
LABEL org.opencontainers.image.base.name="ghcr.io/edwardwoodhub/my-debian-bootc:latest"
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
    && find /boot /var/tmp -mindepth 1 -delete

# 3. 修复 Legacy BIOS 模式下 bootc/ostree 独立 /boot 分区 GRUB 前缀与模块缺失问题
RUN printf '%s\n' \
      '#!/usr/bin/env bash' \
      'set -euo pipefail' \
      '' \
      '[ -d /sys/firmware/efi ] && exit 0' \
      'findmnt -rn /boot >/dev/null || exit 0' \
      '' \
      'BOOT_DEV=$(findmnt -no SOURCE /boot)' \
      'BOOT_DISK=$(lsblk -no PKNAME "$BOOT_DEV" | head -n1)' \
      'BOOT_UUID=$(findmnt -no UUID /boot)' \
      'GRUB_PC_DIR=$(find /usr/lib/grub -maxdepth 2 -type d -name "i386-pc" | head -n1)' \
      '' \
      '[ -z "$BOOT_DISK" ] || [ -z "$BOOT_UUID" ] || [ -z "$GRUB_PC_DIR" ] && exit 0' \
      '' \
      'TMP_DIR=$(mktemp -d /boot/.grub-fix.XXXXXX)' \
      'trap '\''rm -rf "$TMP_DIR"'\'' EXIT' \
      '' \
      'printf "search --no-floppy --fs-uuid --set=root %s\nset prefix=(\$root)/grub2\n" "$BOOT_UUID" > "$TMP_DIR/early.cfg"' \
      '' \
      'grub2-mkimage -O i386-pc -d "$GRUB_PC_DIR" -p /grub2 -c "$TMP_DIR/early.cfg" -o "$TMP_DIR/core.img" biosdisk part_gpt part_msdos ext2 xfs fat search search_fs_uuid normal configfile blscfg loadenv test regexp gzio linux echo boot password_pbkdf2 gettext gfxterm terminfo' \
      'cp "$GRUB_PC_DIR/boot.img" "$TMP_DIR/boot.img"' \
      'grub2-bios-setup -d "$TMP_DIR" -b boot.img -c core.img "/dev/$BOOT_DISK"' \
      > /usr/local/sbin/fix-bios-grub.sh \
    && chmod 0755 /usr/local/sbin/fix-bios-grub.sh \
    && printf '%s\n' \
      '[Unit]' \
      'Description=Ensure BIOS GRUB core.img matches /boot UUID and BLS modules' \
      'ConditionPathExists=!/sys/firmware/efi' \
      'After=local-fs.target boot.mount' \
      'Before=ostree-finalize-staged.service' \
      '' \
      '[Service]' \
      'Type=oneshot' \
      'ExecStart=/usr/local/sbin/fix-bios-grub.sh' \
      'RemainAfterExit=yes' \
      '' \
      '[Install]' \
      'WantedBy=multi-user.target' \
      > /etc/systemd/system/fix-bios-grub.service \
    && systemctl enable fix-bios-grub.service \
    && bootc container lint
