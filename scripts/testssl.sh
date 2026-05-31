#!/bin/bash

PkgHome="https://github.com/testssl/testssl.sh/tags"

name=${Name,,}
prefix=/opt/"$name"
prefix2=$DestDir$prefix

unset -v pkg_configure pkg_make

pkg_install() {
    pkg_install_mfd 755 "$name" "$prefix2"/bin
    pkg_cp_fd etc "$prefix2"
    pkg_install_mff 755 "$Prefix2/bin/$name" <<EOF
#!/bin/bash
exec /usr/bin/env TESTSSL_INSTALL_DIR="$prefix" "$prefix/bin/$name" "\$@"
EOF
    pkg_install_mfd 644 doc/testssl.1 "$ManDir2"/man1
}
