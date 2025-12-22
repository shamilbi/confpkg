#!/bin/bash

config() {
    OLD=$1
    NEW=$OLD.new

    [[ ! -e $NEW ]] && return 1

    if [[ ! -r $OLD ]]; then
        mv "$NEW" "$OLD"
    elif [[ "$(cat "$OLD" | md5sum)" = "$(cat "$NEW" | md5sum)" ]]; then
        rm "$NEW"
    fi
    # Otherwise, we leave the .new copy for the admin to consider...
    if [[ -r $OLD && -r $NEW ]]; then
        cp -a "$OLD" "$OLD.incoming"
        cat "$NEW" >"$OLD.incoming"
        mv "$OLD.incoming" "$NEW"
    fi
}
