l#!/usr/bin/env bash
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
readonly PATH="$PATH:/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:/usr/X11/bin"
readonly SCRIPTPATH="$(
  cd "$(dirname "$0")" || exit
  pwd -P
)"
readonly INST_VERS="$(find /Applications -maxdepth 1 -type d -name 'Install macOS*' | wc -l | tr -d '[:space:]')"
readonly INST_VER="$(find /Applications -maxdepth 1 -type d -name 'Install macOS*' -print -quit)"
readonly INST_BIN="$INST_VER/Contents/Resources/createinstallmedia"
readonly DST_DIR="${DST_DIR:-$HOME/VirtualBox VMs}"
readonly VM_NAME="${VM_NAME:-macOS-Mojave}"
readonly VM_DIR="${VM_DIR:-$DST_DIR/$VM_NAME}"
readonly VM_SIZE="${VM_SIZE:-32768}"
readonly VM_RES="${VM_RES:-1680x1050}"
readonly VM_RAM="${VM_RAM:-4096}"
readonly VM_VRAM="${VM_VRAM:-128}"
readonly VM_CPU="${VM_CPU:-2}"
readonly DST_DMG="$DST_DIR/$VM_NAME.dmg"
readonly DST_CLOVER="$DST_DIR/${VM_NAME}Clover"
readonly DST_VOL="/Volumes/$VM_NAME"
readonly DST_ISO="$DST_DIR/$VM_NAME.iso.cdr"
readonly FILE_EFI="/tmp/apfs.efi"
readonly FILE_CFG="$SCRIPTPATH/config.plist"
readonly FILE_EFIMOVER="$SCRIPTPATH/moveCloverToEFI.sh"
readonly FILE_LOG="$HOME/Library/Logs/runMojaveVirtualbox.log"
###############################################################################

# Logging #####################################################################
exec 3>&1
exec 4>&2
exec 1>>"$FILE_LOG"
exec 2>&1
###############################################################################

# Define methods ##############################################################
debug() {
  echo "DEBUG: $1" >&3
  log "$1"
}

error() {
  echo "ERROR: $1" >&4
  log "$1"
  if [ -d "$SCRIPTPATH/ProgressDialog.app" ]; then
    osascript -e 'tell application "'"$SCRIPTPATH/ProgressDialog.app"'"' -e 'activate' \
      -e 'set name of window 1 to "Installing macOS Mojave on Virtualbox"' \
      -e 'set message of window 1 to "'"ERROR: $1"'."' \
      -e 'set percent of window 1 to (100)' \
      -e 'end tell'
  fi
}

info() {
  echo -n "$1" >&3
  log "$1"
  if [ -d "$SCRIPTPATH/ProgressDialog.app" ]; then
    osascript -e 'tell application "'"$SCRIPTPATH/ProgressDialog.app"'"' -e 'activate' \
      -e 'set name of window 1 to "Installing macOS Mojave on Virtualbox"' \
      -e 'set message of window 1 to "'"$1"'...'"$2"'%."' \
      -e 'set percent of window 1 to ('"$2"')' \
      -e 'end tell'
  fi
}

result() {
  echo "$1" >&3
  log "$1"
}

log() {
  datestring="$(date +'%Y-%m-%d %H:%M:%S')"
  echo "[$datestring] $1" >>"$FILE_LOG"
}

runChecks() {
  info "Running checks (around 1 second)..." 0
  result "."
  if [ -d "$SCRIPTPATH/ProgressDialog.app" ]; then
    info "Opening GUI..." 0
    open "$SCRIPTPATH/ProgressDialog.app"
  fi
  if [ "$INST_VERS" = "0" ]; then
    open 'https://beta.apple.com/sp/betaprogram/redemption#macos'
    error "No macOS installer found. Opening the web page for you (press enter in the terminal when done)..."
    read -r
    exit 6
  fi
  if [ ! "$INST_VERS" = "1" ]; then
    error "$INST_VERS macOS installers found. Don't know which one to select."
    exit 7
  fi
  if [ ! -d "$INST_VER/Contents/SharedSupport/" ]; then
    open 'https://beta.apple.com/sp/betaprogram/redemption#macos'
    error "Seems you've downloaded the macOS Stub Installer. Please download the full installer (google the issue)."
    debug "Follow Step 2 (Download the macOS Public Beta Access Utility). Opening the web page for you (press enter in the terminal when done)..."
    read -r
    exit 8
  fi
  if [ ! -x "$INST_BIN" ]; then
    error "'$INST_BIN' not found."
    exit 1
  fi
  if ! type VBoxManage >/dev/null 2>&1; then
    error "'VBoxManage' not installed. Trying to install automatically, if you've brew installed..."
    if type brew >/dev/null 2>&1; then
      brew cask install virtualbox || exit 2
    else
      exit 2
    fi
  fi
  if ! type xz >/dev/null 2>&1; then
    error "'xz' not installed. Trying to install automatically, if you've brew installed..."
    if type brew >/dev/null 2>&1; then
      brew install xz || exit 3
      brew link xz || exit 3
    else
      exit 3
    fi
  fi
  awk >/dev/null 2>&1
  if [ ! $? -eq 1 ]; then
    error "Something is wrong with your 'awk' installation. Trying to fix it automatically, if you've brew installed..."
    if type brew >/dev/null 2>&1; then
      brew upgrade awk || exit 6
    else
      exit 6
    fi
  fi
  if [ "$(VBoxManage list extpacks | grep 'USB 3.0')" = "" ]; then
    error "VirtualBox USB 3.0 Extension Pack not installed. Trying to install automatically, if you've brew installed..."
    if type brew >/dev/null 2>&1; then
      brew cask install virtualbox-extension-pack || exit 4
    else
      exit 4
    fi
  fi
  if [ ! -f "$FILE_CFG" ]; then
    error "'$FILE_CFG' not found. Not checked out? (press enter in the terminal when done)..."
    read -r
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
  version="$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$INST_VER/Contents/Info.plist")"
  info "Creating image '$DST_DMG' (around 20 seconds, version $version, will need sudo)..." 30
  if [ ! -e "$DST_DMG" ]; then
    result "."
    ejectAll
    mkdir -p "$DST_DIR"
    hdiutil create -o "$DST_DMG" -size 10g -layout SPUD -fs HFS+J &&
      hdiutil attach "$DST_DMG" -mountpoint "$DST_VOL" &&
      echo sudo "$INST_BIN" --nointeraction --volume "$DST_VOL" --applicationpath "$INST_VER"
      sudo "$INST_BIN" --nointeraction --volume "$DST_VOL" --applicationpath "$INST_VER"
    ejectAll
  else
    result "already exists."
  fi
  info "Creating iso '$DST_ISO' (around 25 seconds)..." 40
  if [ ! -e "$DST_ISO" ]; then
    result "."
    mkdir -p "$DST_DIR"
    hdiutil convert "$DST_DMG" -format UDTO -o "$DST_ISO"
  else
    result "already exists."
  fi
}

extractAPFS() {
  info " - Extracting APFS EFI driver (around 10 seconds)..." 60
  if [ ! -e "$FILE_EFI" ]; then
    result "."
    ejectAll
    hdiutil attach "$INST_VER/Contents/SharedSupport/BaseSystem.dmg" &&
      cp /Volumes/OS\ X\ Base\ System/usr/standalone/i386/apfs.efi "$FILE_EFI"
    ejectAll
  else
    result "already exists."
  fi
}

createClover() {
  info "Creating clover image '$DST_CLOVER.iso' (around 30 seconds)..."
  if [ ! -e "$DST_CLOVER.iso" ]; then
    result "."
    mkdir -p "$DST_DIR"
    extractAPFS
    while [ ! -f "Clover-v2.4k-4533-X64.iso" ]; do
      info " - Downloading Clover (needs Internet access)..." 80
      curl -Lk https://sourceforge.net/projects/cloverefiboot/files/Bootable_ISO/CloverISO-4533.tar.lzma/download -o clover.tar.lzma
      xz -d clover.tar.lzma && tar xf clover.tar
      sleep 1
    done
    hdiutil detach /Volumes/Clover-v2.4k-4533-X64/ 2>/dev/null || true
    hdiutil attach Clover-v2.4k-4533-X64.iso
    hdiutil create -megabytes 16 -fs MS-DOS -volname MojaveClover -o "$DST_CLOVER.dmg"
    hdiutil detach /Volumes/NO\ NAME/ 2>/dev/null || true
    hdiutil attach "$DST_CLOVER.dmg"
    cp -r /Volumes/Clover-v2.4k-4533-X64/* /Volumes/NO\ NAME/
    cp "$FILE_CFG" /Volumes/NO\ NAME/EFI/CLOVER/
    cp "$FILE_EFI" /Volumes/NO\ NAME/EFI/CLOVER/drivers64UEFI/
    cp "$FILE_EFIMOVER" /Volumes/NO\ NAME/
    hdiutil detach /Volumes/Clover-v2.4k-4533-X64/
    hdiutil detach /Volumes/NO\ NAME/
    hdiutil makehybrid -iso -joliet -o "$DST_CLOVER.iso" "$DST_CLOVER.dmg"
    rm -f "$DST_CLOVER.dmg" "$DST_CLOVER.dmg"
  else
    result "already exists."
  fi
}

createVM() {
  if [ ! -e "$VM_DIR" ]; then
    mkdir -p "$VM_DIR"
  fi
  info "Creating VM HDD '$VM_DIR/$VM_NAME.vdi' (around 5 seconds)..." 90
  if [ ! -e "$VM_DIR/$VM_NAME.vdi" ]; then
    result "."
    VBoxManage createhd --filename "$VM_DIR/$VM_NAME.vdi" --variant Standard --size "$VM_SIZE"
  else
    result "already exists."
  fi
  info "Creating VM '$VM_NAME' (around 2 seconds)..." 99
  if ! VBoxManage showvminfo "$VM_NAME" >/dev/null 2>&1; then
    result "."
    VBoxManage createvm --register --name "$VM_NAME" --ostype MacOS1013_64
    VBoxManage modifyvm "$VM_NAME" --usbxhci on --memory "$VM_RAM" --vram "$VM_VRAM" --cpus "$VM_CPU" --firmware efi --chipset ich9 --mouse usbtablet --keyboard usb
    VBoxManage setextradata "$VM_NAME" "CustomVideoMode1" "${VM_RES}x32"
    VBoxManage setextradata "$VM_NAME" VBoxInternal2/EfiGraphicsResolution "$VM_RES"
    VBoxManage storagectl "$VM_NAME" --name "SATA Controller" --add sata --controller IntelAHCI --hostiocache on
    VBoxManage storageattach "$VM_NAME" --storagectl "SATA Controller" --port 0 --device 0 --type hdd --nonrotational on --medium "$VM_DIR/$VM_NAME.vdi"
    VBoxManage storageattach "$VM_NAME" --storagectl "SATA Controller" --port 1 --device 0 --type dvddrive --medium "$DST_CLOVER.iso"
    VBoxManage storageattach "$VM_NAME" --storagectl "SATA Controller" --port 2 --device 0 --type dvddrive --medium "$DST_ISO"
  else
    result "already exists."
  fi
}

runVM() {
  info "Starting VM '$VM_NAME' (3 minutes in the VM)..." 100
  if ! VBoxManage showvminfo 'macOS-Mojave' | grep "State:" | grep -i running >/dev/null; then
    result "."
    VBoxManage startvm "$VM_NAME" --type gui
    echo "Next steps:"
    echo "  1. Disk Utility: erase the virtual drive using APFS and call it 'Mojave' (it will be converted otherwise)"
    echo "  2. Install macOS: on the erased virtual drive 'Mojave' (around 4 minutes)"
    echo "  3. After the reboot: switch off the VM, remove the virtual macOS installer CD-ROM and restart"
    echo "  4. Start macOS in the Clover boot menu (the initial installation might take a few hours)"
  else
    result "already running."
  fi
}

runClean() {
  rm -f Clover-v2.4k-4533-X64.iso clover.tar* "$FILE_LOG" "$DST_CLOVER.iso" "$DST_CLOVER.dmg" "$DST_DMG" "$DST_ISO" "$FILE_EFI" || true
}

cleanup() {
  local err="${1:-}"
  local line="${2:-}"
  local linecallfunc="${3:-}"
  local command="${4:-}"
  local funcstack="${5:-}"
  ejectAll
  if [[ $err -ne "0" ]]; then
    debug "line $line - command '$command' exited with status: $err."
    debug "In $funcstack called at line $linecallfunc."
    debug "From function ${funcstack[0]} (line $linecallfunc)."
    error "Look at $FILE_LOG for details (or use Console.app). Press enter in the terminal when done..."
    read -r
  fi
  if [ -d "$SCRIPTPATH/ProgressDialog.app" ]; then
    osascript -e 'tell application "ProgressDialog"' -e 'quit' -e 'end tell'
  fi
}

main() {
  while [ "$#" -ne 0 ]; do
    ARG="$1"
    shift # get rid of $1, we saved in ARG already
    case "$ARG" in
    check) runChecks ;;
    clean) runClean ;;
    stash) VBoxManage unregistervm --delete "$VM_NAME" || true ;;
    installer) createImage ;;
    clover) createClover ;;
    vm) createVM ;;
    run) runVM ;;
    all) runChecks && createImage && createClover && createVM && runVM ;;
    *) echo "Possible commands: clean, stash, all, check, installer, clover, vm, run" >&4 ;;
    esac
  done
}
###############################################################################

# Run script ##################################################################
[[ ${BASH_SOURCE[0]} == "${0}" ]] && trap 'cleanup "${?}" "${LINENO}" "${BASH_LINENO}" "${BASH_COMMAND}" $(printf "::%s" ${FUNCNAME[@]:-})' EXIT && main "${@:-}"
###############################################################################
