# Backup Encrypted Device Control

Manage encrypted external devices for Linux backups.

One device is configured as "master" and is mounted on /master. Remaining
device names are considered "slave" and are mounted on /slave. The approach
is to create backup copies by cloning the master.

Each named backup device must have a corresponding keyfile. The keyfile must
use this name with a ".keyfile" suffix.

## Environment Variables

``BDEV_EXCLUDE_DEVICES``
Space delimited list of devices that will not be considered as valid for
use. This is a safety mechanism.

``BDEV_EXCLUDE_DEVICES="sda sdb"``

``BDEV_KEYFILES_PATH``
Path to keyfiles.

``BDEV_KEYFILES_PATH="/path/to/keyfiles"``

``BDEV_NAMED_MASTER``
Mountpoint and command used to mount master device.

``BDEV_NAMED_MASTER="master"``

``BDEV_NAMED_SLAVE``
Mountpoint and command used to mount slave device.

``BDEV_NAMED_SLAVE="slave"``

``BDEV_UNNAMED_MOUNT``
Command and mountpoint used to mount unnamed device. Unnamed means that there
is no corresponding keyfile. The passphrase must be entered by hand.

## Mountpoints

You must create mountpoints: ``/master``, ``/slave`` and ``/admin``.

## Keyfiles and Cipher

For named devices, the cipher and key is located in respective files in
``$BDEV_KEYFILE_PATH``. The format is ``{named_device}.cipher`` and
``{named_device}.keyfile``. ``bdev-ctrl`` will check each of these files
and fail if they are not present.

A reasonable cipher is ``aes-cbc-essiv:sha256``.

The keyfile may be generated like this::

    ``dd if=/dev/random of=$BDEV_KEYFILES_PATH/devname.keyfile bs=1 count=256``

## TODO

``bdev-ctrl admin`` with missing device does not behave correctly.
