dev:
	swiftc autolift.swift

release:
	swiftc -O autolift.swift

test:
	./autolift --test

clean:
	rm autolift
