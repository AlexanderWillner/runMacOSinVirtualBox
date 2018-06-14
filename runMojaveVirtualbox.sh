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
# Source  : https://gist.github.com/AlexanderWillner/e65cfa6c3c537edbd35a99aca2a0ae7a
# Source (config.plist) : https://gist.github.com/AlexanderWillner/1066810002251d456f16def24cfbd85f
###############################################################################

# Core parameters #############################################################
readonly INST_VER="Install macOS 10.14 Beta"
readonly INST_BIN="/Applications/$INST_VER.app/Contents/Resources/createinstallmedia"
readonly DST_DIR="/tmp"
readonly DST_DMG="$DST_DIR/macOS-Mojave.dmg"
readonly DST_CLOVER="$DST_DIR/macOS-MojaveClover"
readonly DST_VOL="/Volumes/macOS-Mojave"
readonly DST_ISO="$DST_DIR/macOS-Mojave.iso.cdr"
readonly FILE_EFI="/usr/standalone/i386/apfs.efi"
readonly FILE_CFG="config.plist"
readonly VM="macOS-Mojave"
readonly VM_DIR="$HOME/VirtualBox VMs/$VM"
readonly VM_SIZE="32768"
###############################################################################

# Define methods ##############################################################
runChecks() {
  echo "Running checks..."
  if [ ! -x "$INST_BIN" ]; then
    echo "ERROR: '$INST_BIN' not found."
    exit 1
  fi
  if ! type VBoxManage >/dev/null 2>&1; then
    echo "ERROR: 'VBoxManage' not installed."
    exit 2
  fi
  if ! type xz >/dev/null 2>&1; then
    echo "ERROR: 'xz' not installed."
    exit 3
  fi
  if [ ! -f "$FILE_EFI" ]; then
    echo "ERROR: '$FILE_EFI' not found."
    exit 4
  fi
  if [ ! -f "$FILE_CFG" ]; then
    echo "ERROR: '$FILE_CFG' not found. Not checked out?"
    exit 5
  fi
}

createImage() {
  echo -n "Creating image '$DST_DMG' (will need sudo)..."
  if [ ! -e "$DST_DMG" ]; then
    echo "."
    hdiutil detach "/Volumes/$INST_VER/" 2>/dev/null || true
    hdiutil create -o "$DST_DMG" -size 10g -layout SPUD -fs HFS+J &&
      hdiutil attach "$DST_DMG" -mountpoint "$DST_VOL" &&
      sudo "$INST_BIN" --nointeraction --volume "$DST_VOL" &&
      hdiutil detach "/Volumes/$INST_VER/"
  else
    echo "already exists."
  fi
  echo -n "Creating iso '$DST_ISO'..."
  if [ ! -e "$DST_ISO" ]; then
    echo "."
    hdiutil convert "$DST_DMG" -format UDTO -o "$DST_ISO"
  else
    echo "already exists."
  fi
}

createClover() {
  echo -n "Creating clover image '$DST_CLOVER.iso'..."
  if [ ! -e "$DST_CLOVER.iso" ]; then
    echo "."
    curl -Lk https://sourceforge.net/projects/cloverefiboot/files/Bootable_ISO/CloverISO-4533.tar.lzma/download -o clover.tar.lzma
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
  echo -n "Creating VM HDD '$VM_DIR/$VM.vdi'..."
  if [ ! -e "$VM_DIR/$VM.vdi" ]; then
    echo "."
    VBoxManage createhd --filename "$VM_DIR/$VM.vdi" --variant Standard --size "$VM_SIZE"
  else
    echo "already exists."
  fi
  echo -n "Creating VM '$VM'..."
  if ! VBoxManage showvminfo "$VM" >/dev/null 2>&1; then
    echo "."
    VBoxManage createvm --register --name "$VM" --ostype MacOS1013_64
    VBoxManage modifyvm "$VM" --usbxhci on --memory 4096 --vram 128 --firmware efi --chipset ich9 --mouse usbtablet --keyboard usb
    VBoxManage setextradata "$VM" "CustomVideoMode1" "1920x1080x32"
    VBoxManage setextradata "$VM" VBoxInternal2/EfiGraphicsResolution 1680x1050
    VBoxManage storagectl "$VM" --name "SATA Controller" --add sata --controller IntelAHCI --hostiocache on
    VBoxManage storageattach "$VM" --storagectl "SATA Controller" --port 0 --device 0 --type hdd --nonrotational on --medium "$VM_DIR/$VM.vdi"
    VBoxManage storageattach "$VM" --storagectl "SATA Controller" --port 1 --device 0 --type dvddrive --medium "$DST_CLOVER.iso"
    VBoxManage storageattach "$VM" --storagectl "SATA Controller" --port 2 --device 0 --type dvddrive --medium "$DST_ISO"
  else
    echo "already exists."
  fi
}

runVM() {
  echo -n "Starting VM '$VM'..."
  if ! VBoxManage showvminfo 'macOS-Mojave' | grep "State:" | grep -i running >/dev/null; then
    echo "."
    VBoxManage startvm "$VM" --type gui
    echo "Bootup takes around 3 minutes..."
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
  if [[ "$err" -ne "0" ]]; then
    echo 2>&1 "ERROR: line $line - command '$command' exited with status: $err."
    echo 2>&1 "ERROR: In $funcstack called at line $linecallfunc."
    echo 2>&1 "DEBUG: From function ${funcstack[0]} (line $linecallfunc)."
  fi
}

main() {
  if [ "$1" = "clean" ]; then
    VBoxManage unregistervm --delete "$VM" || true
    rm -f Clover-v2.4k-4533-X64.iso clover.tar "$DST_DIR/macOS-Mojave.dmg" "$DST_DIR/macOS-MojaveClover.iso" "$DST_DIR/macOS-MojaveClover.dmg" "$DST_DIR/macOS-Mojave.iso.cdr" || true
  else
    echo "Setup takes around 2 minutes..."
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
