info:
	swiftc --version
	make --version

dev:
	swiftc autolift.swift

release:
	swiftc -O autolift.swift -o autolift

test:
	./autolift --test

clean:
	rm autolift
