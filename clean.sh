#!/bin/bash

rm -f *.log
rm -rf build
rm -f *.pkg
rm -f dist.plist
rm -f distx.plist
rm -rf tmp_*
rm -f log.json
rm -rf Archives
rm -rf Packages
pushd ../StandaloneHostUpdater > /dev/null
rm -f *.log
rm -rf build
rm -f app.pkg
rm -rf tmp_*
rm -rf Archives
popd > /dev/null
