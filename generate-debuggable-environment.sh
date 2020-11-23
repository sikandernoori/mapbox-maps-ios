#!/bin/bash

# Update submodules
git submodule update --init --recursive

# Create xcodeproj for gl-native-internal
cd mapbox-gl-native-internal
mkdir -p build/ios 
cd build/ios
cmake ../.. -DBUILD_SHARED_LIBS=OFF -DCMAKE_ARCHIVE_OUTPUT_DIRECTORY="./lib" -DCMAKE_BUILD_TYPE=Release -DCMAKE_OSX_SYSROOT=iphonesimulator -DCMAKE_SYSTEM_NAME=iOS -DMAPBOX_COMMON_BUILD_TYPE='SHARED' -DMAPBOX_COMMON_TARGET_NAME='MapboxCommon' -DMAPBOX_ENABLE_FRAMEWORK=ON -DMBGL_WITH_IOS_CCACHE=ON -DMBGL_WITH_METAL=ON -GXcode
cd ../../../

# Make the deps in carbon
cd mapbox-maps-ios
make deps
cd ..

# Open the workspace
xed Umbrella.xcworkspace
