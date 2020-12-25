#!/bin/bash


brew bundle --file=./Brewfile

carthage bootstrap --platform macOS
