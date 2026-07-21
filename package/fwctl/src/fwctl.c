// SPDX-License-Identifier: GPL-2.0+
#define _GNU_SOURCE
#include <endian.h>
#include <errno.h>
#include <fcntl.h>
#include <inttypes.h>
#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#define FW_METADATA_MAGIC 0x46574d44U
#define FW_METADATA_VERSION 1U
#define FW_METADATA_SIZE 128U
#define FW_SLOT_NONE 0xffU
#define FW_COMPONENT_COUNT 3U
#define FW_META0_OFFSET 0x00500000ULL
#define FW_META1_OFFSET 0x00510000ULL

enum fw_state {
	FW_STATE_EMPTY,
	FW_STATE_WRITING,
	FW_STATE_READY,
	FW_STATE_BOOT_TESTING,
	FW_STATE_CONFIRMED,
	FW_STATE_FAILED,
};

struct fw_disk_component {
	uint8_t slot;
	uint8_t valid;
	uint16_t reserved;
	uint32_t version;
	uint32_t rollback_index;
} __attribute__((packed));

struct fw_disk_deployment {
	struct fw_disk_component component[FW_COMPONENT_COUNT];
	uint8_t state;
	uint8_t tries_remaining;
	uint8_t successful;
	uint8_t reserved;
	uint32_t release_version;
} __attribute__((packed));

struct fw_disk_metadata {
	uint32_t magic;
	uint16_t format_version;
	uint16_t header_size;
	uint32_t sequence;
	uint8_t active_deployment;
	uint8_t pending_deployment;
	uint8_t last_good_deployment;
	uint8_t boot_once_deployment;
	uint8_t update_state;
	uint8_t selected_deployment;
	uint8_t reserved0[2];
	struct fw_disk_deployment deployment[2];
	uint8_t reserved1[16];
	uint32_t crc32;
} __attribute__((packed));

_Static_assert(sizeof(struct fw_disk_metadata) == FW_METADATA_SIZE,
	       "firmware metadata size mismatch");

static const char *const component_names[] = {
	"bootloader", "kernel", "rootfs",
};

static const char *state_name(uint8_t state)
{
	static const char *const names[] = {
		"empty", "writing", "ready", "boot-testing", "confirmed",
		"failed",
	};

	return state < sizeof(names) / sizeof(names[0]) ? names[state] :
		"invalid";
}

static uint32_t fw_crc32(uint32_t crc, const void *data, size_t len)
{
	const uint8_t *p = data;
	size_t i;
	int bit;

	crc = ~crc;
	for (i = 0; i < len; i++) {
		crc ^= p[i];
		for (bit = 0; bit < 8; bit++)
			crc = (crc >> 1) ^ (0xedb88320U &
					      (uint32_t)-(int32_t)(crc & 1U));
	}

	return ~crc;
}

static int read_full_at(int fd, void *buf, size_t len, uint64_t offset)
{
	uint8_t *p = buf;
	size_t done = 0;

	while (done < len) {
		ssize_t ret = pread(fd, p + done, len - done, offset + done);

		if (ret < 0) {
			if (errno == EINTR)
				continue;
			return -errno;
		}
		if (!ret)
			return -EIO;
		done += ret;
	}

	return 0;
}

static int write_full_at(int fd, const void *buf, size_t len, uint64_t offset)
{
	const uint8_t *p = buf;
	size_t done = 0;

	while (done < len) {
		ssize_t ret = pwrite(fd, p + done, len - done, offset + done);

		if (ret < 0) {
			if (errno == EINTR)
				continue;
			return -errno;
		}
		if (!ret)
			return -EIO;
		done += ret;
	}

	return 0;
}

static int metadata_valid(const struct fw_disk_metadata *metadata)
{
	uint32_t expected, actual;

	if (le32toh(metadata->magic) != FW_METADATA_MAGIC ||
	    le16toh(metadata->format_version) != FW_METADATA_VERSION ||
	    le16toh(metadata->header_size) != FW_METADATA_SIZE)
		return 0;
	if (metadata->active_deployment > 1 ||
	    metadata->last_good_deployment > 1 ||
	    (metadata->pending_deployment != FW_SLOT_NONE &&
	     metadata->pending_deployment > 1) ||
	    (metadata->boot_once_deployment != FW_SLOT_NONE &&
	     metadata->boot_once_deployment > 1) ||
	    metadata->selected_deployment > 1 ||
	    metadata->update_state > FW_STATE_FAILED)
		return 0;
	expected = le32toh(metadata->crc32);
	actual = fw_crc32(0, metadata,
			  offsetof(struct fw_disk_metadata, crc32));

	return expected == actual;
}

static int sequence_newer(uint32_t lhs, uint32_t rhs)
{
	return (int32_t)(lhs - rhs) > 0;
}

static int load_metadata(int fd, const uint64_t offsets[2],
			 struct fw_disk_metadata *metadata, unsigned int *source)
{
	struct fw_disk_metadata copy[2];
	int valid[2] = { 0, 0 };
	int ret;

	ret = read_full_at(fd, &copy[0], sizeof(copy[0]), offsets[0]);
	if (!ret)
		valid[0] = metadata_valid(&copy[0]);
	ret = read_full_at(fd, &copy[1], sizeof(copy[1]), offsets[1]);
	if (!ret)
		valid[1] = metadata_valid(&copy[1]);
	if (!valid[0] && !valid[1])
		return -ENODATA;

	*source = valid[1] && (!valid[0] ||
		sequence_newer(le32toh(copy[1].sequence),
			       le32toh(copy[0].sequence)));
	*metadata = copy[*source];

	return 0;
}

static int save_metadata(int fd, const uint64_t offsets[2],
			 struct fw_disk_metadata *metadata, unsigned int *source)
{
	struct fw_disk_metadata verify;
	unsigned int target = 1U - *source;
	uint32_t sequence = le32toh(metadata->sequence) + 1U;
	int ret;

	metadata->sequence = htole32(sequence);
	metadata->crc32 = htole32(fw_crc32(
		0, metadata, offsetof(struct fw_disk_metadata, crc32)));
	ret = write_full_at(fd, metadata, sizeof(*metadata), offsets[target]);
	if (ret)
		return ret;
	if (fsync(fd))
		return -errno;
	ret = read_full_at(fd, &verify, sizeof(verify), offsets[target]);
	if (ret)
		return ret;
	if (!metadata_valid(&verify) ||
	    le32toh(verify.sequence) != sequence)
		return -EIO;
	*source = target;

	return 0;
}

static int deployment_valid(const struct fw_disk_deployment *deployment)
{
	unsigned int i;

	if (deployment->state == FW_STATE_EMPTY ||
	    deployment->state == FW_STATE_FAILED)
		return 0;
	for (i = 0; i < FW_COMPONENT_COUNT; i++) {
		if (!deployment->component[i].valid ||
		    deployment->component[i].slot > 1)
			return 0;
	}

	return 1;
}

static void metadata_init(struct fw_disk_metadata *metadata, uint8_t slot)
{
	struct fw_disk_deployment *deployment;
	unsigned int i;

	memset(metadata, 0, sizeof(*metadata));
	metadata->magic = htole32(FW_METADATA_MAGIC);
	metadata->format_version = htole16(FW_METADATA_VERSION);
	metadata->header_size = htole16(FW_METADATA_SIZE);
	metadata->active_deployment = 0;
	metadata->pending_deployment = FW_SLOT_NONE;
	metadata->last_good_deployment = 0;
	metadata->boot_once_deployment = FW_SLOT_NONE;
	metadata->selected_deployment = 0;
	metadata->update_state = FW_STATE_CONFIRMED;
	deployment = &metadata->deployment[0];
	deployment->state = FW_STATE_CONFIRMED;
	deployment->successful = 1;
	for (i = 0; i < FW_COMPONENT_COUNT; i++) {
		deployment->component[i].slot = slot;
		deployment->component[i].valid = 1;
	}
	metadata->deployment[1].state = FW_STATE_EMPTY;
}

static void print_status(const struct fw_disk_metadata *metadata)
{
	unsigned int i, j;

	printf("sequence: %" PRIu32 "\n", le32toh(metadata->sequence));
	printf("active: %u  pending: ", metadata->active_deployment);
	if (metadata->pending_deployment == FW_SLOT_NONE)
		printf("none");
	else
		printf("%u", metadata->pending_deployment);
	printf("  last-good: %u  selected: %u\n",
	       metadata->last_good_deployment, metadata->selected_deployment);

	for (i = 0; i < 2; i++) {
		const struct fw_disk_deployment *deployment =
			&metadata->deployment[i];

		printf("deployment %u: %s successful=%u tries=%u release=%" PRIu32
		       "\n", i, state_name(deployment->state),
		       deployment->successful, deployment->tries_remaining,
		       le32toh(deployment->release_version));
		for (j = 0; j < FW_COMPONENT_COUNT; j++) {
			const struct fw_disk_component *component =
				&deployment->component[j];

			printf("  %-10s slot=%c version=%" PRIu32
			       " rollback=%" PRIu32 " valid=%u\n",
			       component_names[j], 'a' + component->slot,
			       le32toh(component->version),
			       le32toh(component->rollback_index), component->valid);
		}
	}
}

static int cmdline_deployment(void)
{
	char buf[2048];
	char *token, *saveptr;
	ssize_t len;
	int saved_errno;
	int fd, deployment = -1;

	fd = open("/proc/cmdline", O_RDONLY | O_CLOEXEC);
	if (fd < 0)
		return -errno;
	len = read(fd, buf, sizeof(buf) - 1);
	saved_errno = errno;
	close(fd);
	if (len < 0) {
		errno = saved_errno;
		return -errno;
	}
	buf[len] = '\0';

	for (token = strtok_r(buf, " \n", &saveptr); token;
	     token = strtok_r(NULL, " \n", &saveptr)) {
		char extra;

		if (sscanf(token, "fw.deployment=%d%c", &deployment, &extra) == 1)
			break;
	}

	return deployment;
}

static int parse_deployment(const char *value)
{
	char *end;
	long deployment;

	errno = 0;
	deployment = strtol(value, &end, 10);
	if (errno || *end || deployment < 0 || deployment > 1)
		return -EINVAL;

	return deployment;
}

static void usage(const char *program)
{
	fprintf(stderr,
		"Usage: %s [--device path] [--meta0 offset] [--meta1 offset] "
		"<init a|b|status|mark-good [deployment]|mark-bad deployment|rollback>\n",
		program);
}

int main(int argc, char **argv)
{
	const char *device = "/dev/mmcblk1";
	uint64_t offsets[2] = { FW_META0_OFFSET, FW_META1_OFFSET };
	struct fw_disk_metadata metadata;
	unsigned int source;
	const char *command;
	int arg = 1, deployment, fd, ret;

	while (arg < argc && !strncmp(argv[arg], "--", 2)) {
		if (arg + 1 >= argc) {
			usage(argv[0]);
			return 2;
		}
		if (!strcmp(argv[arg], "--device"))
			device = argv[arg + 1];
		else if (!strcmp(argv[arg], "--meta0"))
			offsets[0] = strtoull(argv[arg + 1], NULL, 0);
		else if (!strcmp(argv[arg], "--meta1"))
			offsets[1] = strtoull(argv[arg + 1], NULL, 0);
		else {
			usage(argv[0]);
			return 2;
		}
		arg += 2;
	}
	if (arg >= argc) {
		usage(argv[0]);
		return 2;
	}
	command = argv[arg++];

	fd = open(device, O_RDWR | O_CLOEXEC);
	if (fd < 0) {
		fprintf(stderr, "fwctl: cannot open %s: %s\n", device,
			strerror(errno));
		return 1;
	}
	if (!strcmp(command, "init")) {
		if (arg + 1 != argc || strlen(argv[arg]) != 1 ||
		    (argv[arg][0] != 'a' && argv[arg][0] != 'b')) {
			usage(argv[0]);
			close(fd);
			return 2;
		}
		metadata_init(&metadata, argv[arg][0] - 'a');
		source = 1;
		ret = save_metadata(fd, offsets, &metadata, &source);
		if (!ret)
			ret = save_metadata(fd, offsets, &metadata, &source);
		if (!ret)
			printf("fwctl: initialized metadata with slot %c active\n",
			       argv[arg][0]);
		else
			fprintf(stderr, "fwctl: init failed: %s\n", strerror(-ret));
		close(fd);
		return ret ? 1 : 0;
	}
	ret = load_metadata(fd, offsets, &metadata, &source);
	if (ret) {
		fprintf(stderr, "fwctl: metadata unavailable: %s\n",
			strerror(-ret));
		close(fd);
		return 1;
	}

	if (!strcmp(command, "status")) {
		if (arg != argc) {
			usage(argv[0]);
			ret = -EINVAL;
		} else {
			print_status(&metadata);
			ret = 0;
		}
		goto out;
	}

	if (!strcmp(command, "mark-good")) {
		deployment = arg < argc ? parse_deployment(argv[arg++]) :
			cmdline_deployment();
		if (arg != argc || deployment < 0 ||
		    !deployment_valid(&metadata.deployment[deployment])) {
			ret = -EINVAL;
			goto out;
		}
		if (metadata.active_deployment == deployment &&
		    metadata.last_good_deployment == deployment &&
		    metadata.pending_deployment == FW_SLOT_NONE &&
		    metadata.deployment[deployment].state == FW_STATE_CONFIRMED &&
		    metadata.deployment[deployment].successful) {
			printf("fwctl: deployment %d is already confirmed\n",
			       deployment);
			ret = 0;
			goto out;
		}
		metadata.deployment[deployment].state = FW_STATE_CONFIRMED;
		metadata.deployment[deployment].successful = 1;
		metadata.deployment[deployment].tries_remaining = 0;
		metadata.active_deployment = deployment;
		metadata.last_good_deployment = deployment;
		metadata.selected_deployment = deployment;
		metadata.pending_deployment = FW_SLOT_NONE;
		metadata.update_state = FW_STATE_CONFIRMED;
	} else if (!strcmp(command, "mark-bad")) {
		if (arg >= argc || (deployment = parse_deployment(argv[arg++])) < 0 ||
		    arg != argc) {
			ret = -EINVAL;
			goto out;
		}
		metadata.deployment[deployment].state = FW_STATE_FAILED;
		metadata.deployment[deployment].successful = 0;
		metadata.deployment[deployment].tries_remaining = 0;
		if (metadata.pending_deployment == deployment)
			metadata.pending_deployment = FW_SLOT_NONE;
		if (metadata.active_deployment == deployment)
			metadata.active_deployment = metadata.last_good_deployment;
		if (metadata.selected_deployment == deployment)
			metadata.selected_deployment = metadata.last_good_deployment;
		metadata.update_state = FW_STATE_FAILED;
	} else if (!strcmp(command, "rollback")) {
		deployment = metadata.last_good_deployment;
		if (arg != argc || deployment > 1 ||
		    !metadata.deployment[deployment].successful ||
		    !deployment_valid(&metadata.deployment[deployment])) {
			ret = -ENOENT;
			goto out;
		}
		if (metadata.pending_deployment != FW_SLOT_NONE)
			metadata.deployment[metadata.pending_deployment].state =
				FW_STATE_FAILED;
		metadata.pending_deployment = FW_SLOT_NONE;
		metadata.boot_once_deployment = FW_SLOT_NONE;
		metadata.active_deployment = deployment;
		metadata.selected_deployment = deployment;
		metadata.update_state = FW_STATE_CONFIRMED;
	} else {
		usage(argv[0]);
		ret = -EINVAL;
		goto out;
	}

	ret = save_metadata(fd, offsets, &metadata, &source);
	if (!ret)
		printf("fwctl: %s committed to metadata copy %u\n", command,
		       source);

out:
	if (ret)
		fprintf(stderr, "fwctl: %s failed: %s\n", command,
			strerror(-ret));
	close(fd);
	return ret ? 1 : 0;
}
