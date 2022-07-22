#!/bin/bash
which() {
    (alias; declare -f) | /usr/bin/which --read-alias --read-functions --show-tilde --show-dot $@
}

check_requirement() {
    req=$1
    if ! which $req &>/dev/null; then
        echo "No $req. Can't continue" 1>&2
        return 1
    fi
}

main() {
# Check for required software
    reqs=(
        aws
        abc
        doctl
        kubectl
        oc
        openshift-install
        jq
    )
    for req in ${reqs[@]}; do
        check_requirement $req
    done
}

main $@
if [ $? -ne 0 ]; then
    exit 1
else
    exit 0
fi