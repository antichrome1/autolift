SCRATCH ?= .build
PREFIX  ?= /usr/local/bin

info:
	swiftc --version
	make --version

release:
	swiftc -O autolift.swift

install:
	sudo mv autolift $(PREFIX)

release-nix:
	nix-build

install-nix:
	sudo install -m755 result/bin/autolift $(PREFIX)/autolift

dev:
	swiftc autolift.swift

test:
	./autolift --test

clean:
	rm autolift
