#!/bin/bash

# Run this within the virtual machine and remove the ISO from the setup afterwards
sudo mkdir /Volumes/EFI
sudo mount -t msdos /dev/disk0s1 /Volumes/EFI
sudo cp -r /Volumes/NO\ NAME/EFI/* /Volumes/EFI/EFI
sudo diskutil unmount /dev/disk0s1

