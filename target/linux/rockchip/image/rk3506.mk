# SPDX-License-Identifier: GPL-2.0-only
#
# Copyright (C) 2024 RK3506 OpenWrt Port

### RK3506 base definitions (ImmortalWrt-style BOOT_FLOW pattern) ###
define Device/rk3506
  SOC := rk3506
  KERNEL_LOADADDR := 0x03200000
  # RK3506 is 32-bit ARM (Cortex-A7). The kernel is configured for a
  # self-decompressing zImage (CONFIG_AUTO_ZRELADDR / CONFIG_ARM_PATCH_PHYS_VIRT),
  # so ship the zImage as the FIT kernel payload instead of the default raw
  # vmlinux binary. A raw ARM Image is not position-independent and hangs in
  # early head.S when entered at the high load address below.
  #
  # TEXT_OFFSET is bumped from 0x8000 to 0x208000 via patch 0019 so that the
  # zImage output is above both OP-TEE and the secure DRAM firewall's possible
  # 1/2 MiB granule. This preserves the ARM kernel requirement that
  # KERNEL_RAM_VADDR ends in 0x8000.
  KERNEL_NAME := zImage
  # Vendor U-Boot builds with CONFIG_FIT_IMAGE_POST_PROCESS=y, which makes
  # fit_image_load() require a "load" address on every FIT subimage - including
  # the FDT. Without it the FDT node has no load address, U-Boot bails out and
  # leaves the fdt blob pointer uninitialised (e.g. 0x00000002), so boot fails
  # with "image is not a fdt - must RESET the board".
  #
  # The FDT must also survive kernel decompression: with CONFIG_AUTO_ZRELADDR
  # the zImage decompresses the kernel to (RAM base + TEXT_OFFSET) = 0x00208000
  # and it grows to well over 8 MiB, so a low FDT (e.g. 0x00063000) would be
  # overwritten. Load the FDT at 0x02000000 (32 MiB) instead: it sits safely
  # above the decompressed kernel and below both the compressed zImage copy
  # (0x03200000) and the FIT image, matching the common ARM fdt_addr_r value.
  DEVICE_DTS_LOADADDR := 0x02000000
  BOOT_FLOW := rk3506-img
  DEVICE_DTS = $$(lastword $$(subst _, ,$$(1)))
  UBOOT_DEVICE_NAME = evb-$$(SOC)
endef

### Devices ###

define Device/hzhy_mini_evm_emmc
  $(Device/rk3506)
  DEVICE_VENDOR := HZHY
  DEVICE_MODEL := RK3506SP MiniEVM (eMMC)
  DEVICE_DTS := rockchip/HZ-RK3506SP_MiniEVM_EMMC
  DEVICE_PACKAGES := kmod-usb-hid kmod-usb-ohci kmod-usb2 kmod-usb-storage \
    kmod-usb-storage-extras kmod-usb-net kmod-usb-core kmod-gpio-button-hotplug \
    urandom-seed
  KERNEL := kernel-bin | fit none $$(DTS_DIR)/$$(DEVICE_DTS).dtb
  BOOT_SCRIPT := rk3506
  # MMC/SD style target: squashfs only, no UBIFS variant (see NAND devices)
  FILESYSTEMS := squashfs
endef
TARGET_DEVICES += hzhy_mini_evm_emmc

define Device/hzhy_mini_evm_nand
  $(Device/rk3506)
  DEVICE_VENDOR := HZHY
  DEVICE_MODEL := RK3506SP MiniEVM (NAND)
  DEVICE_DTS := rockchip/HZ-RK3506SP_MiniEVM_NAND
  DEVICE_PACKAGES := kmod-usb-hid kmod-usb-ohci kmod-usb2 kmod-usb-storage \
    kmod-usb-storage-extras kmod-usb-net kmod-usb-core kmod-gpio-button-hotplug \
    kmod-mtd-rw urandom-seed
  KERNEL := kernel-bin | fit none $$(DTS_DIR)/$$(DEVICE_DTS).dtb
  BOOT_SCRIPT := rk3506
  # SPI-NAND target: never an MMC-style disk image. The kernel is stored raw in
  # the "boot" MTD partition and the rootfs lives in a UBI volume on the
  # "rootfs" partition (see the NAND DTS partition table). Two artifacts are
  # produced, to be written from a TF-card-booted Linux:
  #   flash_erase /dev/mtd3 0 0 && nandwrite -p /dev/mtd3 <img>-ubifs-kernel.bin
  #   ubiformat /dev/mtd4 -f <img>-ubifs-rootfs.ubi
  FILESYSTEMS := ubifs
  BLOCKSIZE := 128k
  PAGESIZE := 2048
  VID_HDR_OFFSET := 2048
  # 182.5 MiB rootfs partition = 1392 PEBs; allow for the bad-block reserve
  MKUBIFS_OPTS := -c 1350
  IMAGES := kernel.bin rootfs.ubi
  IMAGE/kernel.bin = append-kernel
  IMAGE/rootfs.ubi = append-ubi
endef
TARGET_DEVICES += hzhy_mini_evm_nand

define Device/hzhy_mini_evm_nand256
  $(Device/rk3506)
  DEVICE_VENDOR := HZHY
  DEVICE_MODEL := RK3506SP MiniEVM (NAND 256MiB)
  DEVICE_DTS := rockchip/HZ-RK3506SP_MiniEVM_NAND256
  DEVICE_PACKAGES := kmod-usb-hid kmod-usb-ohci kmod-usb2 kmod-usb-storage \
    kmod-usb-storage-extras kmod-usb-net kmod-usb-core kmod-gpio-button-hotplug \
    kmod-mtd-rw urandom-seed
  KERNEL := kernel-bin | fit none $$(DTS_DIR)/$$(DEVICE_DTS).dtb
  BOOT_SCRIPT := rk3506
  # See the NAND device above; same idea, sized for the 256 MiB layout
  #   mtd3 "boot"   -> <img>-ubifs-kernel.bin
  #   mtd4 "rootfs" -> <img>-ubifs-rootfs.ubi
  FILESYSTEMS := ubifs
  BLOCKSIZE := 128k
  PAGESIZE := 2048
  VID_HDR_OFFSET := 2048
  # 230.75 MiB rootfs partition = 1846 PEBs; allow for the bad-block reserve
  MKUBIFS_OPTS := -c 1800
  IMAGES := kernel.bin rootfs.ubi
  IMAGE/kernel.bin = append-kernel
  IMAGE/rootfs.ubi = append-ubi
endef
TARGET_DEVICES += hzhy_mini_evm_nand256

define Device/hzhy_mini_evm_sd
  $(Device/rk3506)
  DEVICE_VENDOR := HZHY
  DEVICE_MODEL := RK3506SP MiniEVM (SD/TF card)
  DEVICE_DTS := rockchip/HZ-RK3506SP_MiniEVM_SD
  DEVICE_PACKAGES := kmod-usb-hid kmod-usb-ohci kmod-usb2 kmod-usb-storage \
    kmod-usb-storage-extras kmod-usb-net kmod-usb-core kmod-gpio-button-hotplug \
    kmod-fs-ext4 kmod-fs-vfat kmod-mmc urandom-seed
  KERNEL := kernel-bin | fit none $$(DTS_DIR)/$$(DEVICE_DTS).dtb
  BOOT_SCRIPT := rk3506
  # TF/eMMC image: bootloader at sector 64/0x4000, then boot + rootfs.
  # Written to SD with: dd if=...-sd.img of=/dev/sdX bs=4M conv=fsync
  FILESYSTEMS := squashfs
  IMAGES := sdcard.img.gz sysupgrade.img.gz
  IMAGE/sdcard.img.gz = boot-common | boot-script rk3506 | rk3506-img | gzip
endef
TARGET_DEVICES += hzhy_mini_evm_sd
