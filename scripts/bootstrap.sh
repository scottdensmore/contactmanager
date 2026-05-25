#!/bin/bash


brew bundle --file=./Brewfile

XCODE_XCCONFIG_FILE="$(pwd)/carthage.xcconfig" carthage bootstrap --platform macOS

