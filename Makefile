#
# Core Makefile
#

TOP_DIR = $(CURDIR)

CONFIG = $(shell cat $(TOP_DIR)/.config 2>/dev/null)

ifeq ($(CONFIG),)
MACH = versatilepb
else
MACH = $(CONFIG)
endif
MACH_DIR = $(TOP_DIR)/machine/$(MACH)/

PREBUILT = $(TOP_DIR)/prebuilt/
PREBUILT_TOOLCHAINS = $(PREBUILT)/toolchains/
PREBUILT_ROOTFS = $(PREBUILT)/rootfs/
PREBUILT_KERNEL = $(PREBUILT)/kernel/
PREBUILT_BIOS = $(PREBUILT)/bios/

include $(MACH_DIR)/Makefile

QEMU_GIT = https://github.com/qemu/qemu.git
QEMU = $(TOP_DIR)/qemu/

KERNEL_GIT = git://git.kernel.org/pub/scm/linux/kernel/git/stable/linux-stable.git
KERNEL = $(TOP_DIR)/linux-stable/

# Use faster mirror instead of git://git.buildroot.net/buildroot.git
BUILDROOT_GIT = https://github.com/buildroot/buildroot
BUILDROOT = $(TOP_DIR)/buildroot/

QEMU_OUTPUT = $(TOP_DIR)/output/$(XARCH)/qemu/
KERNEL_OUTPUT = $(TOP_DIR)/output/$(XARCH)/linux-$(LINUX)-$(MACH)/
BUILDROOT_OUTPUT = $(TOP_DIR)/output/$(XARCH)/buildroot-$(CPU)/

CCPATH ?= $(BUILDROOT_OUTPUT)/host/usr/bin/
TOOLCHAIN = $(PREBUILT_TOOLCHAINS)/$(XARCH)

HOST_CPU_THREADS = $(shell grep processor /proc/cpuinfo | wc -l)

MISC = $(TOP_DIR)/misc/

ifneq ($(BIOS),)
    BIOS_ARG = -bios $(BIOS)
endif

EMULATOR = qemu-system-$(XARCH) $(BIOS_ARG)

# TODO: kernel defconfig for $ARCH with $LINUX
LINUX_KIMAGE = $(KERNEL_OUTPUT)/$(ORIIMG)
KIMAGE ?= $(LINUX_KIMAGE)

# TODO: buildroot defconfig for $ARCH

ROOTDEV ?= /dev/ram0
BUILDROOT_ROOTFS = $(BUILDROOT_OUTPUT)/images/rootfs.cpio.gz
PREBUILT_ROOTDIR = $(PREBUILT_ROOTFS)/$(XARCH)/$(CPU)/rootfs/
ifneq ($(ROOTFS),)
ROOTDIR = $(PREBUILT_ROOTDIR)
else
ROOTDIR = $(BUILDROOT_OUTPUT)/target/
endif
ROOTFS ?= $(BUILDROOT_ROOTFS)

# TODO: net driver for $BOARD
#NET = " -net nic,model=smc91c111,macaddr=DE:AD:BE:EF:3E:03 -net tap"
NET =  -net nic,model=$(NETDEV) -net tap

# Common
ROUTE = $(shell ifconfig br0 | grep "inet addr" | cut -d':' -f2 | cut -d' ' -f1)

SERIAL ?= ttyS0
CONSOLE?= tty0

CMDLINE = route=$(ROUTE) root=$(ROOTDEV) $(EXT_CMDLINE)
ifeq ($(ROOTDEV),/dev/nfs)
TMP = $(shell bash -c 'echo $$(($$RANDOM%230+11))')
IP = $(shell echo $(ROUTE)END | sed -e 's/\.\([0-9]*\)END/.$(TMP)/g')
CMDLINE += nfsroot=$(ROUTE):$(ROOTDIR) ip=$(IP)
endif

CMDLINE_NG = $(CMDLINE) console=$(SERIAL)
CMDLINE_G = $(CMDLINE) console=$(CONSOLE)

# For debug
env:
	@echo "[$(MACH)]:"
	@echo "   $(XARCH)"
	@echo "   $(CPU)"
	@echo "   $(NETDEV)"
	@echo "   $(SERIAL)"
	@echo "   $(LINUX)"
	@echo "   $(MEM)"
	@echo "   $(ROOTDEV)"
	@echo "   $(CCPRE)"
	@echo "   $(ROOTFS)"
	@echo "   $(CCPATH)"

mach-config:
	@echo $(MACH) > $(TOP_DIR)/.config
	@find machine/$(MACH) -name "Makefile" -printf "* [%p]\n" -exec cat -n {} \;

mach-list:
	@find machine/ -name "Makefile" -printf "* [%p]\n" -exec cat -n {} \;

# Please makesure docker, git are installed
# TODO: Use gitsubmodule instead, ref: http://tinylab.org/nodemcu-kickstart/ 
qemu-source:
	git submodule update --init qemu

kernel-source:
	git submodule update --init linux-stable

buildroot-source:
	git submodule update --init buildroot

source: qemu-source kernel-source buildroot-source

# Qemu

emulator:
	mkdir -p $(QEMU_OUTPUT)
	cd $(QEMU_OUTPUT) && $(QEMU)/configure --target-list=$(ARCH)-softmmu && cd $(TOP_DIR)
	make -C $(QEMU_OUTPUT) -j$(HOST_CPU_THREADS)

# Toolchains

toolchain:
	make -C $(TOOLCHAIN)

toolchain-clean:
	make -C $(TOOLCHAIN) clean

# Rootfs
# Configure Buildroot
root-defconfig: $(MACH_DIR)/buildroot_$(CPU)_defconfig
	mkdir -p $(BUILDROOT_OUTPUT)
	cp $(MACH_DIR)/buildroot_$(CPU)_defconfig $(BUILDROOT)/configs/
	make O=$(BUILDROOT_OUTPUT) -C $(BUILDROOT) buildroot_$(CPU)_defconfig

root-menuconfig:
	make O=$(BUILDROOT_OUTPUT) -C $(BUILDROOT) menuconfig

# Build Buildroot
root:
	make O=$(BUILDROOT_OUTPUT) -C $(BUILDROOT) -j$(HOST_CPU_THREADS)
	cp $(MISC)/if-pre-up.d/config_iface $(BUILDROOT_OUTPUT)/target/etc/network/if-pre-up.d/config_iface
	make O=$(BUILDROOT_OUTPUT) -C $(BUILDROOT)

# Configure Kernel
kernel-defconfig: $(MACH_DIR)/linux_$(LINUX)_defconfig
	cd $(KERNEL) && git checkout -f linux-$(LINUX).y && cd $(TOP_DIR)
	mkdir -p $(KERNEL_OUTPUT)
	cp $(MACH_DIR)/linux_$(LINUX)_defconfig $(KERNEL)/arch/$(ARCH)/configs/
	make O=$(KERNEL_OUTPUT) -C $(KERNEL) ARCH=$(ARCH) linux_$(LINUX)_defconfig

kernel-menuconfig:
	make O=$(KERNEL_OUTPUT) -C $(KERNEL) ARCH=$(ARCH) menuconfig


# Build Kernel

KPATCH=$(TOP_DIR)/patch/linux/$(LINUX)/

kernel:
	# Kernel 2.6.x need include/linux/compiler-gcc5.h
ifeq ($(findstring 2.6.,$(LINUX)),2.6.)
	-$(foreach p,$(shell ls $(KPATCH)),$(shell echo patch -r- -N -l -d $(KERNEL) -p1 \< $(KPATCH)/$p\;))
endif
	PATH=$(PATH):$(CCPATH) make O=$(KERNEL_OUTPUT) -C $(KERNEL) ARCH=$(ARCH) CROSS_COMPILE=$(CCPRE) -j$(HOST_CPU_THREADS)

# Config Kernel and Rootfs
config: root-defconfig kernel-defconfig

# Build Kernel and Rootfs
build: root kernel

# Save the built images
root-save:
	mkdir -p $(PREBUILT_ROOTFS)/$(XARCH)/$(CPU)/
	cp $(BUILDROOT_ROOTFS) $(PREBUILT_ROOTFS)/$(XARCH)/$(CPU)/

kernel-save:
	mkdir -p $(PREBUILT_KERNEL)/$(XARCH)/$(MACH)/$(LINUX)/
	cp $(LINUX_KIMAGE) $(PREBUILT_KERNEL)/$(XARCH)/$(MACH)/$(LINUX)/

kconfig-save:
	cp $(KERNEL_OUTPUT)/.config $(MACH_DIR)/linux_$(LINUX)_defconfig

rconfig-save:
	cp $(BUILDROOT_OUTPUT)/.config $(MACH_DIR)/buildroot_$(CPU)_defconfig


save: root-save kernel-save rconfig-save kconfig-save


# Launch Qemu, prefer our own instead of the prebuilt one 
BOOT_CMD = PATH=$(QEMU_OUTPUT)/$(ARCH)-softmmu/:$(PATH) $(EMULATOR) -M $(MACH) -m $(MEM) $(NET) -kernel $(KIMAGE)
ifeq ($(findstring /dev/ram,$(ROOTDEV)),/dev/ram)
BOOT_CMD += -initrd $(ROOTFS)
endif

rootdir:
ifeq ($(ROOTDIR),$(PREBUILT_ROOTDIR))
ifneq ($(PREBUILT_ROOTDIR),$(wildcard $(PREBUILT_ROOTDIR)))
	mkdir -p $(ROOTDIR) && cd $(ROOTDIR)/ && cp ../rootfs.cpio.gz ./ && gunzip -f rootfs.cpio.gz && cpio -idmv < rootfs.cpio
endif
endif

rootdir-clean:
ifeq ($(ROOTDIR),$(PREBUILT_ROOTDIR))
	-rm -rf $(ROOTDIR)
endif

boot-ng: rootdir
	$(BOOT_CMD) -append "$(CMDLINE_NG)" -nographic

boot: rootdir
	$(BOOT_CMD) -append "$(CMDLINE_G)"

# Allinone
all: config build boot

# Clean up

emulator-clean:
	make -C $(QEMU_OUTPUT) clean

root-clean:
	make O=$(BUILDROOT_OUTPUT) -C $(BUILDROOT) clean

kernel-clean:
	make O=$(KERNEL_OUTPUT) -C $(KERNEL) clean

clean: emulator-clean root-clean kernel-clean rootdir-clean

help:
	@cat $(TOP_DIR)/README.md
