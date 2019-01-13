SCRIPT=./runMojaveVirtualbox.sh
SHELL=bash

help:
	@echo "Some available commands:"
	@echo " * all      : run everything needed (check, installer, vm, patch, run, stop, eject)"
	@echo " * check    : check environment"
	@echo " * installer: create macOS installer image"
	@echo " * clover   : create clover boot image"
	@echo " * patch    : add APFS drivers to VM EFI to boot w/o clover"
	@echo " * vm       : create VM and disk"
	@echo " * run      : run VM"
	@echo " * stop     : stop VM"
	@echo " * wait     : wait for VM to stop"
	@echo " * eject    : eject installer medium"
	@echo " * clean    : delete generated images and downloaded files"
	@echo " * stash    : delete generated VM and disk"
	@echo " * test     : test shell scripts"
	@echo " * style    : style shell scripts"
	@echo " * harden   : harden shell scripts"
	@echo " * release  : make new release"
	@echo " * feedback : create a GitHub issue"

all:
	@bash  $(SCRIPT) all

check:
	@bash  $(SCRIPT) check

installer:
	@bash  $(SCRIPT) installer

clover:
	@bash  $(SCRIPT) clover

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

clean:
	@bash  $(SCRIPT) clean

stash:
	@bash  $(SCRIPT) stash

feedback:
	@open https://github.com/alexanderwillner/runMacOSinVirtualBox/issues
		
test: dependencies
	@echo "Running first round of shell checks..."
	@shellcheck -x *.sh
	@echo "Running second round of shell checks..."
	@shellharden --check runMojaveVirtualbox.sh

harden: dependencies
	@shellharden --replace runMojaveVirtualbox.sh
	
style: dependencies
	@shfmt -i 2 -w -s *.sh

dependencies:
	@type shellcheck >/dev/null 2>&1 || (echo "Run 'brew install shellcheck' first." >&2 ; exit 1)
	@type shellharden >/dev/null 2>&1 || (echo "Run 'brew install shellharden' first." >&2 ; exit 1)
	@type shfmt >/dev/null 2>&1 || (echo "Run 'brew install shfmt' first." >&2 ; exit 1)

release:
	@cp runMojaveVirtualbox.sh app/RunMojaveVirtualbox.app/Contents/Resources/
	@cd app; rm -f RunMojaveVirtualbox.app.zip || true
	@cd app; zip -r RunMojaveVirtualbox.app.zip RunMojaveVirtualbox.app/
	@open app
	@open https://github.com/AlexanderWillner/runMacOSinVirtualBox/releases

.PHONY: all clean feedback test harden style check release
