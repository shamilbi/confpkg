#!/bin/bash

. "$Home/functions.sh" || exit 1

# installpkg dirs
PkgsAdmDir=/var/lib/pkgtools
PkgsLogDir=/var/log/pkgtools
PkgsDir=$PkgsAdmDir/packages
PkgsScriptsDir=$PkgsAdmDir/scripts
# confpkg dir
PkgsLddDir=$PkgsAdmDir/ldd

X=1
WAYLAND=1
ALSA=1
WEBKIT=
DOC=1 # /usr/doc
GTK_DOC= # /usr/share/gtk-doc

PULSE=
PIPEWIRE=1
JACK=
AALIB=

SELINUX=
AUDIT=

Arch=$(uname -m)
Host="$Arch-slackware-linux"

LibSuffix=
[[ $Arch = "x86_64" ]] && LibSuffix="64"
LibName=lib$LibSuffix
LibDir=/usr/$LibName

PAM=
if [[ -L /$LibName/libpam.so ]]; then
    PAM=1
fi

ELOGIND=
if [[ -x /$LibName/elogind/elogind ]]; then
    ELOGIND=1
fi

Prefix=/usr
Etc=/etc
ShareDir=/usr/share
IncludeDir=/usr/include
FontsDir=/usr/share/fonts
PerlLibDir=$LibDir/perl5
GoDir=$LibDir/go
ManDir=/usr/man
InfoDir=/usr/info
DocDir0=/usr/doc

Python=python3
#BuildForPython=(python3.11 python3.12)
BuildForPython=(python3)

_find_utils() {
    local i

    # Editor
    for i in vim vi; do
        if [[ $(command -v $i) ]]; then
            Editor=$i
            break
        fi
    done

    # Pager
    for i in less more; do
        if [[ $(command -v $i) ]]; then
            Pager=$i
            break
        fi
    done
}
_find_utils
unset -f _find_utils

pkg_check= # make check
pkg_strip=1 # strip files after install

PATH=$PATH:/usr/sbin:/sbin
export PATH

UserCacheDir=~/.cache/confpkg
