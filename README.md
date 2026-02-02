
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
cd cxl-qemu
```

and then go to the **Boot VM with the .iso file** and continue.

# If you wanna go step by step

## Packages
```
sudo apt update
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

Go up one level, now you should have a directory "qemu"
```
cd ../
ls
```

## Download Linux Kernel
```
git clone https://github.com/weiny2/linux-kernel.git
cd linux-kernel
git checkout dcd-v6-2025-09-23
```
Now this part might be scary, don't worry just press the right arrow to go to \<Exit> and press space twice.
```
make menuconfig
```

Now a `.config` file should have appeared, delete it and add my .config file here
```
rm .config
cp ../../.config .config
```

Now run the next command and go find something else to do because it may take a while. (it may ask you some questions at the start, press y)
```
make -j$(nproc) && sudo make modules_install
```

To verify that it finished successfully you should have a bzImage file in the following path and this kernel release
```
$ ls -lh arch/x86/boot/bzImage
-rw-r--r-- 1 Paul_S ucy-coast-teach- 13M Nov 16 10:07 arch/x86/boot/bzImage

$ cat include/config/kernel.release
6.17.0-rc6+
```

Now we need to make RAM Initialization Functions
```
cd ../
sudo mkinitramfs -o initrd.img $(cat linux-kernel/include/config/kernel.release)
```
## Download a file system

We will download the Ubuntu 25.04 server file system for the VM, go back to your directory.
```
cd ../
wget https://releases.ubuntu.com/plucky/ubuntu-25.04-live-server-amd64.iso
```

## Create a QEMU image
This will be the space your VM runs in.

You can make this image whatever size you want but try to give yourself space since its annoying to expand it.

```
qemu/build/qemu-img create -f qcow2 ubuntu25.04.qcow2 30G
```




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

If you get an error regarding `-accel kvm / KVM` you have to enable it in your BIOS, search online how to do it because if you don't want to use -accel kvm your VM will run 10x slower. I did this next step once with and without `-accel kvm` and without it, it took around an hour and with it, 10 minutes. (If you are stubborn and don't want to use `-accel kvm` then you don't need sudo.)

```
sudo ./qemu/build/qemu-system-x86_64 \
-m 8192 \
-smp 4 \
-machine type=q35 \
-boot d \
-cdrom ubuntu-25.04-live-server-amd64.iso \
-drive file=ubuntu25.04.qcow2,format=qcow2 \
-accel kvm
```


If you're running this on a server/machine with no GUI you poor soul, you can't see the window of Ubuntu to set it up. You need to install a VNC program on a machine that has a GUI and connect to this machine that you're doing this tutorial on. I installed TigerVNC. Run this script instead:

```
sudo ./qemu/build/qemu-system-x86_64 \
-m 8192 \
-smp 4 \
-machine type=q35 \
-boot d \
-cdrom ubuntu-25.04-live-server-amd64.iso \
-drive file=ubuntu25.04.qcow2,format=qcow2 \
-accel kvm \
-vnc 0.0.0.0:0
```

Your terminal should now not take any input after this script. Open your VNC program and connect to server-ip:5900 (server-ip is the IP address of the machine you're doing this tutorial on) and do the Ubuntu setup there.

## Boot VM with the disk now

Now the .iso file did it's job and is no longer needed, you will boot with the disk now. You can delete the .iso file if you want. You can also delete all the linux-kernel content but **keep the bzImage**.

We are done here, now it's just a matter of setting up your QEMU VM CXL configuration how you want it, the following are some examples. You can check out some example VMs on [QEMU's CXL Page](https://www.qemu.org/docs/master/system/devices/cxl.html).

### This is a launch command for 1 Volatile Device
I suggest you make a script to store your QEMU launch commands because you can easily copy it and try changing things. I used this one.
```
#!/bin/bash

# Paths
PATH_TO_CXL_TUTORIAL="/mydata"
KERNEL="$PATH_TO_CXL_TUTORIAL/Emulating-CXL-devices-with-QEMU-VM-tutorial/cxl-qemu/linux-kernel/arch/x86_64/boot/bzImage"
DISK="$PATH_TO_CXL_TUTORIAL/Emulating-CXL-devices-with-QEMU-VM-tutorial/cxl-qemu/ubuntu25.04.qcow2"
INITRD="$PATH_TO_CXL_TUTORIAL/Emulating-CXL-devices-with-QEMU-VM-tutorial/cxl-qemu/initrd.img"
QEMU="$PATH_TO_CXL_TUTORIAL/Emulating-CXL-devices-with-QEMU-VM-tutorial/cxl-qemu/qemu/build/qemu-system-x86_64"

sudo $QEMU \
  -machine type=q35,cxl=on,accel=kvm,mem-merge=on \
  -smp 32 \
  -m 8G,maxmem=16G,slots=8 \
  -cpu host \
  -kernel "$KERNEL" \
  -initrd "$INITRD" \
  -append "root=/dev/mapper/ubuntu--vg-ubuntu--lv console=ttyS0 rw memhp_default_state=online_movable" \
  -drive file="$DISK",format=qcow2,if=none,id=hd0 \
  -device virtio-blk-pci,drive=hd0,bus=pcie.0,id=virtio0 \
  -netdev user,id=net0 \
  -device virtio-net-pci,netdev=net0 \
  -nographic \
  \
  -object memory-backend-ram,id=vmem0,share=on,size=256M \
  -object memory-backend-ram,id=vmem1,share=on,size=512M \
  -device pxb-cxl,bus_nr=12,bus=pcie.0,id=cxl.1 \
  -device cxl-rp,port=0,bus=cxl.1,id=root_port13,chassis=0,slot=2 \
  -device cxl-rp,port=1,bus=cxl.1,id=root_port14,chassis=0,slot=3 \
  -device cxl-type3,bus=root_port13,volatile-memdev=vmem0,id=cxl-vmem0 \
  -M cxl-fmw.0.targets.0=cxl.1,cxl-fmw.0.size=4G,cxl-fmw.0.interleave-granularity=4k

```
# Things to do when you open your VM
## Resize your partition
You allocated 30G of space but if you run `lsblk` you'll see you only have 14/28GB on your partition and the other 14 are no used, run these commands so that you have your 28G.
```
sudo lvextend -l +100%FREE /dev/ubuntu-vg/ubuntu-lv
sudo resize2fs /dev/ubuntu-vg/ubuntu-lv
```
## Enable Internet Access

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

## Create CXL Memory Region
To see the difference, you should NOT have a region0 in your CXL devices.
```
.......:~$ ls /sys/bus/cxl/devices/

decoder0.0  decoder1.2	decoder2.1  endpoint2	    port1
decoder1.0  decoder1.3	decoder2.2  mem0	    root0
decoder1.1  decoder2.0	decoder2.3  nvdimm-bridge0
```

If you ran the launch command like above you should run
```
sudo cxl create-region -m -d decoder0.0 -w 1 -g 4096 -t ram mem0
```

Now you should get a JSON output if it worked correctly and it will appear in this folder:
```
.......:~$ ls /sys/bus/cxl/devices/

dax_region0  decoder1.1  decoder2.0  decoder2.3  nvdimm-bridge0  root0
decoder0.0   decoder1.2  decoder2.1  endpoint2	 port1
decoder1.0   decoder1.3  decoder2.2  mem0	 region0
```

Also after a successful command you should get a file here
```
........:~$ ls -lh /dev/dax0.0

crw------- 1 root root 249, 1 Feb  2 09:43 /dev/dax0.0
```

Do also:
```
daxctl list
```
You should get an output like this:
```
[
  {
    "chardev":"dax0.0",
    "size":268435456,
    "target_node":1,
    "align":2097152,
    "mode":"system-ram"
  }
]
```

If it says `"mode":"devdax"` or has `"state":"disabled"` check that your DAX modules are built-in:
```
.........:~$ zcat /proc/config.gz | grep -i dax

CONFIG_ARCH_WANT_OPTIMIZE_DAX_VMEMMAP=y
CONFIG_NVDIMM_DAX=y
CONFIG_DAX=y
CONFIG_DEV_DAX=y
CONFIG_DEV_DAX_PMEM=y
CONFIG_DEV_DAX_HMEM=y
CONFIG_DEV_DAX_CXL=y
CONFIG_DEV_DAX_HMEM_DEVICES=y
CONFIG_DEV_DAX_KMEM=y
CONFIG_FS_DAX=y
CONFIG_FS_DAX_PMD=y
CONFIG_FUSE_DAX=y
```

At first I had issues with this DAX but I just forgot to enable 1 module (DAX_KMEM), as soon as I enabled it and rebuilt it worked perfectly.

Now you should see that the device shows up as a NUMA node:
```
.......:~$ numactl --hardware

available: 2 nodes (0-1)
node 0 cpus: 0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31
node 0 size: 7942 MB
node 0 free: 6690 MB
node 1 cpus:
node 1 size: 256 MB
node 1 free: 256 MB
node distances:
node   0   1 
  0:  10  20 
  1:  20  10 
```

## Install the modules of your custom kernel (NOT really needed)
Now the VM that booted has the built-in features of your custom kernel. If you want to have the modules of your custom kernel in your VM also, you need to compile the same linux image in the VM. (I don't know if this is needed but I did it just in case some program needs modules or stuff)

***If you'll do this, you will need more storage than 30GB, I made my VM 100GB just incase but the whole process took around 50GB of storage at its peak. So resize your image (on the host) to atleast 60GB and resize the disk in the VM to take up this new space. Also I suggest you open your VM with more than 4 cores and more RAM to finish fast.***

#### In the VM:
You'll need the same .config file
```
mkdir more-setup
cd more-setup
git clone https://github.com/PaulAdrianDev/Emulating-CXL-devices-with-QEMU-VM-tutorial.git
```

Now you do the same linux process
```
git clone https://github.com/weiny2/linux-kernel.git
cd linux-kernel
git checkout dcd-v6-2025-09-23
make menuconfig
```
Just press \<Exit> on menuconfig.

The following will install the modules that the custom .config file has, as well as other linux-y things for your kernel that might or might not be useful
```
rm .config
cp ../Emulating-CXL-devices-with-QEMU-VM-tutorial/.config .config
make -j$(nproc)
sudo make modules_install
sudo update-initramfs -c -k 6.17.0-rc6+
sudo make install
```

And then reboot
```
sudo reboot
```

And now you should see your kernel's `(6.17.0-rc6+)` modules:
```
...........:~$ ls /lib/modules
6.14.0-15-generic  6.14.0-35-generic  6.14.0-36-generic  6.17.0-rc6+
```

Now you can delete the more-setup dir and have fun CXL-ing!

