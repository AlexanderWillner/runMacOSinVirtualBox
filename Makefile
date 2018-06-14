SCRIPT=./runMojaveVirtualbox.sh
SHELL=bash

all: help

help:
	@echo "Some available commands:"
	@echo " * image    : create macOS installer, clover image and VM"
	@echo " * clean    : delete generated images and VM"
	@echo " * test     : run some tests"
	@echo " * style    : style bash scripts"
	@echo " * harden   : harden bash scripts"
	@echo " * feedback : create a GitHub issue"

image:
	@bash $(SCRIPT)

clean:
	@bash  $(SCRIPT) clean

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
