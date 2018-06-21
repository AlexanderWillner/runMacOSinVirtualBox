SCRIPT=./runMojaveVirtualbox.sh
SHELL=bash

all: help

help:
	@echo "Some available commands:"
	@echo " * image    : create macOS installer image, clover boot image, VM and disk"
	@echo " * clean    : delete generated images and downloaded files"
	@echo " * stash    : delete generated VM and disk"
	@echo " * test     : test shell scripts"
	@echo " * style    : style shell scripts"
	@echo " * harden   : harden shell scripts"
	@echo " * feedback : create a GitHub issue"

image:
	@bash $(SCRIPT)

clean:
	@bash  $(SCRIPT) clean

stash:
	@bash  $(SCRIPT) stash

feedback:
	@open https://github.com/alexanderwillner/runMacOSinVirtualBox/issues
		
test: check
	@echo "Running first round of shell checks..."
	@shellcheck -x *.sh
	@echo "Running second round of shell checks..."
	@shellharden --check runMojaveVirtualbox.sh

harden: check
	@shellharden --replace runMojaveVirtualbox.sh
	
style: check
	@shfmt -i 2 -w -s *.sh

check:
	@type shellcheck >/dev/null 2>&1 || (echo "Run 'brew install shellcheck' first." >&2 ; exit 1)
	@type shellharden >/dev/null 2>&1 || (echo "Run 'brew install shellharden' first." >&2 ; exit 1)
	@type shfmt >/dev/null 2>&1 || (echo "Run 'brew install shfmt' first." >&2 ; exit 1)

.PHONY: image clean feedback test harden style check
