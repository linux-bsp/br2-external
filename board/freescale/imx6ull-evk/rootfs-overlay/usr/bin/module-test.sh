#!/bin/sh

echo "modprobe osal"
modprobe osal

echo "modprobe lpf_configs"
modprobe lpf_configs

echo "modprobe lpf_core"
modprobe lpf_core
