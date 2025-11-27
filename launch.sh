#!/bin/bash

# Paths
KERNEL="$HOME/Emulating-CXL-devices-with-QEMU-VM-tutorial/cxl-qemu/linux-kernel/arch/x86_64/boot/bzImage"
DISK="$HOME/Emulating-CXL-devices-with-QEMU-VM-tutorial/cxl-qemu/ubuntu25.04.qcow2"
INITRD="$HOME/Emulating-CXL-devices-with-QEMU-VM-tutorial/cxl-qemu/initrd.img"
QEMU="$HOME/Emulating-CXL-devices-with-QEMU-VM-tutorial/cxl-qemu/qemu/build/qemu-system-x86_64"

# Launch QEMU VM
sudo $QEMU \
  -M q35,cxl=on \
  -smp 4 \
  -m 4G,maxmem=8G,slots=8 \
  -kernel "$KERNEL" \
  -append "root=/dev/mapper/ubuntu--vg-ubuntu--lv console=ttyS0 rw" \
  -initrd "$INITRD" \
  -drive file="$DISK",format=qcow2,if=none,id=hd0 \
  -device virtio-blk-pci,drive=hd0,bus=pcie.0,id=virtio0 \
  -netdev user,id=net0 \
  -device virtio-net-pci,netdev=net0 \
  -nographic \
  -accel kvm \
  \
  -object memory-backend-file,id=cxl-mem1,share=on,mem-path=/tmp/cxltest.raw,size=256M \
  -object memory-backend-file,id=cxl-mem2,share=on,mem-path=/tmp/cxltest2.raw,size=256M \
  -object memory-backend-file,id=cxl-mem3,share=on,mem-path=/tmp/cxltest3.raw,size=256M \
  -object memory-backend-file,id=cxl-mem4,share=on,mem-path=/tmp/cxltest4.raw,size=256M \
  -object memory-backend-file,id=cxl-lsa1,share=on,mem-path=/tmp/lsa.raw,size=256M \
  -object memory-backend-file,id=cxl-lsa2,share=on,mem-path=/tmp/lsa2.raw,size=256M \
  -object memory-backend-file,id=cxl-lsa3,share=on,mem-path=/tmp/lsa3.raw,size=256M \
  -object memory-backend-file,id=cxl-lsa4,share=on,mem-path=/tmp/lsa4.raw,size=256M \
  -device pxb-cxl,bus_nr=12,bus=pcie.0,id=cxl.1 \
  -device pxb-cxl,bus_nr=222,bus=pcie.0,id=cxl.2 \
  -device cxl-rp,port=0,bus=cxl.1,id=root_port13,chassis=0,slot=2 \
  -device cxl-type3,bus=root_port13,persistent-memdev=cxl-mem1,lsa=cxl-lsa1,id=cxl-pmem0,sn=0x1 \
  -device cxl-rp,port=1,bus=cxl.1,id=root_port14,chassis=0,slot=3 \
  -device cxl-type3,bus=root_port14,persistent-memdev=cxl-mem2,lsa=cxl-lsa2,id=cxl-pmem1,sn=0x2 \
  -device cxl-rp,port=0,bus=cxl.2,id=root_port15,chassis=0,slot=5 \
  -device cxl-type3,bus=root_port15,persistent-memdev=cxl-mem3,lsa=cxl-lsa3,id=cxl-pmem2,sn=0x3 \
  -device cxl-rp,port=1,bus=cxl.2,id=root_port16,chassis=0,slot=6 \
  -device cxl-type3,bus=root_port16,persistent-memdev=cxl-mem4,lsa=cxl-lsa4,id=cxl-pmem3,sn=0x4 \
  -M cxl-fmw.0.targets.0=cxl.1,cxl-fmw.0.targets.1=cxl.2,cxl-fmw.0.size=4G,cxl-fmw.0.interleave-granularity=8k
