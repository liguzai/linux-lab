
# Linux Lab

This project aims to make a Qemu-based Linux development Lab to easier the
learning and development of the Linux Kernel itself.

## Download the lab

    $ git clone https://github.com/tinyclub/linux-lab.git
    $ cd /linux-lab/

## Build the Lab

    $ sudo tools/install-docker-lab.sh
    $ tools/run-docker-lab-daemon.sh
    $ tools/open-docker-lab.sh

## Quickstart

Login in `http://localhost:6080/vnc.html` with 'ubuntu' password, and then open a terminal:

    $ sudo -s
    $ cd /linux-lab
    $ make boot

## Usage

Check supported machines:

    $ make mach-list

Check the machine specifci configuration:

    $ make mach-list | grep Makefile
    * [machine/pc/Makefile]
    * [machine/versatilepb/Makefile]
    * [machine/g3beige/Makefile]
    * [machine/malta/Makefile]
    $ cat machine/versatilepb/Makefile
    ARCH=arm
    XARCH=$(ARCH)
    CPU=arm926t
    MEM=128M
    LINUX=2.6.35
    NETDEV=smc91c111
    SERIAL=ttyAMA0
    ROOTDEV=/dev/nfs
    ORIIMG=arch/$(ARCH)/boot/zImage
    CCPRE=arm-linux-gnueabi-
    KIMAGE=$(PREBUILT_KERNEL)/$(XARCH)/$(MACH)/$(LINUX)/zImage
    ROOTFS=$(PREBUILT_ROOTFS)/$(XARCH)/$(CPU)/rootfs.cpio.gz

Disable prebuilt kernel and rootfs via comment the `KIMAGE` and `ROOTFS`:

    $ vim machine/versatilepb/Makefile
    #KIMAGE=$(PREBUILT_KERNEL)/$(XARCH)/$(MACH)/$(LINUX)/zImage
    #ROOTFS=$(PREBUILT_ROOTFS)/$(XARCH)/$(CPU)/rootfs.cpio.gz

Download the sources:

    $ make source # All in one

    $ make kernel-source  # One by one
    $ make buildroot-source

Configure the sources:

    $ make config  # Configure all with defconfig

    $ make kernel-defconfig # Configure one by one
    $ make root-defconfig

Manually configure the sources:

    $ make kernel-menuconfig
    $ make root-menuconfig

Build them:

    $ make build   # All in one

    $ make kernel  # One by one
    $ make root

Boot it:

    $ make boot-ng  # Boot with serial port (no graphic), exit with 'pkill qemu'

    $ make boot     # Boot with graphic

Boot with NFS-rootfs or RamFs:

    $ make boot ROOTDEV=/dev/nfs
    $ make boot ROOTDEV=/dev/ram

If NFS boot fails, please make sure `IP_PNP` and `ROOT_NFS` are configured in
kernel and if issue still exists, then try to fix up it:

    $ tools/restart-nfs-server.sh

By default, the default machine: 'versatilepb' is used, we can configure, build
and boot for a specific machine with 'MACH', for example:

    $ make MACH=malta root-defconfig
    $ make MACH=malta root
    $ make MACH=malta kernel-defconfig
    $ make MACH=malta kernel
    $ make MACH=malta boot

Or simply do:

    $ make MACH=malta mach-config

## More

Buildroot has provided many examples about buildroot and kernel configuration:

* buildroot: `configs/qemu_ARCH_BOARD_defconfig`
* kernel: `board/qemu/ARCH-BOARD/linux-VERSION.config`

To start a new ARCH, BOARD and linux VERSION test, please based on it.

Note, different qemu version uses different kernel VERSION, so, to find the
suitable kernel version, we can checkout different git tags.
