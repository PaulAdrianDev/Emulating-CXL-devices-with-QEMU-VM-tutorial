# Emulating CXL with QEMU Tutorial
This is a step by step tutorial on how to set up QEMU from the source code, compile a linux kernel with custom configurations and use it with QEMU to boot up an Ubuntu 25.04 Virtual Machine with CXL devices for emulation.

**Notice:** Before we get started, if you are in any organizational machine (e.g. University server) that has safety measures such as proxy servers, blocking iptables and such, just give up. I tried to do this on an organizational machine and almost pulled my hair out, ask your organization for a laptop or access to server providers like CloudLab.

## Prerequisites
- Like 40GB of free space 
- Ubuntu 22.04 (jammy)

## If you can't be bothered

There is the script full-setup.sh that does the code for you until the **Boot VM with the .iso file** so after you clone the repo you can just:
```
chmod +x full-setup.sh
./full-setup.sh
```
and then go to the **Boot VM with the .iso file** and continue.

## Ignore this for now

```
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
make menuconfig
```

Do menuconfig
```
make -j$(nproc)  
cd ../  
wget https://releases.ubuntu.com/plucky/ubuntu-25.04-live-server-amd64.iso  
qemu/build/qemu-img create -f qcow2 ubuntu25.04.qcow2 30G
```

# If you wanna go step by step

## Packages
```
sudo apt-get install -y libglib2.0-dev libgcrypt20-dev zlib1g-dev autoconf automake libtool flex libpixman-1-dev bc make ninja-build libncurses-dev libelf-dev libssl-dev libcap-ng-dev libattr1-dev libslirp-dev libslirp0 git fakeroot build-essential ncurses-dev xz-utils bison python3-venv python3-pip
```
#### The following will not work properly in Ubuntu 25.04 (so make sure you use 22.04)!
```
pip install tomli
```

## Make a directory for everything
```
mkdir cxl-qemu
cd cxl-qemu
```

## Download QEMU
```
git clone https://gitlab.com/qemu-project/qemu.git
cd qemu
git checkout stable-10.0
./configure --target-list=x86_64-softmmu --enable-debug
make -j$(nproc)
```

Now you should have a directory "qemu", go up one level
```
cd ../
```

## Download Linux Kernel
```
git clone https://github.com/weiny2/linux-kernel.git
cd linux-kernel
git checkout dcd-v6-2025-09-23
make defconfig
```
A .config file should have appeared now, delete it and add my .config file to this directory
```
ls -lh .config
rm .config
```

Now run the next commands and go find something else to do because it may take a while. (it may ask you some questions at the start, press y)
```
make -j$(nproc)
sudo make modules_install
sudo mkinitramfs -o ~/cxl-qemu/initrd.img 6.17.0-rc6+
```

To verify that it finished successfully you should have a bzImage file
```
ls -lh arch/x86/boot/bzImage
```

## Download a file system

I will download the Ubuntu 25.04 server file system for the VM, go back to your directory
```
cd ../
wget https://releases.ubuntu.com/plucky/ubuntu-25.04-live-server-amd64.iso
```

## Create a QEMU image
```
qemu/build/qemu-img create -f qcow2 ubuntu25.04.qcow2 30G
```

You can make this image whatever size you want but try to give yourself space since its annoying to expand it.


## Let's make sure everything is alright
Now in your directory cxl-qemu (if you named it the same) you should have:
- a folder "linux-kernel"
- a folder "qemu"
- a file ubuntu-25.04-live-server-amd64.iso
- a file ubuntu25.04.qcow2
- a file initrd.img

## Boot VM with the .iso file

Now you boot your VM with the .iso file as a ROM to set it up. For me it took around 10 minutes on a performant server so don't be afraid if it seems like it froze at some points.

- If you are following this tutorial on your own device with a GUI like normal people, run the **FIRST SCRIPT** and ignore what's under. 
- If you are on a server/machine with no GUI skip the **FIRST SCRIPT** and read what's under.

Change the -smp flag to how many cores you want to give to the VM and the -m to how many bytes of memory, the more cores the faster the installation (probably). *Type nproc in the CLI to find out how many cores you have if you don't know and free -h to find out your RAM.*

### FIRST SCRIPT
After you run this script an Ubuntu setup window will pop up, do the installation process normally, no stress, you got this. When it finishes there will be an option Reboot Now, don't press it just close the window.

```
./qemu/build/qemu-system-x86_64 \
-m 8192 \
-smp 4 \
-machine type=q35 \
-boot d \
-cdrom ubuntu-25.04-live-server-amd64.iso \
-drive file=ubuntu25.04.qcow2,format=qcow2
```


If you're running this on a server/machine with no GUI you poor soul, you can't see the window of Ubuntu to set it up. You need to install a VNC program on a machine that has a GUI and connect to this machine that you're doing this tutorial on. I installed TigerVNC. Run this script instead:

```
./qemu/build/qemu-system-x86_64 \
-m 8192 \
-smp 4 \
-machine type=q35 \
-boot d \
-cdrom ubuntu-25.04-live-server-amd64.iso \
-drive file=ubuntu25.04.qcow2,format=qcow2 \
-vnc 0.0.0.0:0
```

Your terminal should now not take any input after this script. Open your VNC program and connect to server-ip:5900 (server-ip is the IP address of the machine you're doing this tutorial on) and do the Ubuntu setup there.

## Boot VM with the disk now

Now the .iso file did it's job and is no longer needed, you will boot with the disk now. You can delete the .iso file if you want.

We are done here, now it's just a matter of setting up your QEMU VM CXL configuration how you want it, the following are some examples (the exact commands are run in the cxl-qemu folder).

### VM with CXL Devices
Make a bash script to launch your VM and change the various paths and then just run it.
```
#!/bin/bash

# Paths
KERNEL="$HOME/cxl-qemu/linux-kernel/arch/x86_64/boot/bzImage"
DISK="$HOME/cxl-qemu/ubuntu25.04.qcow2"
CXL_MEM="/tmp/cxltest.raw"
CXL_LSA="/tmp/lsa.raw"

# QEMU command
$HOME/cxl-qemu/qemu/build/qemu-system-x86_64 \
  -M q35,cxl=on -m 4G,maxmem=8G,slots=8 -smp 4 \
  -kernel "$KERNEL" \
  -append "root=/dev/mapper/ubuntu--vg-ubuntu--lv console=ttyS0 rw" \
  -drive file="$DISK",format=qcow2,if=none,id=hd0 \
  -device virtio-blk-pci,drive=hd0,bus=pcie.0,id=virtio0 \
  -initrd ~/cxl-qemu/initrd.img \
  \
  -netdev user,id=net0 \
  -device virtio-net-pci,netdev=net0 \
  \
  -nographic \
  \
  -object memory-backend-file,id=cxl-mem1,share=on,mem-path="$CXL_MEM",size=256M \
  -object memory-backend-file,id=cxl-lsa1,share=on,mem-path="$CXL_LSA",size=256M \
  -device pxb-cxl,bus_nr=12,bus=pcie.0,id=cxl.1 \
  -device cxl-rp,port=0,bus=cxl.1,id=root_port13,chassis=0,slot=2 \
  -device cxl-type3,bus=root_port13,persistent-memdev=cxl-mem1,lsa=cxl-lsa1,id=cxl-pmem0,sn=0x1 \
  -M cxl-fmw.0.targets.0=cxl.1,cxl-fmw.0.size=4G

```
# Warning: Nothing is guaranteed from this point on QEMU VMs is a very complicated topic that I don't know enough on, I will write some errors/things I encountered and what I did
## I can't sudo apt / VM doesn't have internet access

In the VM if you try to `ping 8.8.8.8` and it says Network is Unreachable do this:
```
ip addr
```
You should see something like:
```
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
    inet6 ::1/128 scope host noprefixroute 
       valid_lft forever preferred_lft forever
2: enp0s3: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc pfifo_fast state DOWN group default qlen 1000
    link/ether 52:54:00:12:34:56 brd ff:ff:ff:ff:ff:ff
    altname enx525400123456
```
Copy the name `enp0s3` or whatever yours is. Now make sure you have a .yaml file in your `/etc/netplan/`
```
.........:~$ ls /etc/netplan
50-cloud-init.yaml
```
Edit it now so that it's contents are the following, change `enp0s3` to whatever yours is.
```
network:
  version: 2
  ethernets:
    enp0s3:
      dhcp4: true
```
Then apply the changes and try to `ping 8.8.8.8` again.
```
sudo netplan apply
```

