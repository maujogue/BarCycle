APP_NAME = BarCycle

.PHONY: all build run clean

all: build

build:
	./build.sh

run: build
	open $(APP_NAME).app

clean:
	rm -rf $(APP_NAME).app BarCycle dist

fmt:
	# No-op: Swift formatting is handled by Xcode or swift-format if configured

open:
	open $(APP_NAME).app