# Run macOS 10.14 Mojave on VirtualBox on macOS

## Overview

Simple script to automatically install and run macOS 10.14 Mojave on VirtualBox on macOS. Since VirtualBox 5.2 does not support booting from APFS volumes, this script is using the [Clover EFI bootloader](https://sourceforge.net/projects/cloverefiboot/) as a workaround.

## ToC

 * [Quick Guide](#quick-guide)
 * [Step by Step Guide](#step-by-step-guide)
 * [Shell Hacker](#shell-hacker)
 * [FAQ](#faq)

##  Quick Guide

[![RunMojaveVirtualbox.app](img/app.png)](https://github.com/AlexanderWillner/runMacOSinVirtualBox/releases/download/1.0/RunMojaveVirtualbox.app.zip)
Download and execute the app [```RunMojaveVirtualbox.app```](https://github.com/AlexanderWillner/runMacOSinVirtualBox/releases/download/1.0/RunMojaveVirtualbox.app.zip).
 
## Step by Step Guide

1. After executing ```make all``` you should have a configured and running VM:
![Images](img/images.png)
2. After booting erase the virtual drive ```VBOX HARDDISK Media``` in Disk Utility using APFS and name it 'Mojave':
![Erase Disk](img/erase.png)
3. Install macOS on the erased virtual drive 'Mojave' (around 4 minutes):
![Install](img/install.png)
4. After the reboot switch off the VM and remove ```macOS-Mojave.iso.cdr``` and restart:
![Remove](img/remove.png)
5. Start macOS in the Clover boot menu (the initial installation might take some time):
![Clover](img/clover.png)
![Install](img/install2.png)
6. Enjoy macOS Mojave in Virtualbox:
![Running macOS 10.14 Mojave Beta 1 in VirtualBox 5.2](img/macosMojaveBeta1.png)

## Shell Hacker
Execute ```make all``` to setup and run everything:

```
$ time make all
Running checks (around 1 second)....
Creating image '/tmp/macOS-Mojave.dmg' (around 20 seconds, will need sudo)....
Password:
Creating iso '/tmp/macOS-Mojave.iso.cdr' (around 25 seconds)....
Creating clover image '/tmp/macOS-MojaveClover.iso' (around 30 seconds)....
 - Extracting APFS EFI driver (around 3 seconds)....
 - Downloading Clover (needs Internet access)...
Creating VM HDD '/Users/awi/VirtualBox VMs/macOS-Mojave/macOS-Mojave.vdi' (around 5 seconds)....
Creating VM 'macOS-Mojave' (around 2 seconds)....
Starting VM 'macOS-Mojave' (around 3 minutes in the VM)....

real	1m21.689s
user	0m19.641s
sys	0m14.779s
```

Execute ```make``` to get some help:

```
$ make
Some available commands:
 * all      : run everything needed (check, installer, clover, vm, run)
 * check    : check environment
 * installer: create macOS installer image
 * clover   : create clover boot image
 * vm       : create VM and disk
 * run      : run VM
 * clean    : delete generated images and downloaded files
 * stash    : delete generated VM and disk
 * test     : test shell scripts
 * style    : style shell scripts
 * harden   : harden shell scripts
 * feedback : create a GitHub issue
```

## FAQ

* Reboot
  * Q: I see the message ```MACH Reboot```. What should I do?
  * A: The VM failed to restart. Restart manually.
* Installation Loop
  * Q: After starting the installation the VM restarts and I see the installer again.
  * A: You forgot to remove the installation CD. Switch off the VM and go to step 4.
* Kernel Panic
  * Q: I see the message ```Error loading kernel cache (0x9)```. What should I do?
  * A: This error is shown from time to time. Restart the VM.
