#!/bin/sh

set -eu

die()
{
	echo "firmware-image: $*" >&2
	exit 1
}

usage()
{
	echo "Usage: $0 <binaries-dir> -c <genimage-config>" >&2
	exit 2
}

[ "$#" -eq 3 ] || usage
BINARIES_DIR="$1"
[ "$2" = "-c" ] || usage
GENIMAGE_CFG="$3"

[ -d "${BINARIES_DIR}" ] || die "missing binaries directory: ${BINARIES_DIR}"
[ -f "${GENIMAGE_CFG}" ] || die "missing genimage config: ${GENIMAGE_CFG}"

CONFIG_DIR="$(CDPATH= cd -- "$(dirname -- "${GENIMAGE_CFG}")" && pwd)"
GENIMAGE_CFG="${CONFIG_DIR}/$(basename -- "${GENIMAGE_CFG}")"
MKIMAGE="${HOST_DIR}/bin/mkimage"
RELEASE_TEMPLATE="${CONFIG_DIR}/release.its.in"
MEDIA_CFG="${CONFIG_DIR}/genimage_sdcard.cfg"

[ -x "${MKIMAGE}" ] || die "mkimage is not available"

if [ -z "${FW_DTB_FILE:-}" ] && [ -n "${BR2_CONFIG:-}" ]; then
	DTB_LIST="$(sed -n "s#^BR2_LINUX_KERNEL_INTREE_DTS_NAME=\"\(.*\)\"\$#\1#p" "${BR2_CONFIG}")"
	set -- ${DTB_LIST}
	if [ "$#" -gt 0 ]; then
		FW_DTB_FILE="$(basename -- "$1").dtb"
		export FW_DTB_FILE
	fi
fi

ITS_LIST="$(sed -n "s#^[[:space:]]*its[[:space:]]*=[[:space:]]*\"\([^\"]*\)\".*#\1#p" "${GENIMAGE_CFG}" | sort -u)"

for ITS_PATH in ${ITS_LIST}; do
	ITS_SOURCE="${CONFIG_DIR}/$(basename -- "${ITS_PATH}")"
	ITS_OUTPUT="${BINARIES_DIR}/${ITS_PATH}"
	[ -f "${ITS_SOURCE}" ] || die "missing ITS file: ${ITS_SOURCE}"
	mkdir -p "$(dirname -- "${ITS_OUTPUT}")"
	cp "${ITS_SOURCE}" "${ITS_OUTPUT}"
done

PATH="${HOST_DIR}/bin:${PATH}" GENIMAGE_MKIMAGE="${MKIMAGE}" support/scripts/genimage.sh -c "${GENIMAGE_CFG}"

if [ -f "${RELEASE_TEMPLATE}" ]; then
	command -v sha256sum >/dev/null 2>&1 || die "sha256sum is not available"
	BOOTLOADER_SHA256="$(sha256sum "${BINARIES_DIR}/release/bootloader.itb" | cut -d ' ' -f 1)"
	KERNEL_SHA256="$(sha256sum "${BINARIES_DIR}/release/kernel.itb" | cut -d ' ' -f 1)"
	ROOTFS_SHA256="$(sha256sum "${BINARIES_DIR}/release/rootfs.itb" | cut -d ' ' -f 1)"
	RELEASE_ITS="${BINARIES_DIR}/release/release.its"

	sed -e "s/@BOOTLOADER_SHA256@/${BOOTLOADER_SHA256}/g" \
	    -e "s/@KERNEL_SHA256@/${KERNEL_SHA256}/g" \
	    -e "s/@ROOTFS_SHA256@/${ROOTFS_SHA256}/g" \
	    "${RELEASE_TEMPLATE}" >"${RELEASE_ITS}"
	if ! "${MKIMAGE}" -f "${RELEASE_ITS}" \
		"${BINARIES_DIR}/release/release.itb"; then
		rm -f "${RELEASE_ITS}"
		die "failed to create release.itb"
	fi
	rm -f "${RELEASE_ITS}"
fi

if [ -f "${MEDIA_CFG}" ]; then
	PATH="${HOST_DIR}/bin:${PATH}" support/scripts/genimage.sh -c "${MEDIA_CFG}"
fi

for ITS_PATH in ${ITS_LIST}; do
	rm -f "${BINARIES_DIR}/${ITS_PATH}"
done
