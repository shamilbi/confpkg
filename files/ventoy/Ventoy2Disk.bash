#!/bin/bash

main2() {
    local curver
    if [[ -f ./ventoy/version ]]; then
        curver=$(cat ./ventoy/version) 
    fi

    case "$(uname -m)" in
        aarch64|arm64)
            export TOOLDIR=aarch64
            ;;
        x86_64|amd64)
            export TOOLDIR=x86_64
            ;;
        mips64)
            export TOOLDIR=mips64el
            ;;
        *)
            export TOOLDIR=i386
            ;;
    esac
    export PATH="./tool/$TOOLDIR:$PATH"


    echo ''
    echo '**********************************************'
    echo "      Ventoy: $curver  $TOOLDIR"
    echo "      longpanda admin@ventoy.net"
    echo "      https://www.ventoy.net"
    echo '**********************************************'
    echo ''


    if [[ ! -f ./boot/boot.img ]]; then
        if [[ -d ./grub ]]; then
            echo "Don't run Ventoy2Disk.sh here, please download the released install package, and run the script in it."
        else
            echo "Please run under the correct directory!" 
        fi
        exit 1
    fi

    echo "############# Ventoy2Disk $* [$TOOLDIR] ################" >> "$log"
    date -R >> "$log"

    "$BASH" ./tool/VentoyWorker.sh "$@"
}

main() {
    local f d
    f=$(realpath "$0") || return 1
    d=$(dirname "$f") || return 1

    log=~/$(basename "$f").tmp
    >"$log" || return 1
    export log

    (cd "$d" || exit 1
        main2 "$@"
    )
}

main "$@"
