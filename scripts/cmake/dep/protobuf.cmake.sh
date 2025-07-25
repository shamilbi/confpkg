#!/bin/bash

PkgHome="https://github.com/protocolbuffers/protobuf"

# REQ: abseil-cpp

ConfigureOpts+=(
    # Slackware
    #-DCMAKE_C_FLAGS="$SLKCFLAGS"
    #-DCMAKE_CXX_FLAGS="$SLKCFLAGS"
    #-DCMAKE_INSTALL_PREFIX=/usr
    #-DCMAKE_INSTALL_LIBDIR="lib$LIBDIRSUFFIX"
    #-DDOC_INSTALL_DIR="doc"
    #-DMAN_INSTALL_DIR=/usr/man
    -Dprotobuf_BUILD_TESTS=OFF
    -Dprotobuf_ABSL_PROVIDER=package # abseil-cpp
    -Dprotobuf_BUILD_SHARED_LIBS=ON

    -Dprotobuf_JSONCPP_PROVIDER=package # module, Provider of jsoncpp library
)

pkg_pre_configure() {
    local i j sed1 sed2

    # Slackware
    # soversion.patch
    #      VERSION ${protobuf_VERSION}
    # +    SOVERSION ${protobuf_VERSION_MINOR}
    sed1='^( *)(VERSION \$\{protobuf_VERSION\})'
    sed2='\1\2\n\1SOVERSION ${protobuf_VERSION_MINOR}'
    for i in libprotobuf libprotobuf-lite libprotoc; do
        j=$OrigSrcDir/cmake/$i.cmake
        if ! grep -q 'SOVERSION \${protobuf_VERSION_MINOR}' "$j"; then
            sed -i -r -e "s,$sed1,$sed2," "$j"
        fi
    done
}
