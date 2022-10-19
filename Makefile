SCRIPT=./runMacOSVirtualbox.sh
SHELL=bash

help:
	@echo "Some available commands:"
	@echo " * all      : run everything needed (check, installer, vm, patch, run, stop, eject)"
	@echo " * download : download a macOS installer"
	@echo " * check    : check environment"
	@echo " * installer: create macOS installer image"
	@echo " * patch    : add APFS drivers to VM EFI to boot"
	@echo " * vm       : create VM and disk"
	@echo " * run      : run VM"
	@echo " * stop     : stop VM"
	@echo " * wait     : wait for VM to stop"
	@echo " * eject    : eject installer medium"
	@echo " * add      : add installer medium"
	@echo " * clean    : delete generated images and downloaded files"
	@echo " * stash    : delete generated VM and disk"
	@echo " * stashvm  : delete generated VM and NOT the disk"
	@echo " * test     : test shell scripts"
	@echo " * style    : style shell scripts"
	@echo " * harden   : harden shell scripts"
	@echo " * release  : make new release"
	@echo " * feedback : create a GitHub issue"

all:
	@bash  $(SCRIPT) all

download:
	@bash  $(SCRIPT) download

check:
	@bash  $(SCRIPT) check

installer:
	@bash  $(SCRIPT) installer

patch:
	@bash  $(SCRIPT) patch

vm:
	@bash  $(SCRIPT) vm

run:
	@bash  $(SCRIPT) run

stop:
	@bash  $(SCRIPT) stop

wait:
	@bash  $(SCRIPT) wait

eject:
	@bash  $(SCRIPT) eject

add:
	@bash  $(SCRIPT) add

clean:
	@bash  $(SCRIPT) clean

stash:
	@bash  $(SCRIPT) stash

stashvm:
	@bash  $(SCRIPT) stashvm

feedback:
	@open https://github.com/alexanderwillner/runMacOSinVirtualBox/issues
		
test: dependencies
	@echo "Running first round of shell checks..."
	@shellcheck -x *.sh
	@echo "Running second round of shell checks..."
	@shellharden --check runMacOSVirtualbox.sh

harden: dependencies
	@shellharden --replace runMacOSVirtualbox.sh
	
style: dependencies
	@shfmt -i 2 -w -s *.sh

dependencies:
	@type shellcheck >/dev/null 2>&1 || (echo "Run 'brew install shellcheck' first." >&2 ; exit 1)
	@type shellharden >/dev/null 2>&1 || (echo "Run 'brew install shellharden' first." >&2 ; exit 1)
	@type shfmt >/dev/null 2>&1 || (echo "Run 'brew install shfmt' first." >&2 ; exit 1)

release:
	@cp runMacOSVirtualbox.sh app/runMacOSVirtualbox.app/Contents/Resources/
	@cd app; rm -f runMacOSVirtualbox.app.zip || true
	@cd app; zip -r runMacOSVirtualbox.app.zip runMacOSVirtualbox.app/
	@open app
	@open https://github.com/AlexanderWillner/runMacOSinVirtualBox/releases

.PHONY: all clean feedback test harden style check release
