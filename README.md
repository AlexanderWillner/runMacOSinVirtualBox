# Run macOS 11 Big Sur (and other versions) in VirtualBox on macOS

## Overview

Simple script to automatically download, install and run macOS 11 Big Sur (and other versions) in VirtualBox on macOS. Since VirtualBox does not support booting from APFS volumes, this script is copying the APFS EFI drivers automatically.

[![Codacy Badge](https://api.codacy.com/project/badge/Grade/722e2f9736844387b611945fb430d195)](https://app.codacy.com/app/AlexanderWillner/runMacOSinVirtualBox?utm_source=github.com&utm_medium=referral&utm_content=AlexanderWillner/runMacOSinVirtualBox&utm_campaign=Badge_Grade_Dashboard) [![download](https://img.shields.io/github/downloads/AlexanderWillner/runMacOSinVirtualBox/total)](https://github.com/AlexanderWillner/runMacOSinVirtualBox/releases)

![macosBigSurBeta1](./img/macosBigSurBeta1.png)

## ToC

* [Required Software](#required-software)
* [Step by Step Video](#step-by-step-video)
* [Step by Step](#step-by-step)
* [FAQ](#faq)

## Required Software

The following software is needed.

* macOS Installer
* VirtualBox
* VirtualBox Extension Pack (note: released under the Personal Use and Evaluation License)

## Step by Step Video

Two minute summary video (Catalina):

[![Short Summary Video](https://img.youtube.com/vi/WmETOgRuMx4/0.jpg)](https://youtu.be/WmETOgRuMx4)

## Step by Step

Execute ```make all``` to setup and run everything. After the installer reboots, press enter in the terminal to finish the installation.

```bash
$ make all
Running checks (around 1 second)....
Creating image '/Users/awi/VirtualBox VMs/macOS-VM.dmg' (around 20 seconds, version 14.2.2, will need sudo)....
Creating iso '/Users/awi/VirtualBox VMs/macOS-VM.iso.cdr' (around 25 seconds)....
Creating VM HDD '/Users/awi/VirtualBox VMs/macOS-VM/macOS-VM.vdi' (around 5 seconds)....
Creating VM 'macOS-VM' (around 2 seconds)....
Adding APFS drivers to EFI in '/Users/awi/VirtualBox VMs/macOS-VM/macOS-VM.vdi' (around 5 seconds)....
Starting VM 'macOS-VM' (3 minutes in the VM)....
Press enter to stop VM 'macOS-VM' (e.g. after installer restarted)....

Ejecting installer DVD for VM 'macOS-VM'....
Starting VM 'macOS-VM' (3 minutes in the VM)....
```

### Customizing your build

Additionally the following parameters can be customized with environment variables:

| variable name | description                                         | default value                |
|---------------|-----------------------------------------------------|------------------------------|
| VM_NAME       | name of the virtual machine                         | macOS-VM                     |
| VM_DIR        | directory, where the virtual machine will be stored | HOME/VirtualBox VMs/$VM_NAME |
| VM_SIZE       | the size of the hard disk                           | 131072                       |
| VM_RES        | monitor resolution                                  | 1680x1050                    |
| VM_RAM        | ram size in megabytes                               | 4096                         |
| VM_VRAM       | video ram size in megabytes                         | 128                          |
| VM_CPU        | number of cpu cores to allocate                     | 2                            |

Execute ```make``` to get some help:

```bash
$ make
Some available commands:
 * all      : run everything needed (check, installer, vm, patch, run, stop, eject)
 * check    : check environment
 * installer: create macOS installer image
 * patch    : add APFS drivers to VM EFI to boot
 * vm       : create VM and disk
 * run      : run VM
 * stop     : stop VM
 * wait     : wait for VM to stop
 * eject    : eject installer medium
 * clean    : delete generated images and downloaded files
 * stash    : delete generated VM and disk
 * test     : test shell scripts
 * style    : style shell scripts
 * harden   : harden shell scripts
 * release  : make new release
 * feedback : create a GitHub issue
```

## FAQ

* Graphic Issues
  * Q: Applications such as Apple Maps do not work as expected.
  * A: There is currently no 3D acceleration, therefore some applications do not work.
* Recovery
  * Q: How do I start the recovery mode?
  * A: Start the VM as usual and be ready to press ```CMD+C``` when you see ```Trying to find a bootable device...``` to interrupt the regular boot process. At the following EFI shell prompt try to find the relevant volume holding ```boot.efi``` in a single randomly-named sub-directory of the root directory. So try to change the current volume by entering ```fs4:``` (or ```fs5:```, ```fs6:```, etc.), then enter ```cd TAB``` (where ```TAB``` is used to auto-complete the randomly-named sub-dir), then look for ```boot.efi``` in that dir. If existing, start Recovery by entering ```boot.efi```.
* Installation Loop
  * Q: After starting the installation the VM restarts and I see the installer again.
  * A: You've to press enter in the terminal after the installer restarts.
* Installation Not Starting
  * Q: I've pressed ```Continue``` to start the installation and nothing happens for minutes.
  * A: Your macOS installer might be incomplete or corrupted, please download it again from Apple.
* Error Message
  * Q: I get the error code 2, 3, 4, or 6.
  * A: You need to have some software components installed on your machine (VirtualBox, VirtualBox Extension Pack, awk). If you've installed [Homebrew](https://brew.sh), the script will partly install these automatically. Otherwise, you need to install them manually.
* Reboot
  * Q: I see the message ```MACH Reboot```. What should I do?
  * A: The VM failed to restart. Restart manually. However, this should not happen anymore with the latest version.
* Kernel Panic
  * Q: I see the message ```Error loading kernel cache (0x9)```. What should I do?
  * A: This error is shown from time to time. Restart the VM. However, this should not happen anymore with the latest version.
* Black Screen
  * Q: When I then boot I don't see anything, just a black screen. What should I do?
  * A: Change the VM version in the settings from ```Mac OS X (64-bit)``` to ```macOS 10.13 High Sierra (64-bit)```
* Slow
  * Q: Why is the VM so slow?
  * A: Maybe [#71](https://github.com/AlexanderWillner/runMacOSinVirtualBox/issues/71) provides some insights.
* Download macOS
  * Q: Where can I download macOS?
  * A: Look at the script `installinstallmacos.py`
* Other Issue
  * Q: Something is not working. What should I do?
  * A: [Create a ticket](https://github.com/AlexanderWillner/runMacOSinVirtualBox/issues/new?template=bug_report.md)
