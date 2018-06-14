# Run macOS 10.14 Mojave on VirtualBox

## Overview

Simple script to automatically install and run macOS 10.14 Mojave on VirtualBox. Since VirtualBox 5.2 does not support booting from APFS volumes, this script is using the [Clover EFI bootloader](https://sourceforge.net/projects/cloverefiboot/) as a workaround.

## How To

Here an example after already successfully created the images and VM:

```
$ make image
Setup takes around 2 minutes...
Running checks...
Creating image '/tmp/macOS-Mojave.dmg' (will need sudo)...already exists.
Creating iso '/tmp/macOS-Mojave.iso.cdr'...already exists.
Creating clover image '/tmp/macOS-MojaveClover.iso'...already exists.
Creating VM HDD '/Users/me/VirtualBox VMs/macOS-Mojave/macOS-Mojave.vdi'...already exists.
Creating VM 'macOS-Mojave'...already exists.
Starting VM 'macOS-Mojave'...already running.
```

Some help:
```
$ make
Some available commands:
 * image    : create macOS installer, clover image and VM
 * clean    : delete generated images and VM
 * test     : run some tests
 * style    : style bash scripts
 * harden   : harden bash scripts
 * feedback : create a GitHub issue
```
 
## Example Screenshot

![Running macOS 10.14 Mojave Beta 1 in VirtualBox 5.2](img/macosMojaveBeta1.png)
