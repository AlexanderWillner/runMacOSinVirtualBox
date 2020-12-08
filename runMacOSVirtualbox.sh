#!/usr/bin/env bash
#
# DESCRIPTION
#
# Run macOS Catalina and older versions in Virtualbox.
#
# CREDITS
#
# Author  : Alexander Willner
# License : Whatever. Use at your own risk.
# Source  : https://github.com/AlexanderWillner/runMacOSinVirtualBox
###############################################################################


# Logging #####################################################################
readonly FILE_LOG="$HOME/Library/Logs/runMacOSVirtualbox.log"
echo "Logfile: $FILE_LOG"
exec 3>&1
exec 4>&2
exec 1>>"$FILE_LOG"
exec 2>&1
###############################################################################


# Core parameters #############################################################
echo "Collecting system information..."
readonly PATH="$PATH:/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:/usr/X11/bin"
readonly SCRIPTPATH="$(
  cd "$(dirname "$0")" || exit
  pwd -P
)"
readonly INST_VERS="$(find /Applications -maxdepth 1 -type d -name 'Install macOS *' | wc -l | tr -d '[:space:]')"
readonly INST_VER="$(find /Applications -maxdepth 1 -type d -name 'Install macOS *' -print -quit)"
readonly INST_BIN="$INST_VER/Contents/Resources/createinstallmedia"
readonly DST_DIR="${DST_DIR:-$HOME/VirtualBox VMs}"
readonly VM_NAME="${VM_NAME:-macOS-VM}"
readonly VM_DIR="${VM_DIR:-$DST_DIR/$VM_NAME}"
readonly VM_SIZE="${VM_SIZE:-131072}"
readonly VM_RES="${VM_RES:-1680x1050}"
readonly VM_SCALE="${VM_SCALE:-1.0}"
readonly VM_RAM="${VM_RAM:-4096}"
readonly VM_VRAM="${VM_VRAM:-128}"
readonly VM_CPU="${VM_CPU:-2}"
readonly DST_DMG="$DST_DIR/$VM_NAME.dmg"
readonly DST_VOL="/Volumes/$VM_NAME"
readonly DST_ISO="$DST_DIR/$VM_NAME.iso.cdr"
readonly DST_SPARSE="$DST_DIR/$VM_NAME.efi.sparseimage"
readonly DST_SPARSE2="$DST_DIR/$VM_NAME.sparseimage"
readonly FILE_EFI="/usr/standalone/i386/apfs.efi"
readonly HOST_SERIAL="$(ioreg -c IOPlatformExpertDevice -d 2 | awk -F\" '/IOPlatformSerialNumber/{print $(NF-1)}')"
readonly HOST_ID="$(ioreg -l | grep "board-id" | awk -F\" '/board-id/{print $(NF-1)}')"
readonly HOST_UUID="$(ioreg -l -p IODeviceTree | awk -F"\<|>" '/"system-id"/{print $(NF-1)}')"
readonly VM_SYSTEM_FAMILY="$(system_profiler SPHardwareDataType |  awk -F': ' ' /Model Name/ { print $2 } ')"
readonly VM_SYSTEM_PRODUCT="$(system_profiler SPHardwareDataType |  awk -F': ' ' /Model Identifier/ { print $2 } ')"
readonly VM_SYSTEM_UUID="$(system_profiler SPHardwareDataType |  awk -F': ' ' /Hardware UUID/ { print $2 } ')"
readonly VM_SYSTEM_VER="string:1"
readonly VM_SYSTEM_REV="string:.23456"
readonly VM_SYSTEM_BIOS="$(system_profiler SPHardwareDataType |  awk -F': ' ' /Boot ROM Version/ { print $2 } ')"
readonly VM_SYSTEM_SN="$(system_profiler SPHardwareDataType |  awk -F': ' ' /Serial Number \(system\)/ { print $2 } ')"
###############################################################################


# Define methods ##############################################################
debug() {
  echo "DEBUG: $1" >&3
  log "$1"
}

error() {
  echo "ERROR: $1" >&4
  log "$1"
}

info() {
  echo -n "$1" >&3
  log "$1"
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
  info "Running checks..." 0
  result "."
  if [[ ! $HOME == /Users* ]]; then
	error "\$HOME should point to the users home directory. See issue #63."
  fi  
  if [ "$INST_VERS" = "0" ]; then
    error "No macOS installer found at /Applications. Download the installer first (e.g. via 'installinstallmacos.py') - press enter in the terminal when done..."
    read -r
    exit 6
  fi
  if [ ! "$INST_VERS" = "1" ]; then
    error "$INST_VERS macOS installers found at /Applications. Don't know which one to select."
    exit 7
  fi
  if [ ! -d "$INST_VER/Contents/SharedSupport/" ]; then
    error "Partial macOS installer found at /Applications. Download the full installer first (e.g. via 'installinstallmacos.py') - press enter in the terminal when done..."
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
    error "VirtualBox USB 3.0 Extension Pack not installed. Will not install it automatically, due to licensing issues!"
    error "Install e.g. via brew cask install virtualbox-extension-pack"
    exit 4
  fi

  if ! diskutil listFilesystems | grep -q APFS; then
    error "This host does not support required APFS filesystem. You must upgrade to High Sierra or later and try again."
    exit 11
  fi
}

ejectAll() {
  # todo: replace this brute-force error-prone approach by a more coordinated approach

  hdiutil info | grep 'Install macOS' | awk '{print $1}' | while read -r i; do
    hdiutil detach -force "$i" 2>/dev/null || true
  done
  hdiutil info | grep 'OS X Base System' | awk '{print $1}' | while read -r i; do
    hdiutil detach -force "$i" 2>/dev/null || true
  done
  hdiutil info | grep 'InstallESD' | awk '{print $1}' | while read -r i; do
    hdiutil detach -force "$i" 2>/dev/null || true
  done
  hdiutil detach -force "$DST_VOL" 2>/dev/null || true
  hdiutil detach -force /Volumes/EFI 2>/dev/null || true
  find /Volumes/ -maxdepth 1 -name "NO NAME*" -exec hdiutil detach -force {} \; 2>/dev/null || true
}

createImage() {
  version="$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$INST_VER/Contents/Info.plist")"
  info "Creating image '$DST_DMG' (takes a while, version $version, will need sudo)..." 30
  if [ ! -e "$DST_DMG" ]; then
    result "."
    ejectAll
    mkdir -p "$DST_DIR"
    hdiutil create -o "$DST_DMG" -size 16g -layout SPUD -fs HFS+J &&
    hdiutil attach "$DST_DMG" -mountpoint "$DST_VOL" &&
    sudo "$INST_BIN" --nointeraction --volume "$DST_VOL" --applicationpath "$INST_VER" ||
    error "Could create or run installer. Please look in the log file..."
    ejectAll
  else
    result "already exists."
  fi
  info "Creating iso '$DST_ISO'..." 40
  if [ ! -e "$DST_ISO" ]; then
    result "."
    mkdir -p "$DST_DIR"
    hdiutil convert "$DST_DMG" -format UDTO -o "$DST_ISO"
  else
    result "already exists."
  fi
}

patchEFI() {
  info "Adding APFS drivers to EFI in '$DST_DIR/$VM_NAME.efi.vdi'..."
  result "."

  ejectAll

  if [ ! -f "$DST_SPARSE" ]; then
    hdiutil create -size 1m -fs MS-DOS -volname "EFI" "$DST_SPARSE"
  fi

  EFI_DEVICE=$(hdiutil attach -nomount "$DST_SPARSE" 2>&1)
  result="$?"
  if [ "$result" -ne "0" ]; then
    error "Couldn't mount EFI disk: $EFI_DEVICE"
    exit 92
  fi

  EFI_DEVICE=$(echo $EFI_DEVICE|egrep -o '/dev/disk[[:digit:]]{1}' |head -n1)

  # add APFS driver to EFI
  if [ -d "/Volumes/EFI/" ]; then
    error "The folder '/Volumes/EFI/' already exists!"
    exit 94
  fi
  diskutil mount "${EFI_DEVICE}s1"
  mkdir -p /Volumes/EFI/EFI/drivers >/dev/null 2>&1||true
  cp "$FILE_EFI" /Volumes/EFI/EFI/drivers/

  # create startup script to boot macOS or the macOS installer
  cat <<EOT > /Volumes/EFI/startup.nsh
@echo -off
#fixme startup delay
set StartupDelay 0
load "fs0:\EFI\drivers\apfs.efi"
#fixme bcfg driver add 0 "fs0:\\EFI\\drivers\\apfs.efi" "APFS Filesystem Driver"
map -r
echo "Trying to find a bootable device..."
for %p in "macOS Install Data" "macOS Install Data\Locked Files\Boot Files" "OS X Install Data" "Mac OS X Install Data" "System\Library\CoreServices" ".IABootFiles"
  for %d in fs2 fs3 fs4 fs5 fs6 fs1
    if exist "%d:\%p\boot.efi" then
      echo "Booting: %d:\%p\boot.efi ..."
      #fixme: bcfg boot add 0 "%d:\\%p\\boot.efi" "macOS"
      "%d:\%p\boot.efi"
    endif
  endfor
endfor
echo "Failed."
EOT

  # close disk again
  diskutil unmount "${EFI_DEVICE}s1"
  VBoxManage convertfromraw "${EFI_DEVICE}" "$DST_DIR/$VM_NAME.efi.vdi" --format VDI
  diskutil eject "${EFI_DEVICE}"
}

createVM() {
  if [ ! -e "$VM_DIR" ]; then
    mkdir -p "$VM_DIR"
  fi
  info "Creating VM HDD '$DST_DIR/$VM_NAME.vdi' (takes a while)..." 90
  if [ ! -e "$DST_DIR/$VM_NAME.vdi" ]; then
    result "."
    ejectAll
    result "Creating $DST_SPARSE2..."
    if [ ! -e "$DST_SPARSE2" ]; then
      hdiutil create -size "$VM_SIZE"MB -fs "APFS" -volname "macOS" -type SPARSE "$DST_SPARSE2"
      if [ "$?" -ne "0" ]; then
        error "Couldn't create $DST_SPARSE2"
        exit 95
      fi
    else
      result "...already exists"
    fi
    MACOS_DEVICE=$(hdiutil attach -nomount "$DST_SPARSE2" 2>&1)
    if [ "$?" -ne "0" ]; then
      error "Couldn't mount target disk: $MACOS_DEVICE"
      exit
    fi
    MACOS_DEVICE=$(echo $MACOS_DEVICE|egrep -o '/dev/disk[[:digit:]]{1}' |head -n1)
    result "Converting virtual macOS disk: $MACOS_DEVICE"
    VBoxManage convertfromraw "${MACOS_DEVICE}" "$DST_DIR/$VM_NAME.vdi" --format VDI
    diskutil eject "${MACOS_DEVICE}"
  else
    result "already exists."
  fi
  if [ ! -e "$DST_DIR/$VM_NAME.efi.vdi" ]; then
    patchEFI
  fi
  info "Creating VM '$VM_NAME'..." 99
  if ! VBoxManage showvminfo "$VM_NAME" >/dev/null 2>&1; then
    result "."
    VBoxManage createvm --register --name "$VM_NAME" --basefolder "$DST_DIR" --ostype MacOS1013_64
    VBoxManage modifyvm "$VM_NAME" --usbxhci on --memory "$VM_RAM" --vram "$VM_VRAM" --cpus "$VM_CPU" \
      --firmware efi --chipset ich9 --mouse usbtablet --keyboard usb \
      --cpu-profile "Intel Core i7-6700K" --cpuidset 00000001 000106e5 00100800 0098e3fd bfebfbff
    VBoxManage setextradata "$VM_NAME" "CustomVideoMode1" "${VM_RES}x32"
    VBoxManage setextradata "$VM_NAME" VBoxInternal2/EfiGraphicsResolution "$VM_RES"
    VBoxManage setextradata "$VM_NAME" GUI/ScaleFactor "$VM_SCALE"
    VBoxManage setextradata "$VM_NAME" "VBoxInternal/Devices/efi/0/Config/DmiBoardProduct" "string:${HOST_ID}"
    VBoxManage setextradata "$VM_NAME" "VBoxInternal/Devices/efi/0/Config/DmiSystemSerial" "string:${HOST_SERIAL}"
    VBoxManage setextradata "$VM_NAME" "VBoxInternal/Devices/efi/0/Config/DmiSystemFamily" "${VM_SYSTEM_FAMILY}"
    VBoxManage setextradata "$VM_NAME" "VBoxInternal/Devices/efi/0/Config/DmiSystemProduct" "${VM_SYSTEM_PRODUCT}"
    VBoxManage setextradata "$VM_NAME" "VBoxInternal/Devices/efi/0/Config/DmiSystemUuid" "${VM_SYSTEM_UUID}"
    VBoxManage setextradata "$VM_NAME" "VBoxInternal/Devices/efi/0/Config/DmiOEMVBoxVer" "${VM_SYSTEM_VER}"
    VBoxManage setextradata "$VM_NAME" "VBoxInternal/Devices/efi/0/Config/DmiOEMVBoxRev" "${VM_SYSTEM_REV}"
    VBoxManage setextradata "$VM_NAME" "VBoxInternal/Devices/efi/0/Config/DmiBIOSVersion" "${VM_SYSTEM_BIOS}"
    VBoxManage setextradata "$VM_NAME" "VBoxInternal/Devices/efi/0/Config/DmiBoardSerial" "${VM_SYSTEM_SN}"
    VBoxManage setextradata "$VM_NAME" "VBoxInternal/Devices/efi/0/Config/DmiSystemVendor" "Apple Inc."
    VBoxManage setextradata "$VM_NAME" "VBoxInternal/Devices/efi/0/Config/DmiSystemVersion" "1.0"
    VBoxManage setextradata "$VM_NAME" "VBoxInternal/Devices/smc/0/Config/DeviceKey" "ourhardworkbythesewordsguardedpleasedontsteal(c)AppleComputerInc"
    VBoxManage setextradata "$VM_NAME" "VBoxInternal/Devices/smc/0/Config/GetKeyFromRealSMC" 0
    VBoxManage storagectl "$VM_NAME" --name "SATA Controller" --add sata --controller IntelAHCI --hostiocache on --portcount 4
    VBoxManage storageattach "$VM_NAME" --storagectl "SATA Controller" --port 0 --device 0 --type hdd --nonrotational on --medium "$DST_DIR/$VM_NAME.efi.vdi"
    VBoxManage storageattach "$VM_NAME" --storagectl "SATA Controller" --port 1 --device 0 --type hdd --nonrotational on --medium "$DST_DIR/$VM_NAME.vdi"
    addInstaller
    VBoxManage modifyvm "$VM_NAME" --boot1 disk
    VBoxManage modifyvm "$VM_NAME" --boot2 disk
    VBoxManage modifyvm "$VM_NAME" --boot3 dvd
  else
    result "already exists."
  fi
}

runVM() {
  info "Starting VM '$VM_NAME'..." 100
  if ! VBoxManage showvminfo "$VM_NAME" | grep "State:" | grep -i running >/dev/null; then
    result "."
    VBoxManage startvm "$VM_NAME" --type gui
  else
    result "already running."
  fi
}

runClean() {
  rm -f "$FILE_LOG" "$DST_DMG" "$DST_ISO" "$DST_SPARSE" "$DST_SPARSE2" || true
}

waitVM() {
  info "Waiting for VM '$VM_NAME' to shutdown..."
  result "."
  while VBoxManage showvminfo "$VM_NAME"|grep -E "State:.*running" >/dev/null; do
     sleep 5
  done
  true
}

stopVM() {
  info "Press enter to stop the VM and to eject the installer medium (to avoid an installation loop for macOS < 10.16)..."
  result "."
  read
  VBoxManage controlvm "$VM_NAME" poweroff||true
  sleep 5
}

removeInstaller() {
  info "Ejecting installer DVD for VM '$VM_NAME'..."
  result "."
  # Skip installation DVD to boot from new disk
  VBoxManage storageattach "$VM_NAME" --storagectl "SATA Controller" --port 2 --device 0 --type dvddrive --medium emptydrive >/dev/null 2>&1||true
}

download() {
  info "Downloading macOS (need sudo)..."
  result "."
  exec 1>&3
  sudo ./installinstallmacos.py
  info "Please mount the produced .dmg file and move the contained installer to /Applications now."
}

addInstaller() {
  info "Adding installer DVD for VM '$VM_NAME'..."
  result "."
  # Skip installation DVD to boot from new disk
  VBoxManage storageattach "$VM_NAME" --storagectl "SATA Controller" --port 2 --device 0 --type dvddrive --hotpluggable on --medium "$DST_ISO"
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
}

main() {
  while [ "$#" -ne 0 ]; do
    ARG="$1"
    shift # get rid of $1, we saved in ARG already
    case "$ARG" in
    check) runChecks ;;
    clean) runClean ;;
    cleanup) cleanup ;;
    stash) VBoxManage unregistervm --delete "$VM_NAME"||true ;;
    stashvm) VBoxManage storageattach "$VM_NAME" --storagectl "SATA Controller" --port 0 --device 0 --type dvddrive --medium emptydrive >/dev/null 2>&1||true ; VBoxManage unregistervm --delete "$VM_NAME"||true ;;
    installer) createImage ;;
    patch) patchEFI ;;
    vm) createVM ;;
    run) runVM ;;
    wait) waitVM ;;
    stop) stopVM ;;
    eject) removeInstaller ;;
    add) addInstaller ;;
    download) download ;;
    all) runChecks && createImage && createVM && patchEFI && runVM && stopVM && removeInstaller && runVM ;;
    *) echo "Possible commands: clean, stash, all, check, installer, patch, vm, run, stop, wait, eject, add" >&4 ;;
    esac
  done
}
###############################################################################

# Run script ##################################################################
[[ ${BASH_SOURCE[0]} == "${0}" ]] && trap 'cleanup "${?}" "${LINENO}" "${BASH_LINENO}" "${BASH_COMMAND}" $(printf "::%s" ${FUNCNAME[@]:-})' EXIT && main "${@:-}"
###############################################################################
