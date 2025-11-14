#!/bin/bash

SA_VERSION=$(cat StandaloneHost.xcodeproj/project.pbxproj | \
             grep -m1 'MARKETING_VERSION' | cut -d'=' -f2 | \
             tr -d ';' | tr -d ' ')
ARCHIVE_DIR=/Users/Larry/Library/Developer/Xcode/Archives/CommandLine
mkdir -p Archives

rm -f make.log
touch make.log

echo "Building StandaloneHost" 2>&1 | tee -a make.log

xcodebuild -project StandaloneHost.xcodeproj \
    clean 2>&1 | tee -a make.log
xcodebuild -project StandaloneHost.xcodeproj \
    -scheme "StandaloneHost Release" \
    -archivePath Archives/StandaloneHost.xcarchive \
    archive 2>&1 | tee -a make.log

rm -rf ${ARCHIVE_DIR}/StandaloneHost-v${SA_VERSION}.xcarchive
cp -rf Archives/StandaloneHost.xcarchive \
    ${ARCHIVE_DIR}/StandaloneHost-v${SA_VERSION}.xcarchive

pushd ../StandaloneHostUpdater > /dev/null

SAU_VERSION=$(cat StandaloneHostUpdater.xcodeproj/project.pbxproj | \
              grep -m1 'MARKETING_VERSION' | cut -d'=' -f2 | \
              tr -d ';' | tr -d ' ')

rm -f make.log
touch make.log

echo "Building StandaloneHostUpdater" 2>&1 | tee -a make.log

xcodebuild -project StandaloneHostUpdater.xcodeproj \
    clean 2>&1 | tee -a make.log
xcodebuild -project StandaloneHostUpdater.xcodeproj \
    -scheme "StandaloneHostUpdater" \
    -archivePath Archives/StandaloneHostUpdater.xcarchive \
    archive 2>&1 | tee -a make.log

rm -rf ${ARCHIVE_DIR}/StandaloneHostUpdater-v${SAU_VERSION}.xcarchive
cp -rf Archives/StandaloneHostUpdater.xcarchive \
    ${ARCHIVE_DIR}/StandaloneHostUpdater-v${SAU_VERSION}.xcarchive

popd > /dev/null

