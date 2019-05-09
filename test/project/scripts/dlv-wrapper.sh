#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# Copyright 2019 The Kubernetes authors.

# This is a utility script that attempts to connect to a dlv debugger for the
# purpose of sending it a continue command to allow the process being debugged
# to start running without needing to wait for a debugger to attach to it.

DLVPATH=${DLVPATH}
SERVER=${SERVER:-"127.0.0.1"}
PORT=${PORT:-40000}
WAIT=${WAIT:-1}
MULTICLIENT=${MULTICLIENT:-1}
APIVERSION=${APIVERSION:-2}
HEADLESS=${HEADLESS:-true}

trap cleanup EXIT INT QUIT TERM

if [[ "${DLVPATH}" == "" ]]; then
    # Use the automatic path if available.
    DLVPATH=$(which dlv)
    if [[ "${DLVPATH}" == "" ]]; then
        # Otherwise, default to the expected image path
        DLVPATH="/dlv"
    fi
fi

# Kills the inject background task if it exists.
cleanup () {
    kill %2 > /dev/null 2>1
    kill %1 > /dev/null 2>1
    return 0
}

# Injects a "continue" command into the local debug session so that it starts
# the process being debugged without needing to wait for a real debugger to
# connect.
inject_continue () {
    local RET=1
    while [[ ${RET} -ne 0 ]]; do
        ${DLVPATH} --init <(echo "exit -c") connect ${SERVER}:${PORT} >/dev/null 2>1
        RET=$?

        if [[ ${RET} -ne 0 ]]; then
           sleep 5
        fi
    done

    echo "debugger continued; exiting"

    return 0
}

# Attach the debugger to the target program.  This method is preferred over the
# "exec" method because when using "exec" the debugger will not termine if the
# program terminates.  When running inside of a container the termination of
# the program needs to propagate to the death of the container so that it is
# restarted.
attach_debugger () {
    local TARGETPID=$1
    local MULTICLIENT=$2
    shift ; shift

    if [[ ${MULTICLIENT} -ne 0 ]]; then
        ACCEPTMULTI="--accept-multiclient"
    else
        ACCEPTMULTI=""
    fi

    ${DLVPATH} --listen=:${PORT} --headless=${HEADLESS} --api-version=${APIVERSION} ${ACCEPTMULTI} attach ${TARGETPID} $@ &
    local DLVPID=$!

    # Give it time to start
    sleep 0.5

    # Test that it is running
    kill -0 ${DLVPID} > /dev/null 2>1
    if [[ $? -ne 0 ]]; then
        RET=$?
        echo "Debugger did not start: ${RET}"
        return ${RET}
    fi

    return 0
}

# Start the target program in the background
echo "Starting: $@"
$@ &
TARGETPID=$!

# Give it time to start
sleep 0.5

# Test that it is running
kill -0 ${TARGETPID} > /dev/null 2>1
if [[ $? -ne 0 ]]; then
    RET=$?
    echo "Target program did not start: ${RET}"
    exit ${RET}
fi

attach_debugger ${TARGETPID} ${MULTICLIENT} $@
if [[ $? -ne 0 ]]; then
    exit $?
fi

if [[ ${WAIT} -ne 0 ]]; then
    inject_continue &
fi

wait ${TARGETPID}
exit $?
