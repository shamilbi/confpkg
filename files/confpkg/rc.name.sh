#daemon_=
#daemonOpts=()
#daemonUser=
#pidFile=

name=$(basename "$daemon_")
pid=
if [[ $pidFile && -r $pidFile ]]; then
    #pid=$(cat "$pidFile"| head -1)
    # Slackware rc.pcscd
    pid=$(cat "$pidFile" | head -1 | tr -d '\0')
fi

_cmd() {
    local rc
    "$@"
    rc=$?
    (( rc == 0 )) && echo "OK" || echo "FAILED"
    return $rc
}

_start() {
    if [[ -x $daemon_ ]]; then
        if [[ $pid ]]; then
            echo "$name already started!"
            return 0
        fi
        if [[ $daemonUser ]]; then
            echo -n "Starting $daemon_ (user=$daemonUser) ..."
            _cmd runuser -u "$daemonUser" -- "$daemon_" "${daemonOpts[@]}"
        else
            echo -n "Starting $daemon_..."
            _cmd "$daemon_" "${daemonOpts[@]}"
        fi
    fi
}

_stop() {
    local killall_
    echo -n "Stopping $name ..."
    if [[ $pid ]]; then
        echo -n "kill $pid ..."
        _cmd kill "$pid" || killall_=1
    else
        killall_=1
    fi
    if [[ $killall_ ]]; then
        echo -n "killall $name ..."
        #_cmd killall "$name"
        # Slackware rc.pcscd
        _cmd killall --ns $$ "$name"
    fi
    sleep 1
    [[ -f $pidFile ]] && rm -f "$pidFile" 2>/dev/null
}

_restart() {
    _stop
    sleep 2
    _start
}

_status() {
    if [[ $pid ]]; then
        echo "$name is running."
    else
        echo "$name is stopped."
    fi
}

case "$1" in
    start) _start ;;
    stop) _stop ;;
    restart) _restart ;;
    status) _status ;;
    *) echo "Usage: $0 start|stop|restart|status" ;;
esac
