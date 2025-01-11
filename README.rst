confpkg
=======

`confpkg` is a utility and a collection of bash-scripts to configure, build, and create txz-packages for Slackware Linux.
It's designed to be run by an ordinary user with the help of `fakeroot`_.

Usage
-----

.. code-block:: sh

    tar xf package-1.2.3.tar.gz    # unzip a source package
    confpkg all package-1.2.3      # configure, make and create binary package-1.2.3.txz
    confpkg installpkg package-1.2.3.txz # if $USER in group wheel and group wheel in /etc/sudoers

Installation
------------

#.  install `fakeroot`_ from source

    .. code-block:: sh

        # source
        wget https://deb.debian.org/debian/pool/main/f/fakeroot/fakeroot_1.31.orig.tar.gz
        tar xf fakeroot_1.31.orig.tar.gz    # fakeroot-1.31/
        cd fakeroot-1.31
        # patches
        wget https://deb.debian.org/debian/pool/main/f/fakeroot/fakeroot_1.31-1.2.debian.tar.xz
        tar xf fakeroot_1.31-1.2.debian.tar.xz  # debian/
        while IFS= read -r patch; do
            patch -p1 <debian/patches/"$patch"
        done < <(cat debian/patches/series)
        # compile and install
        ./configure --prefix=/usr --libdir=/usr/lib64 \
            --mandir=/usr/man --docdir=/usr/doc/fakeroot-1.31 \
            --disable-static &&
            make && sudo make install
        # check
        fakeroot bash -c 'whoami'   # root

#.  install confpkg

    .. code-block:: sh

        mkdir -p ~/apps/confpkg
        git clone https://github.com/shamilbi/confpkg ~/apps/confpkg

        ln -sfn ~/apps/confpkg/confpkg ~/bin/   # if ~/bin in your PATH
        # or
        ln -sfn ~/apps/confpkg/confpkg ~/.local/bin/   # if ~/.local/bin in your PATH

Differences with `pkgtools`
---------------------------

#. All scripts are written for bash version 5 or higher, utilizing arrays and `[[...]]`
   blocks whenever possible.

#. The txz file includes an additional file located at /var/lib/pkgtools/ldd/`<package>`,
   which contains the output of running `ldd` (actually, `objdump -p`) on all binary files
   within the package (executed by a regular user, not root).
   This information is useful for tracking dependencies.

#. installpkg: The txz file is extracted to a temporary directory (/var/lib/pkgtools/setup/tmp/XXXXXX)
   rather than directly to the root directory (/).
   From this temporary location, all files except for links are copied to the root directory,
   followed by the copying of the links.
   Finally, the install/doinst.sh script is executed in the root directory, similar to the process in pkgtools.

   The file /var/lib/pkgtools/packages/`<package>` contains ALL files from the package, including links.

   To avoid being deleted by slackpkg, package names in /var/lib/pkgtools/packages/ must be different
   from the standard Slackware package names.  For example:

    * Slackware: fmt-11.1.1-x86_64-1
    * confpkg: fmt-11.1.1 

.. _fakeroot: https://packages.debian.org/bookworm/fakeroot
