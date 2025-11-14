#!/bin/bash

if [ $# -eq 0 ]; then
    echo "Usage: $(basename $0) [package | log <submit_id>]" > /dev/stderr
    exit 1
fi

if ! [ -n "${DEV_ID_APP}" ] || ! [ -n "${DEV_ID_INST}" ] ||
   ! [ -n "${DEV_KEY_PROF}" ]; then
    echo "Please set these variables in your environment for code signing:"
    echo "    DEV_ID_APP"
    echo "    DEV_ID_INST"
    echo "    DEV_KEY_PROF"
    echo "Examples:"
    echo '    DEV_ID_APP="Developer ID Application: <your_name> (<team_id>)"'
    echo '    DEV_ID_INST="Developer ID Installer: <your_name> (<team_id>)"'
    echo '    DEV_KEY_PROF="<password_label>"'
    echo -n "password_label is for an app-specific password stored "
    echo "in the notarytool:"
    echo '    xcrun notarytool store-credentials "MY_PASSWORD" \'
    echo '    --apple-id <your_apple_id> --team-id <team_id> \'
    echo -n '    --password <app-specific password from appleid.apple.com>'
    echo " (no quotes)"
    exit 1
fi

ACTION=$1
SUBMIT_ID=$2
SA_VERSION=$(cat StandaloneHost.xcodeproj/project.pbxproj | \
             grep -m1 'MARKETING_VERSION' | cut -d'=' -f2 | \
             tr -d ';' | tr -d ' ')
SAU_VERSION=$(cat ../StandaloneHostUpdater/StandaloneHostUpdater.xcodeproj/project.pbxproj | grep -m1 'MARKETING_VERSION' | cut -d'=' -f2 | tr -d ';' | tr -d ' ')

SA_ENTITLEMENTS="StandaloneHost/StandaloneHost.entitlements"
SA_APP=./Archives/StandaloneHost.xcarchive/Products/Applications/StandaloneHost.app

if [ "${ACTION}" == "package" ]; then
    # Remove previous artifacts
    rm -f *.pkg
    rm -rf tmp_*
    rm -f log.json

    # Copy components
    mkdir tmp_app
    cp -r ${SA_APP} tmp_app

    # Sign app
    codesign -s "${DEV_ID_APP}" -f --timestamp -o runtime \
        --entitlements "${SA_ENTITLEMENTS}" tmp_app/StandaloneHost.app

    # Build component package
    pkgbuild --root tmp_app --identifier com.larrymtaylor.StandaloneHost \
        --version ${SA_VERSION} --install-location /Applications \
        --min-os-version 10.13 --component-plist app.plist \
        --scripts Scripts sa_app.pkg

    pushd ../StandaloneHostUpdater > /dev/null

    SAU_ENTITLEMENTS="StandaloneHostUpdater.entitlements"
    SAU_APP=./Archives/StandaloneHostUpdater.xcarchive/Products/Applications/StandaloneHostUpdater.app

    # Remove previous artifacts
    rm -f *.pkg
    rm -rf tmp_*

    # Copy components
    mkdir tmp_app
    cp -r ${SAU_APP} tmp_app

    # Sign app
    codesign -s "${DEV_ID_APP}" -f --timestamp -o runtime \
        --entitlements "${SAU_ENTITLEMENTS}" tmp_app/StandaloneHostUpdater.app

    # Build component package
    pkgbuild --root tmp_app \
        --identifier com.larrymtaylor.StandaloneHostUpdater \
        --version ${SAU_VERSION} --install-location /Applications \
        --min-os-version 10.13 --component-plist app.plist app.pkg

    popd > /dev/null

    # Build installer package
    cp -f ../StandaloneHostUpdater/app.pkg sau_app.pkg
    cat distribution.plist | sed "s/SA_VERSION/${SA_VERSION}/" > distx.plist
    cat distx.plist | sed "s/SAU_VERSION/${SAU_VERSION}/" > dist.plist
    productbuild --sign "${DEV_ID_INST}" --distribution dist.plist \
        --product requirements.plist StandaloneHost.pkg

    # If you are using nested containers, only notarize the outermost 
    # container.  For example, if you have an app inside an installer 
    # package on a disk image, sign the app, sign the installer package,
    # and sign the disk image, but only notarize the disk image.

    # Upload for notarization
    xcrun notarytool submit StandaloneHost.pkg --keychain-profile \
        ${DEV_KEY_PROF} --wait

    # Staple notary ticket to product
    xcrun stapler staple StandaloneHost.pkg
elif [ "${ACTION}" == "log" ]; then
    # Download notarization log file
    xcrun notarytool log ${SUBMIT_ID} --keychain-profile ${DEV_KEY_PROF} \
        log.json
else
    echo "Invalid action ${ACTION}"
    exit 1
fi

exit 0
