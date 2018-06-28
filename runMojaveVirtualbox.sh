#!/usr/bin/env bash
#
# DESCRIPTION
#
# Run macOS 10.14 Mojave in Virtualbox.
#
# CREDITS
#
# Author  : Alexander Willner
# License : Whatever. Use at your own risk.
# Source  : https://github.com/AlexanderWillner/runMacOSinVirtualBox
###############################################################################

# Core parameters #############################################################
readonly INST_VERS="$(find /Applications -maxdepth 1 -type d -name 'Install macOS*' | wc -l | tr -d '[:space:]')"
readonly INST_VER="$(find /Applications -maxdepth 1 -type d -name 'Install macOS*' -print -quit)"
readonly INST_BIN="$INST_VER/Contents/Resources/createinstallmedia"
readonly DST_DIR="/tmp"
readonly VM="macOS-Mojave"
readonly VM_DIR="$HOME/VirtualBox VMs/$VM"
readonly VM_SIZE="32768"
readonly VM_RES="1680x1050"
readonly VM_RAM="4096"
readonly VM_VRAM="128"
readonly VM_CPU="2"
readonly DST_DMG="$DST_DIR/$VM.dmg"
readonly DST_CLOVER="$DST_DIR/${VM}Clover"
readonly DST_VOL="/Volumes/$VM"
readonly DST_ISO="$DST_DIR/$VM.iso.cdr"
readonly FILE_EFI="$DST_DIR/apfs.efi"
readonly FILE_CFG="config.plist"
###############################################################################

# Define methods ##############################################################
runChecks() {
  echo "Running checks (1 second)..."
  if [ "$INST_VERS" = "0" ]; then
    echo "ERROR: No macOS installer found. Opening the web page for you..."
    open 'https://beta.apple.com/sp/betaprogram/redemption#macos'
    exit 6
  fi
  if [ ! "$INST_VERS" = "1" ]; then
    echo "ERROR: $INST_VERS macOS installers found. Don't know which one to select."
    exit 7
  fi
  if [ ! -d "$INST_VER/Contents/SharedSupport/" ]; then
    echo "ERROR: Seems you've downloaded the macOS Stub Installer. Please download the full installer (google the issue)."
    echo "Suggestion: Follow Step 2 (Download the macOS Public Beta Access Utility). Opening the web page for you..."
    open 'https://beta.apple.com/sp/betaprogram/redemption#macos'
    exit 8
  fi
  if [ ! -x "$INST_BIN" ]; then
    echo "ERROR: '$INST_BIN' not found."
    exit 1
  fi
  if ! type VBoxManage >/dev/null 2>&1; then
    echo "ERROR: 'VBoxManage' not installed. Trying to install automatically, if you've brew installed..."
    if ! type brew >/dev/null 2>&1; then brew cask install virtualbox ; fi
    exit 2
  fi
  if ! type xz >/dev/null 2>&1; then
    echo "ERROR: 'xz' not installed. Trying to install automatically, if you've brew installed..."
    if ! type brew >/dev/null 2>&1; then brew install xz ; fi
    exit 3
  fi
  if [ "$(VBoxManage list extpacks | grep 'USB 3.0')" = "" ]; then
    echo "ERROR: VirtualBox USB 3.0 Extension Pack not installed. Trying to install automatically, if you've brew installed..."
    if ! type brew >/dev/null 2>&1; then brew cask install virtualbox-extension-pack ; fi
    exit 4
  fi
  if [ ! -f "$FILE_CFG" ]; then
    echo "ERROR: '$FILE_CFG' not found. Not checked out?"
    exit 5
  fi
}

ejectAll() {
  hdiutil info | grep 'Install macOS' | awk '{print $1}' | while read -r i; do
    hdiutil detach "$i" 2>/dev/null || true
  done
  hdiutil info | grep 'OS X Base System' | awk '{print $1}' | while read -r i; do
    hdiutil detach "$i" 2>/dev/null || true
  done
  hdiutil info | grep 'InstallESD' | awk '{print $1}' | while read -r i; do
    hdiutil detach "$i" 2>/dev/null || true
  done
  hdiutil detach "$DST_VOL" 2>/dev/null || true
}

createImage() {
  echo -n "Creating image '$DST_DMG' (20 seconds, will need sudo)..."
  if [ ! -e "$DST_DMG" ]; then
    echo "."
    ejectAll
    hdiutil create -o "$DST_DMG" -size 10g -layout SPUD -fs HFS+J &&
      hdiutil attach "$DST_DMG" -mountpoint "$DST_VOL" &&
      sudo "$INST_BIN" --nointeraction --volume "$DST_VOL"
    ejectAll
  else
    echo "already exists."
  fi
  echo -n "Creating iso '$DST_ISO' (10 seconds)..."
  if [ ! -e "$DST_ISO" ]; then
    echo "."
    hdiutil convert "$DST_DMG" -format UDTO -o "$DST_ISO"
  else
    echo "already exists."
  fi
}

extractAPFS() {
  echo -n "Extracting APFS EFI driver (3 seconds)..."
  if [ ! -e "$FILE_EFI" ]; then
    echo "."
    ejectAll
    hdiutil attach "$INST_VER/Contents/SharedSupport/BaseSystem.dmg" &&
      cp /Volumes/OS\ X\ Base\ System/usr/standalone/i386/apfs.efi "$FILE_EFI"
    ejectAll
  else
    echo "already exists."
  fi
}

createClover() {
  echo -n "Creating clover image '$DST_CLOVER.iso' (30 seconds)..."
  if [ ! -e "$DST_CLOVER.iso" ]; then
    echo "."
    extractAPFS
    while [ ! -f "clover.tar.lzma" ]; do
      echo "Downloading Clover (needs Internet access)..."
      curl -Lk https://sourceforge.net/projects/cloverefiboot/files/Bootable_ISO/CloverISO-4533.tar.lzma/download -o clover.tar.lzma
      sleep 1
    done
    xz -d clover.tar.lzma
    tar xf clover.tar
    hdiutil detach /Volumes/Clover-v2.4k-4533-X64/ 2>/dev/null || true
    hdiutil attach Clover-v2.4k-4533-X64.iso
    hdiutil create -megabytes 16 -fs MS-DOS -volname MojaveClover -o "$DST_CLOVER.dmg"
    hdiutil detach /Volumes/NO\ NAME/ 2>/dev/null || true
    hdiutil attach "$DST_CLOVER.dmg"
    cp -r /Volumes/Clover-v2.4k-4533-X64/* /Volumes/NO\ NAME/
    cp "$FILE_CFG" /Volumes/NO\ NAME/EFI/CLOVER/
    cp "$FILE_EFI" /Volumes/NO\ NAME/EFI/CLOVER/drivers64UEFI/
    hdiutil detach /Volumes/Clover-v2.4k-4533-X64/
    hdiutil detach /Volumes/NO\ NAME/
    hdiutil makehybrid -iso -joliet -o "$DST_CLOVER.iso" "$DST_CLOVER.dmg"
  else
    echo "already exists."
  fi
}

setupVM() {
  if [ ! -e "$VM_DIR" ]; then
    mkdir -p "$VM_DIR"
  fi
  echo -n "Creating VM HDD '$VM_DIR/$VM.vdi' (5 seconds)..."
  if [ ! -e "$VM_DIR/$VM.vdi" ]; then
    echo "."
    VBoxManage createhd --filename "$VM_DIR/$VM.vdi" --variant Standard --size "$VM_SIZE"
  else
    echo "already exists."
  fi
  echo -n "Creating VM '$VM' (2 seconds)..."
  if ! VBoxManage showvminfo "$VM" >/dev/null 2>&1; then
    echo "."
    VBoxManage createvm --register --name "$VM" --ostype MacOS1013_64
    VBoxManage modifyvm "$VM" --usbxhci on --memory "$VM_RAM" --vram "$VM_VRAM" --cpus "$VM_CPU" --firmware efi --chipset ich9 --mouse usbtablet --keyboard usb
    VBoxManage setextradata "$VM" "CustomVideoMode1" "${VM_RES}x32"
    VBoxManage setextradata "$VM" VBoxInternal2/EfiGraphicsResolution "$VM_RES"
    VBoxManage storagectl "$VM" --name "SATA Controller" --add sata --controller IntelAHCI --hostiocache on
    VBoxManage storageattach "$VM" --storagectl "SATA Controller" --port 0 --device 0 --type hdd --nonrotational on --medium "$VM_DIR/$VM.vdi"
    VBoxManage storageattach "$VM" --storagectl "SATA Controller" --port 1 --device 0 --type dvddrive --medium "$DST_CLOVER.iso"
    VBoxManage storageattach "$VM" --storagectl "SATA Controller" --port 2 --device 0 --type dvddrive --medium "$DST_ISO"
  else
    echo "already exists."
  fi
}

runVM() {
  echo -n "Starting VM '$VM' (3 minutes)..."
  if ! VBoxManage showvminfo 'macOS-Mojave' | grep "State:" | grep -i running >/dev/null; then
    echo "."
    VBoxManage startvm "$VM" --type gui
    echo "Next steps:"
    echo "  1. Disk Utility: erase the virtual drive using APFS and call it 'Mojave' (it will be converted otherwise)"
    echo "  2. Install macOS: on the erased virtual drive 'Mojave' (around 4 minutes)"
    echo "  3. After the reboot: switch off the VM, remove the virtual macOS installer CD-ROM and restart"
    echo "  4. Start macOS in the Clover boot menu (the initial installation might take a few hours)"
  else
    echo "already running."
  fi
}

cleanup() {
  local err="${1:-}"
  local line="${2:-}"
  local linecallfunc="${3:-}"
  local command="${4:-}"
  local funcstack="${5:-}"
  ejectAll
  if [[ "$err" -ne "0" ]]; then
    echo 2>&1 "ERROR: line $line - command '$command' exited with status: $err."
    echo 2>&1 "ERROR: In $funcstack called at line $linecallfunc."
    echo 2>&1 "DEBUG: From function ${funcstack[0]} (line $linecallfunc)."
  fi
}

main() {
  if [ "$1" = "clean" ]; then
    rm -f Clover-v2.4k-4533-X64.iso clover.tar* "$DST_CLOVER.iso" "$DST_CLOVER.dmg" "$DST_DMG" "$DST_ISO" "$FILE_EFI" || true
  fi
  if [ "$1" = "stash" ]; then
    VBoxManage unregistervm --delete "$VM" || true
  fi
  if [ "$1" = "" ]; then
    runChecks
    createImage
    createClover
    setupVM
    runVM
  fi
}
###############################################################################

# Run script ##################################################################
[[ "${BASH_SOURCE[0]}" == "${0}" ]] && trap 'cleanup "${?}" "${LINENO}" "${BASH_LINENO}" "${BASH_COMMAND}" $(printf "::%s" ${FUNCNAME[@]:-})' EXIT && main "${@:-}"
###############################################################################
