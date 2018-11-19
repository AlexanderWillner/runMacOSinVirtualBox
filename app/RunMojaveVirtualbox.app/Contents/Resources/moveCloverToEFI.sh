#!/bin/bash

if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 
   exit 1
fi

# Run this within the virtual machine and remove the ISO from the setup afterwards
mkdir /Volumes/EFI
mount -t msdos /dev/disk0s1 /Volumes/EFI
mkdir -p /Volumes/EFI/EFI
cp -r /Volumes/NO\ NAME/EFI/* /Volumes/EFI/EFI
diskutil unmount /dev/disk0s1

