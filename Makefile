PROJECT   = src/ZoomacIt.xcodeproj
SCHEME    = ZoomacIt
TEST_SCHEME = ZoomacItTests
DERIVED   = $(HOME)/Library/Developer/Xcode/DerivedData/ZoomacIt-*

.PHONY: build test run release clean generate

build:
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration Debug build

test:
	xcodebuild -project $(PROJECT) -scheme $(TEST_SCHEME) -configuration Debug test

run: build
	open $(DERIVED)/Build/Products/Debug/ZoomacIt.app

release:
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration Release build

clean:
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration Debug clean
	rm -rf build

generate:
	cd src && xcodegen generate