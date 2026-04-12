PROJECT      = src/ZoomacIt.xcodeproj
SCHEME       = ZoomacIt
TEST_SCHEME  = ZoomacItTests
BUILD_DIR    = $(CURDIR)/build
APP_NAME     = ZoomacIt
RELEASE_APP  = $(BUILD_DIR)/Build/Products/Release/$(APP_NAME).app
ENTITLEMENTS = $(CURDIR)/src/ZoomacIt/Resources/ZoomacIt-Release.entitlements
VERSION     ?= 0.0.0

# Load secrets from .env (if present)
-include .env
export

.PHONY: build test run release clean generate notarize dmg docs docs-build

build:
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration Debug -derivedDataPath $(BUILD_DIR) build

test:
	xcodebuild -project $(PROJECT) -scheme $(TEST_SCHEME) -configuration Debug -derivedDataPath $(BUILD_DIR) test

run: build
	open $(BUILD_DIR)/Build/Products/Debug/$(APP_NAME).app

release:
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration Release -derivedDataPath $(BUILD_DIR) \
		CODE_SIGN_IDENTITY="Developer ID Application: $(DEVELOPER_NAME) ($(TEAM_ID))" \
		CODE_SIGN_STYLE=Manual \
		DEVELOPMENT_TEAM=$(TEAM_ID) \
		OTHER_CODE_SIGN_FLAGS="--timestamp --options=runtime" \
		CODE_SIGN_ENTITLEMENTS=$(ENTITLEMENTS) \
		CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO \
		build

notarize: release
	@test -n "$(APPLE_ID)" || (echo "Error: APPLE_ID not set. Check .env file." && exit 1)
	@test -n "$(TEAM_ID)" || (echo "Error: TEAM_ID not set. Check .env file." && exit 1)
	@test -n "$(APP_PASSWORD)" || (echo "Error: APP_PASSWORD not set. Check .env file." && exit 1)
	@echo "--- Storing notarytool credentials ---"
	xcrun notarytool store-credentials "notarytool-profile" \
		--apple-id "$(APPLE_ID)" \
		--team-id "$(TEAM_ID)" \
		--password "$(APP_PASSWORD)"
	@echo "--- Creating ZIP for notarization ---"
	cd $(dir $(RELEASE_APP)) && ditto -c -k --keepParent $(APP_NAME).app $(APP_NAME)-notarize.zip
	@echo "--- Submitting for notarization (this may take several minutes) ---"
	xcrun notarytool submit $(dir $(RELEASE_APP))$(APP_NAME)-notarize.zip \
		--keychain-profile "notarytool-profile" --wait
	@echo "--- Stapling notarization ticket ---"
	xcrun stapler staple $(RELEASE_APP)
	@echo "--- Notarization complete ---"

dmg: notarize
	@echo "--- Creating DMG ---"
	rm -rf $(BUILD_DIR)/dmg-staging $(BUILD_DIR)/$(APP_NAME)-v$(VERSION).dmg
	mkdir -p $(BUILD_DIR)/dmg-staging
	cp -R $(RELEASE_APP) $(BUILD_DIR)/dmg-staging/
	ln -s /Applications $(BUILD_DIR)/dmg-staging/Applications
	hdiutil create \
		-volname "$(APP_NAME)" \
		-srcfolder $(BUILD_DIR)/dmg-staging \
		-ov -format UDZO \
		$(BUILD_DIR)/$(APP_NAME)-v$(VERSION).dmg
	rm -rf $(BUILD_DIR)/dmg-staging
	@echo "--- DMG created: $(BUILD_DIR)/$(APP_NAME)-v$(VERSION).dmg ---"

clean:
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration Debug -derivedDataPath $(BUILD_DIR) clean
	rm -rf $(BUILD_DIR)

generate:
	cd src && xcodegen generate

docs:
	cd docs && npm run docs:dev

docs-build:
	cd docs && npm run docs:build
