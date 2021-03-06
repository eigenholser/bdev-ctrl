# Encrypted Backup Device Control

Manage encrypted external devices with plausable deniability for Linux backups.
From the `cryptsetup` man page:

    cryptsetup is used to conveniently setup dm-crypt managed device-mapper
    mappings. These include plain dm-crypt volumes and LUKS volumes. The
    difference is that LUKS uses a metadata header and can hence offer more
    features than  plain  dm-crypt. On the other hand, the header is visible
    and vulnerable to damage.

The key words there are "the header is visible." Using `dm-crypt` is less
flexible, but otherwise the device appears as simply high-entropy data. In and
of itself, that looks suspicious. But, a LUKS header unambiguously declares
the presence of encrypted data.


## The Backup Strategy

One device is configured as "master" and is mounted on `/master`. Remaining
device names are considered "slave" and are mounted on `/slave`. The approach
is to create backup copies by cloning the master. This allows additional
backup copies to be made without taking down system services for the duration.

Also, unnamed devices may be attached using an interactive passphrase only.
The purpose of this is to securely backup the keyfiles! Consider using small
USB flash drives for this purpose.

Attach and detach modes are used only for initialization and troubleshooting.

## Installation

For the impatient, do this:

    sudo make install

That will install the `bdev-ctrl` shell script to `/sbin`.

Now read the sections below on configuration and device initialization.

## Configuration

Several environment variables are required. Directories to use as mount points
are also required.

### Environment Variables

`BDEV_EXCLUDE_DEVICES`

Space delimited list of devices that will not be considered as valid for
use. This is a safety mechanism:

    export BDEV_EXCLUDE_DEVICES="sda sdb"

`BDEV_KEYFILES_PATH`

Path to keyfiles.

    export BDEV_KEYFILES_PATH=/path/to/keyfiles

`BDEV_NAMED_MASTER`

Mountpoint and command used to mount master device.

    export BDEV_NAMED_MASTER=master

`BDEV_NAMED_SLAVE`

Mountpoint and command used to mount slave device.

    export BDEV_NAMED_SLAVE=slave

`BDEV_UNNAMED_MOUNT`

Command and mountpoint used to mount unnamed device. Unnamed means that there
is no corresponding keyfile. The passphrase must be entered by hand. My
convention is to use `admin`.

    export BDEV_UNNAMED_MOUNT=admin

### Mountpoints

You must create mountpoints that correspond to `BDEV_NAMED_MASTER`,
`BDEV_NAMED_SLAVE`, and `BDEV_UNNAMED_MOUNT`. Examples are: `/master`,
`/slave` and `/admin`.

## Device Initialization

Prior to use, devices must be initialized.

### Keyfiles and Cipher

Each named backup device must have a corresponding keyfile and cipher file. The
keyfile must use the device name with a `.keyfile` suffix. The cipher file
specifies the cipher to be used. It must use the device name with a `.cipher`
suffix.

For named devices, the cipher and key is located in respective files in
`$BDEV_KEYFILE_PATH`. The format is `{named_device}.cipher` and
`{named_device}.keyfile`. `bdev-ctrl` will check each of these files
and fail if they are not present.

A reasonable cipher is `aes-cbc-essiv:sha256`. Create file
`$BDEV_KEYFILE_PATH/{named_device}.cipher` with a single line containing
the cipher. See `cryptsetup --help` for a list of compiled in cipher
parameters.

The keyfile may be generated like this:

    dd if=/dev/random of=$BDEV_KEYFILES_PATH/{named_device}.keyfile bs=1k count=8

Since this uses `/dev/random`, you may need to exercise your system for awhile
to generate entropy. Alternatively, for faster generation, use `/dev/urandom`.

### Prepare the device

Preparing the device is slightly different depending on whether it is a named
or unnamed device. In the examples that follow, the example device `/dev/sdX`
will be used. This was chosen to to protect the impatient from themselves.
Really it will be something like `/dev/sdc` or something.

#### Common

Whether or not the device is named or unnamed, you must remove any existing
partition table.

But first, be sure your device is unmounted. Then overwrite the device
partition table:

    dd if=/dev/zero of=/dev/sdX bs=1M count=100

This will overwrite the first 100MB of your device with zeros. Be very certain
that you specify the correct device here!

Unplug the USB cable and then plug it in again.

#### Named Device

Initialize `dm-crypt` on the device:

    cryptsetup --verbose create bd-0_crypt /dev/sdX --key-file /path/to/keyfiles/bd-0.keyfile

This will create the mapped device `/dev/mapper/bd-0_crypt`. At this point,
you must decide whether or not to create a partition or use the entire device.
For this purpose, it is fine to dedicate the entire device. `bdev-ctrl` will
look for `/dev/mapper/bd-0_crypt1` also and use that if present. You may
create a single partition spanning the entire device. If you create multiple
partitions, only the first will be used.

Here is how to create the partition:

    parted /dev/mapper/bd-0_crypt mklabel gpt
    parted /dev/mapper/bd-0_crypt mkpart primary ext2 0% 100%

Since the device is initially without a filesystem, it must first be created.

    mke2fs -j -t ext4 /dev/mapper/bd-0_crypt1

At this point, the device mapping may be removed:

    bdev-ctrl detach bd-0

Then, bring up the device normally:

    bdev-ctrl master sdX bd-0

The device will now be mounted on `/master`.

The final step in device initialization is optional. This step fills the
entire device with high-entropy data.

    dd if=/dev/zero of=/master/bigfile.dat bs=1M

This may take several hours. When the device runs out of space, just delete
`/master/bigfile.dat`:

    rm /master/bigfile.dat

Initialization is complete.

#### Unnamed Device

Initialize `dm-crypt` on the device:

    cryptsetup --verbose create admin_crypt /dev/sdX

`cryptsetup` will prompt for the passphrase.

For an unnamed device, the process is identical to the instructions for a
named device above. The device will be mapped to `/dev/mapper/admin_crypt`.
The only other difference is in how `bdev-ctrl` is used to detach:

    bdev-ctrl detach

Since the device is unnamed, the name does not need to be specified to detach.
The name `admin` is used even though the device is unnamed. The name is used
only to refer to a keyfile. An unnamed device will prompt for a passphrase.

The remaining instructions are the same. Create the partitions and filesystem.

### Flash Memory Devices and Wear Leveling

Flash memory has limited write cycles. Keep this in mind as you fill the
entire device with high-entropy data. There are other considerations here that
are beyond the scope of this README.

# Backup Shell Scripts

The shell scripts use the `rsync` command. Exclude files are required even
if they are empty. They live in `BACKUP_HOME`. See below.

## Environment Variables

The environment variables generally should be set in `root` `.bashrc` file.
Backup directory lists are colon-delimited. Spaces are tolerated in the admin
backup command but probably not for other modes.

`BDEV_TEST`

If this environment variable is set, `--dry-run` will be added to
`rsync_opts` so `rsync` will output what it would have done but will not
actually do it.

    export BDEV_TEST=1

Remove this with `unset BDEV_TEST`.

    unset BDEV_TEST

`BACKUP_HOME`

Path to exclude files.

    export BACKUP_HOME=/path/to/exclude/files

`BACKUP_DEST`

Path to destination of backup. This links in with `bdev-ctrl`.

    export BACKUP_DEST="/${BDEV_NAMED_MASTER}/`hostname -s`"


`BACKUP_DIRS_NOVM`

Colon-delimited list of backup directories with leading slash. I don't like to
backup my virtual machines as often as other data so I distinguish between VM
and non-VM directories. Obviously this is a simple approach where top-level
directories constitute the happy path. More complex arrangments may be
possible--but why?

    export BACKUP_DIRS_NOVM="/root:/home:/var:/etc:/srv"


`BACKUP_DIR_VM`

Colon-delimited list of virtual machine directories. When `all` command-line
argument is passed to `bdev-backup` this will be added to
`BACKUP_DIRS_NOVM`.

    export BACKUP_DIR_VM="/Virtual Machines"


`BACKUP_DIRS`

This is the full list of directories to backup when `all` is specified.

    export BACKUP_DIRS="${BACKUP_DIRS_NOVM}:${BACKUP_DIR_VM}"


`BACKUP_ADMIN_DIRS`

List of directories to use as unnamed admin backup.

    export BACKUP_ADMIN_DIRS='/my/admin dir1:/my/admin/dir2"


`BACKUP_PRE_CMD`

Path to a shell script that will be run prior to doing the backup to
`BDEV_NAMED_MASTER`. The command will be executed with `/bin/sh`.
This is useful for stopping services that might interfere with a point-in-time
backup. It may also be used for other pre-backup tasks such as possibly
dumping database tables.

    export BACKUP_PRE_CMD=/path/to/backup/backup_pre.sh


`BACKUP_POST_CMD`

Path to a shell script that will be run after doing the backup to
`BDEV_NAMED_MASTER`. The command will be executed with `/bin/sh`.
This is good for restarting system services following the backup or logging
the time and date of the backup.

    export BACKUP_POST_CMD=/path/to/backup/backup_post.sh


## Commands

`bdev-backup`

Print usage instructions and exit.


`bdev-backup novm`

Backup `BACKUP_DIRS_NOVM`  directories to `BACKUP_DEST`. Probably the most
common use case where large virtual machine backups are not desirable.


`bdev-backup all`

Backup `BACKUP_DIRS` directories to `BACKUP_DEST`.


`bdev-backup admin`

Tar and Gzip configured directories to `BDEV_UNNAMED_MOUNT`.


`bdev-backup clone`

Clone `BDEV_NAMED_MASTER` to `BDEV_NAMED_SLAVE`.

