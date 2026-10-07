.PHONY: build app run install clean

build:
	swift build

app:
	./scripts/bundle.sh

run: app
	open build/ActionsBar.app

install: app
	pkill -x ActionsBar || true
	rm -rf /Applications/ActionsBar.app
	cp -R build/ActionsBar.app /Applications/
	open /Applications/ActionsBar.app

clean:
	rm -rf .build build
