# Encrypted Backup Device Control

Manage encrypted external devices with plausable deniability for Linux backups.

## The Backup Strategy

One device is configured as "master" and is mounted on ``/master``. Remaining
device names are considered "slave" and are mounted on ``/slave``. The approach
is to create backup copies by cloning the master. This allows additional
backup copies to be made without taking down system services for the duration.

Also, unnamed devices may be attached using an interactive passphrase only.
The purpose of this is to securely backup the keyfiles! Consider using small
USB flash drives for this purpose.

Attach and detach modes are used only for initialization and troubleshooting.

## Installation

For the impatient, do this:

    sudo make install

That will install the ``bdev-ctrl`` shell script to ``/sbin``.

Now read the sections below on configuration and device initialization.

## Configuration

Several environment variables are required. Directories to use as mount points
are also required.

### Environment Variables

``BDEV_EXCLUDE_DEVICES``

Space delimited list of devices that will not be considered as valid for
use. This is a safety mechanism:

    BDEV_EXCLUDE_DEVICES="sda sdb"

``BDEV_KEYFILES_PATH``

Path to keyfiles.

    BDEV_KEYFILES_PATH="/path/to/keyfiles"

``BDEV_NAMED_MASTER``

Mountpoint and command used to mount master device.

    BDEV_NAMED_MASTER="master"

``BDEV_NAMED_SLAVE``

Mountpoint and command used to mount slave device.

    BDEV_NAMED_SLAVE="slave"

``BDEV_UNNAMED_MOUNT``

Command and mountpoint used to mount unnamed device. Unnamed means that there
is no corresponding keyfile. The passphrase must be entered by hand. My
convention is to use ``admin``.

### Mountpoints

You must create mountpoints that correspond to ``BDEV_NAMED_MASTER``,
``BDEV_NAMED_SLAVE``, and ``BDEV_UNNAMED_MOUNT``. Examples are: ``/master``,
``/slave`` and ``/admin``.

## Device Initialization

Prior to use, devices must be initialized.

### Keyfiles and Cipher

Each named backup device must have a corresponding keyfile and cipher file. The
keyfile must use the device name with a ``.keyfile`` suffix. The cipher file
specifies the cipher to be used. It must use the device name with a ``.cipher``
suffix.

For named devices, the cipher and key is located in respective files in
``$BDEV_KEYFILE_PATH``. The format is ``{named_device}.cipher`` and
``{named_device}.keyfile``. ``bdev-ctrl`` will check each of these files
and fail if they are not present.

A reasonable cipher is ``aes-cbc-essiv:sha256``. Create file
``$BDEV_KEYFILE_PATH/{named_device}.cipher`` with a single line containing
the cipher. See ``cryptsetup --help`` for a list of compiled in cipher
parameters.

The keyfile may be generated like this:

    dd if=/dev/random of=$BDEV_KEYFILES_PATH/devname.keyfile bs=1k count=8

Since this uses ``/dev/random``, you may need to exercise your system for awhile
to generate entropy. Alternatively, for faster generation, use ``/dev/urandom``.

### Prepare the device

#### Named Device

Since the device is initially without a filesystem, it must first be attached.
Then the filesystem may be created. For a named device:

    bdev-ctrl attach sdc bd-0

This will create the mapped device ``/dev/mapper/bd-0_crypt``. At this point,
you must decide whether or not to create a partition or use the entire device.
For this purpose, it is fine to dedicate the entire device. ``bdev-ctrl`` will
look for ``/dev/mapper/bd-0_crypt1`` also so you may create a single partition
spanning the entire device. If you create multiple partitions, only the first
will be used.

Here is how to create the partition:

    parted /dev/mapper/bd-0_crypt mklabel gpt
    parted /dev/mapper/bd-0_crypt mkpart primary ext2 0% 100%

Create the filesystem:

    mke2fs -j -t ext4 /dev/mapper/bd-0_crypt1

At this point, the device mapping may be removed:

    bdev-ctrl detach bd-0

Then, bring up the device as usual:

    bdev-ctrl master sdc bd-0

The device will now be mounted on ``/master``.

The final step in device initialization is optional. This step fills the
entire device with high-entropy data.

    dd if=/dev/zero of=/master/bigfile.dat bs=1M

This may take several hours. When the device runs out of space, just delete
``/master/bigfile.dat``.

Initialization is complete.

#### Unnamed Device

For an unnamed device, the process is identical to the instructions for a
named device above. The only difference is in how ``bdev-ctrl`` is used to
attach:

    bdev-ctrl attach sdc

Then the device will be mapped to ``/dev/mapper/admin_crypt``. The remaining
instructions are the same.

### Flash Memory Devices and Wear Leveling

Flash memory has limited write cycles. Keep this in mind as you fill the
entire device with high-entropy data. There are other considerations here that
are beyond the scope of this README.

