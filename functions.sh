#!/bin/bash

pkg_echo() {
    # Printing the value of a variable
    # https://www.etalabs.net/sh_tricks.html
    printf '%s\n' "$@"
}

pkg_check_pkgname() {
    local name=$1
    if [[ ! $name ]]; then
        pkg_log "empty pkgname"
        return 1
    fi
    while :; do
        case $name in
            *.gz | *.xz | *.bz2 | *.tar)
                name=${name%.*}
                ;;
            *)
                break
                ;;
        esac
    done
    local pkgs_file=$PkgsDir/$name
    if [[ ! -f $pkgs_file ]]; then
        pkg_log "file not found: $pkgs_file"
        return 1
    fi
    pkg_echo "$name"
}

pkg_dir_empty() {
    local dir=$1
    #[[ $dir && ! -e $dir ]] || [[ $dir && -d $dir && ! $(ls -A "$dir"/ | head -1) ]]
    [[ $dir && ! -e $dir ]] || [[ $dir && -d $dir && ! $(find "$dir" -mindepth 1 -print -quit) ]]
}

pkg_gitmodules_get() {
    # $0 .gitmodules url 'filter'
    local file=$1   # .gitmodules
    local attr=$2   # url, branch
    local filter=$3 # any string for grep -F
    [[ ! $attr || ! -r $file ]] && return 1
    git config --file "$file" --get-regexp "$attr" | grep -F "$filter" |
        awk '{print $2}' | head -1
}

pkg_log() {
    pkg_echo "${FUNCNAME[1]}: $*" >&2
}

pkg_unrpm_fd() { # unzip rpm -> dir
    local f=$1
    local d=$2
    if [[ ! $f || ! -f $f ]]; then
        pkg_log "file not found: $f"
        return 1
    fi
    local cpio=(cpio -idm)
    if [[ $d ]]; then
        if [[ ! -d $d ]]; then
            mkdir -p "$d" || return 1
        fi
        cpio+=(-D "$d")
    fi
    rpm2cpio "$f" | "${cpio[@]}"
}

pkg_autoconf_version() {
    local s
    s=$(autoconf --version | head -1) || return 1
    if [[ $s =~ (^autoconf .* ([0-9.]+)$) ]]; then
        pkg_echo "${BASH_REMATCH[2]}"
        return 0
    fi
    return 1
}

pkg_replace_autoconf_version() {
    local f=$1
    [[ ! $f ]] && f="configure.ac"
    if [[ ! $f ]]; then
        pkg_echo "file not found: $f"
        return 1
    fi
    local ac
    ac=$(pkg_autoconf_version) || return 1
    if pkg_create_orig "$f"; then
        sed -i -e 's,^AC_PREREQ([0-9.]*)$,AC_PREREQ('"$ac"'),' "$f"
    fi
}

pkg_check_group() {
    local group=$1
    local gid=$2
    if [[ ! $(getent group "$group") ]]; then
        local opt=("groupadd")
        [[ $gid ]] && opt+=(-g "$gid")
        opt+=("$group")
        cat <<END
group not found: $group
to add group: ${opt[@]}
END
        return 1
    fi
}

pkg_check_user() {
    local user=$1
    local group=$2
    local uid=$3
    local userHome=$4
    local userShell=$5
    local userComment=$6
    if [[ ! $(getent passwd "$user") ]]; then
        local opt=("useradd" -g "$group")
        [[ $uid ]] && opt+=(-u "$uid")
        [[ $userHome ]] && opt+=(-d "$userHome")
        [[ $userShell ]] && opt+=(-s "$userShell")
        [[ $userComment ]] && opt+=(-c "$userComment")
        opt+=("$user")
        cat <<END
user not found: $user
to add user: ${opt[@]}
END
        return 1
    fi
}

pkg_kernel_src_dir() {
    KernelSrcDir="/lib/modules/$(uname -r)/build"
    if [[ ! -d $KernelSrcDir ]]; then
        # new kernel
        KernelSrcDir=$(pkg_last_dir /usr/src 'linux-*[0-9]')
        if [[ ! -d $KernelSrcDir ]]; then
            pkg_echo "kernel source not found"
            unset KernelSrcDir
            return 1
        fi
    elif [[ -L $KernelSrcDir ]]; then
        KernelSrcDir=$(readlink "$KernelSrcDir")
    fi
    KernelSrcVersion=$(basename "$KernelSrcDir")
    KernelSrcVersion=${KernelSrcVersion##*-}
    # linux-5.4.12 --> 5.4.12
    return 0
}

pkg_last_dir() {
    # pkg_last_dir <dir> <mask>
    # pkg_last_dir /usr/src 'linux-*'
    local d=$1
    [[ ! -d $d ]] && return 1
    local mask=$2
    [[ ! $mask ]] && mask="*"
    local d2
    d2=$(find "$d" -mindepth 1 -maxdepth 1 -type d -name "$mask" |
        while IFS= read -r d; do
            stat=$(stat -c '%Y' "$d")
            pkg_echo "$stat $d"
        done | sort -r | head -1 | awk '{print $2}')
    pkg_echo "$d2"
}

pkg_patch_f() {
    local f=$1
    local p=$2
    local d=$3
    shift 3

    if [[ ! -f $f ]]; then
        pkg_log "file not exist: $f"
        return 1
    fi

    local cat=(cat)
    if [[ $f = *.gz ]]; then
        cat=(gzip -dc)
    fi

    echo "-----------------------"
    pkg_log "patching $f (${cat[@]} $*) ..."
    "${cat[@]}" "$f" | patch -p"$p" -d "$d" "$@" || return 1
    # $*: -R
}

pkg_patch_f2() {
    # patch in current dir
    local f=$1
    local p=$2
    shift 2

    local fn
    fn=$(basename "$f") || {
        pkg_log "bad filename: $f"
        return 1
    }
    if [[ ! -f $fn.tmp ]]; then
        pkg_patch_f "$f" "$p" . --verbose "$@" || return 1
        touch "$fn.tmp"
    fi
}

pkg_patch_f3() {
    # patch to $OrigSrcDir
    local f=$1 # relative to $SupportDir
    local p=$2
    shift 2

    local fn
    fn=$(basename "$f") || {
        pkg_log "bad filename: $f"
        return 1
    }
    local f2=$OrigSrcDir/$fn.tmp
    if [[ ! -f $f2 ]]; then
        pkg_patch_f "$SupportDir/$f" "$p" "$OrigSrcDir" --verbose "$@" || return 1
        touch "$f2"
    fi
}

pkg_apply_patches() {
    (
        cd "$OrigSrcDir" || exit 1
        pkg_debian_patch || exit 1
    )
}

pkg_debian_patch() {
    local d=debian/patches
    local i
    if [[ -d $d && -f $d/series ]]; then
        while IFS= read -r i; do
            [[ ! $i ]] && continue
            echo "--------------------"
            pkg_echo "patch from $d/$i ..."
            patch -p1 <"$d/$i" || return 1
        done < <(grep -v '^#' "$d/series")
        mv "$d" "$d.tmp"
    fi
}

pkg_mkdir() {
    local d=$1
    if [[ ! $d ]]; then
        pkg_log "empty arg dir: ${FUNCNAME[1]}"
        return 1
    fi
    if [[ ! -d $d ]]; then
        mkdir -p "$d" || {
            pkg_log "mkdir error: $d: ${FUNCNAME[1]}"
            return 1
        }
    fi
}

pkg_read_exist() {
    # while f=$(pkg_read_exist); do ... done
    local x
    while IFS= read -r x; do
        if [[ ! $x ]]; then
            continue
        elif [[ ! -e $x && -L $x ]]; then
            # broken link, OK
            :
        elif [[ ! -e $x ]]; then
            continue
        fi
        pkg_echo "$x"
        return 0
    done
    return 1
}

pkg_mv_ln() {
    # ls *.so*| pkg_mv_ln dir
    # read f; mv $f $1/ && ln -sfnr $1/$f $f
    local d=$1 f
    pkg_mkdir "$d" || return 1
    while f=$(pkg_read_exist); do
        mv "$f" "$d" || return 1
        ln -sfnr "$d/$(basename "$f")" "$f"
    done
}

pkg_mv_ln_ff() {
    # pkg_mv_ln_ff <file1> <file2>
    # pkg_mv_ln_ff "$Prefix2"/bin/gdk-pixbuf-query-loaders{,-64}
    local f1=$1 f2=$2
    if [[ ! $f1 || ! $f2 ]]; then
        pkg_log "empty args"
        return 1
    fi
    if [[ ! -e $f1 ]]; then
        pkg_log "not exist: $f1"
        return 1
    fi
    pkg_mkdir "$(dirname "$f2")" || return 1
    mv "$f1" "$f2" || return 1
    ln -sfnr "$f2" "$f1"
}

pkg_mv_d() {
    # ls *.so*| pkg_mv_d dir
    # read f; mv $f $1/
    local d=$1 f
    pkg_mkdir "$d" || return 1
    while f=$(pkg_read_exist); do
        mv "$f" "$d" || return 1
    done
}

pkg_mv_ff() {
    # pkg_mv_ff file1* file2 (even if many, for convenience)
    local args=("${@:1:($# - 1)}") # (arg1, ... argN), last
    local f2=${!#} # last

    # check $f2
    [[ ! $f2 ]] && {
        pkg_log "empty f2"
        return 1
    }
    pkg_mkdir "$(dirname "$f2")" || return 1

    local f1
    for f1 in "${args[@]}"; do
        if [[ ! $f1 ]]; then
            continue
        elif [[ ! -e $f1 && -L $f1 ]]; then
            # broken link, OK
            :
        elif [[ ! -e $f1 ]]; then
            continue
        fi
        mv "$f1" "$f2"
    done
}

pkg_ln_d() {
    # find -name '*.so*'| pkg_ln_d dir
    # read f; ln -sfnr $f dir
    local d=$1 x
    pkg_mkdir "$d" || return 1
    while x=$(pkg_read_exist); do
        ln -sfnr "$x" "$d"
    done
}

pkg_ln_ff() {
    # ls -d file* | pkg_ln_ff link (even if many, for convenience)
    local f2=$1

    # check $f2, dirname($f2)
    [[ ! $f2 ]] && {
        pkg_log "empty f2"
        return 1
    }
    pkg_mkdir "$(dirname "$f2")" || return 1

    local f1
    while f1=$(pkg_read_exist); do
        ln -sfnr "$f1" "$f2"
    done
}

pkg_filter_doc() {
    # ls | pkg_filter_doc
    local f1 fn bad
    while true; do
        [[ $f1 && ! $bad ]] && pkg_echo "$f1"
        bad=1

        IFS= read -r f1 || break

        [[ -d $f1 ]] && continue

        if [[ ! -s $f1 ]]; then
            # zero size
            continue
        fi

        fn=${f1##*/}
        case $fn in
            [A-Z]*file)
                # Makefile Rakefile Imakefile GNUmakefile BSDmakefile
                # Jamfile Dockerfile Vagrantfile Doxyfile
                continue
                ;;
            Make* | CMake* | *.py | *.c | *.h | *.asc | *.tmp | *.in | *.bazel)
                # Makethird Makedefs CMakeList.txt
                continue
                ;;
            meson_options* | requirements*.txt | ABOUT-NLS | INSTALL* | cmake-config.txt)
                #  meson_options.txt
                continue
                ;;
            SConstruct | SConscript | Kbuild | Kconfig | Jambase | Jamroot | PKGBUILD | WORKSPACE)
                continue
                ;;
            ChangeLog.pre* | NEWS.pre*)
                # gimp-3.x
                continue
                ;;
            *.html | *.txt | *.pdf | ChangeLog | ChangeLog.*)
                # ChangeLog.md
                bad=
                ;;
            [A-Z]*)
                if [[ $fn =~ ^[A-Z]+$ || $fn =~ ^[A-Z]+\. ]]; then
                    # NEWS, README.md, README.win32.md
                    bad=
                elif [[ $fn =~ \. ]]; then
                    continue
                fi
                ;;
            *)
                continue
                ;;
        esac
    done
}

pkg_install_doc() {
    # $OrigSrcDir/{README,...} --> $DocDir2/
    if [[ ! $DOC ]]; then
        return 0
    fi
    local from=$OrigSrcDir
    local to=$DocDir2

    local f1

    # $from/* -> $to/
    while IFS= read -r f1; do
        pkg_install_mfd 644 "$f1" "$to" || return 1
    done < <(find "$from" -maxdepth 1 ! -type d ! -name ".*" |
                pkg_filter_doc)
}

pkg_ln_equals() {
    # find . -name '*.so.*'| pkg_ln_equals
    # if $f1 equals $f2
    #   ln -sfn $f1 $f2

    local f1 fn1 dir1 f2
    while f1=$(pkg_read_exist); do
        [[ -L $f1 ]] && continue

        fn1=$(basename "$f1")
        dir1=$(dirname "$f1")
        while f2=$(pkg_read_exist); do
            diff -q "$f1" "$f2" >/dev/null && ln -sfn "$fn1" "$f2"
        done < <(find "$dir1" -maxdepth 1 -type f ! -name "$fn1")
    done

    return 0
}

pkg_install_mfd() {
    # pkg_install_mfd <mode> [options] [file ...] dir
    # pkg_install_mfd 755 *.sh dir
    # pkg_install_mfd 755 -o root -g bin *.sh dir
    # install -pm <mode> file ... dir
    # ls *.ttf | pkg_install_mfd 644 dir
    if (($# < 2)); then
        pkg_log "bad args: $*"
        return 1
    fi

    local mode=$1
    shift 1

    local args=("${@:1:$(($# - 1))}") # (arg1, ... argN), last
    local dir=${!#}                # last

    if [[ ! $mode ]]; then
        pkg_log "empty mode"
        return 1
    fi

    pkg_mkdir "$dir" || return 1

    local i
    if (($# < 2)); then
        # ls *.ttf | pkg_install_mfd 644 dir
        while i=$(pkg_read_exist); do
            if [[ -L $i ]]; then
                cp -a "$i" "$dir"
            else
                install -pm "$mode" "$i" "$dir"
            fi
        done
    else
        for i in "${args[@]}"; do
            if [[ -L $i ]]; then
                cp -a "$i" "$dir"
            else
                install -pm "$mode" "$i" "$dir"
            fi
        done
    fi
}

pkg_install_mff() {
    # pkg_install_mff <mode> file1 file2
    # pkg_install_mff 644 file1.default /etc/default/file1
    # pkg_install_mff 644 file2 <<EOF
    # ...
    # EOF
    local mode=$1 file1=$2 file2=$3

    [[ ! $mode ]] && { pkg_log "empty mode: $*"; return 1; }

    if (($# < 3)); then
        # mode (stdin) file2
        file2=$file1
        file1=
        [[ ! $file2 ]] && { pkg_log "empty file2: $* (file1=stdin)"; return 1; }
    elif [[ ! $file1 || ! -f $file1 ]]; then
        pkg_log "bad file1: $*"
        return 1
    elif [[ ! $file2 ]]; then
        pkg_log "empty file2: $*"
        return 1
    fi

    local dir2=$(dirname "$file2")
    if [[ $dir2 && ! -d $dir2 ]]; then
        mkdir -p "$dir2" || {
            pkg_log "mkdir error"
            return 1
        }
    fi

    if (($# < 3)); then
        touch "$file2"
        chmod "$mode" "$file2"
        #pkg_log "cat stdin: $*"
        # cat stdin
        cat >"$file2"
    else
        install -pm "$mode" "$file1" "$file2"
    fi
}

pkg_install_md() {
    # find -type f | pkg_install_md mode dir
    local mode=$1 dir=$2 f
    if [[ ! $mode ]]; then
        pkg_log "empty mode"
        return 1
    fi
    pkg_mkdir "$dir" || return 1
    while f=$(pkg_read_exist); do
        install -pm "$mode" "$f" "$dir"
    done
}

pkg_cp_fd() {
    # pkg_cp_fd [cp options] [file ...] dir
    # pkg_cp_fd *.sh dir
    # cp -a file ... dir

    local args=("${@:1:($# - 1)}") # (arg1, ... argN), last
    local dir=${!#}                 # last

    if [[ ! $dir ]]; then
        pkg_log "empty dir"
        return 1
    fi

    pkg_mkdir "$dir" || return 1
    cp -a "${args[@]}" "$dir"
}

pkg_cp_dd() {
    # pkg_cp_dd [cp options] dir1 dir2 [cp options]
    # pkg_cp_dd doc dir2
    # cd dir1 && cp -a . dir2

    local dir1=$1
    local dir2=$2
    shift 2

    if [[ ! $dir1 || ! -d $dir1 ]]; then
        pkg_log "dir1 empty or not dir: $dir1"
        return 1
    fi

    if [[ ! $dir2 ]]; then
        pkg_log "empty dir2"
        return 1
    fi

    pkg_mkdir "$dir2" || return 1
    dir2=$(readlink -f "$dir2")
    (
        cd "$dir1" || exit 1
        cp -a . "$@" "$dir2"
    )
}

pkg_cp_d() {
    # ls -d file* | pkg_cp_d dir
    # cp -a file ... dir/
    local dir=$1
    pkg_mkdir "$dir" || return 1

    local f
    while f=$(pkg_read_exist); do
        cp -a "$f" "$dir"
    done
}

pkg_cd_srcdir() {
    local dir
    if [[ $UseBuildDir ]]; then
        dir=$BuildDir
        if [[ ! -d $dir ]]; then
            mkdir -p "$dir" || return 1
        fi
    else
        dir=$SrcDir
    fi

    cd "$dir"
}

pkg_cd_makedir() {
    # i3status: configure, cd *-linux*; make
    pkg_cd_srcdir
}

pkg_pre_configure() {
    :
}

pkg_pre_make() {
    :
}

pkg_post_make() {
    :
}

pkg_pre_install() {
    :
}

pkg_rm_files() {
    # pkg_rm_files [file [file ...]]    (not dir)
    local f
    while [[ $1 ]]; do
        f=$1
        shift
        [[ $f && -e $f && ! -d $f ]] && rm -f "$f"
    done
}

pkg_filetype() {
    # file $1
    local type_
    type_=$(file -S "$1") || {
        pkg_log "bad command: file \"$1\""
        return 1
    }
    # file -S: disable libseccomp sandboxing
    # fakeroot file --> bad system call
    # Hardening the "file" utility for Debian:
    # https://lwn.net/Articles/796108/?hmsr=joyk.com&utm_source=joyk.com&utm_medium=referral
    # local.manpage-seccomp-is-disabled.patch
    if [[ $type_ =~ (ELF .* executable) ]]; then
        echo "exec"
    elif [[ $type_ =~ (ELF .* shared object) ]]; then
        echo "so"
    elif [[ $type_ =~ ( ar archive$) ]]; then
        echo "a"
    elif [[ $type_ =~ (libtool library file) ]]; then
        echo "la"
    else
        echo ""
    fi
}

pkg_mkdir_cache() {
    local d=$UserCacheDir # ~/.cache/confpkg
    if [[ ! -d $d ]]; then
        mkdir -pm 700 "$d" || return 1
    fi
    chmod 700 "$d"
}

pkg_reinstall_python() {
    # REQ: pkg_set_python ...
    # reinstall python (egg -> dist-info)
    # pkg_reinstall_python <dir>
    local dir=$1
    local p=$(basename "$Python") # python3.14
    if [[ ! $p ]]; then
        echo "var Python not defined"
        return 1
    fi

    local dest i
    for i in "$LibDir2/$p" "$PythonLibDir2"; do
        if [[ -d $i ]]; then
            dest=$i
            break
        fi
    done
    [[ ! $dest ]] && dest=$PythonLibDir2

    (
        pkg_cd_srcdir || exit 1
        cd "$dir" || exit 1
        d2=$dest/site-packages
        [[ -d $d2 ]] && rm -rf "$d2"
        "$Python" -m pip install . -t "$d2"
    )
}

pkg_cmp_versions() {
    # pkg_cmp_versions '5.0.1' '6.1' # -1
    local ver1=$1 ver2=$2 # 5.0.1, 6.1

    # ncurses-6.5_20250809-x86_64-1
    IFS=".-_" read -r -a ver1 <<<"$ver1" # [5, 0, 1]
    IFS=".-_" read -r -a ver2 <<<"$ver2" # [6, 1]

    local max
    if ((${#ver1[*]} < ${#ver2[*]})); then
        max=${#ver1[*]}
    else
        max=${#ver2[*]}
    fi

    local i
    for ((i=0; i<$max; i+=1)); do
        # i = 0 1 2 ...
        if ((${ver1[$i]} < ${ver2[$i]})); then
            echo "-1"
            return 0
        elif ((${ver1[$i]} > ${ver2[$i]})); then
            echo "1"
            return 0
        fi
    done
    echo "0"
}

pkg_create_orig() {
    # cp -a X X.orig
    local f=$1
    if [[ -e $f && ! -e "$f.orig" ]]; then
        cp -a "$f" "$f.orig"
        return 0
    fi
    return 1
}

pkg_show_time_used() {
    local sec1=$1
    local prompt=$2

    local sec2=$(date +%s)
    local time1=$((sec2 - sec1))
    local time2

    [[ $prompt ]] && echo -n "$prompt: "
    if ((time1 < 60)); then
        echo "${time1}s"
        return 0
    fi
    time2=$((time1 % 60))
    ((time1 /= 60))
    if ((time1 < 60)); then
        echo "${time1}m${time2}s" && return 0
    fi
    time2=$((time1 % 60))
    ((time1 /= 60))
    echo "${time1}h${time2}m" && return 0
}

pkg_read2var() {
    # pkg_read2var var_name <<EOF
    # ...
    # EOF
    read -r -d '' "$1"
    :
}

pkg_doinst_add() {
    local dir=$DestDir/install
    local file=$dir/doinst.sh
    if [[ ! -f $file ]]; then
        pkg_install_mfd 644 "$FilesDir/confpkg/doinst.sh" "$dir"
    fi
    if (($# > 0)); then
        echo "$1" >>"$file"
    else
        # stdin
        cat >>"$file"
    fi
}

pkg_doinst_add_config() {
    # f1=$DestDir/$path
    # pkg_doinst_add_config "$f1"
    # -> pkg_doinst_add "config $path"
    local f1=$1
    [[ ! $f1 ]] && return 1
    pkg_doinst_add "config ${f1:$((${#DestDir} + 1))}"
}
