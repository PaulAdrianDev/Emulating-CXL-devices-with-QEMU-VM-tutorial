#!/bin/bash


sudo apt-get install -y libglib2.0-dev libgcrypt20-dev zlib1g-dev autoconf automake libtool flex libpixman-1-dev bc make ninja-build libncurses-dev libelf-dev libssl-dev libcap-ng-dev libattr1-dev libslirp-dev libslirp0 git fakeroot build-essential ncurses-dev xz-utils libssl-dev bc libelf-dev bison python3-venv python3-pip
pip install tomli
mkdir cxl-qemu
cd cxl-qemu
git clone https://gitlab.com/qemu-project/qemu.git
cd qemu
git checkout stable-10.0
./configure --target-list=x86_64-softmmu --enable-debug
make -j$(nproc)
cd ../
git clone https://github.com/weiny2/linux-kernel.git
cd linux-kernel
git checkout dcd-v6-2025-09-23
make defconfig
rm .config
mv ../.config .config
make -j$(nproc)
sudo make modules_install
sudo mkinitramfs -o initrd.img 6.17.0-rc+
cd ../  
wget https://releases.ubuntu.com/plucky/ubuntu-25.04-live-server-amd64.iso  
qemu/build/qemu-img create -f qcow2 ubuntu25.04.qcow2 30G

