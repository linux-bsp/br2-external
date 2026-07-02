#!/bin/sh

set -eu

log()
{
    echo "[module-test] $*"
}

have_cmd()
{
    command -v "$1" >/dev/null 2>&1
}

run_claim_test_if_present()
{
    type_name="$1"
    devices="$2"

    if ! have_cmd pdi_claim_test; then
        log "skip pdi_claim_test $type_name: tool not installed"
        return 0
    fi
    if echo "$devices" | grep -q "type=$type_name .*access=shared-ioctl"; then
        log "run pdi_claim_test $type_name"
        pdi_claim_test "$type_name"
    else
        log "skip pdi_claim_test $type_name: no shared ioctl device"
    fi
}

log "modprobe pdm"
modprobe pdm

if have_cmd pdebug; then
    log "pdebug discovery info"
    pdebug discovery info || true
    log "pdebug discovery list"
    devices="$(pdebug discovery list 2>/dev/null || true)"
    if [ -n "$devices" ]; then
        echo "$devices"
        run_claim_test_if_present mcu "$devices"
        run_claim_test_if_present led "$devices"
    else
        log "no PDM devices reported"
    fi
else
    log "skip pdebug: tool not installed"
fi
