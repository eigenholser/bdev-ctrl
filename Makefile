# Drop it in /sbin
install :
	install --mode 644 bdev-functions /sbin;
	install --mode 755 bdev-ctrl /sbin;
	install --mode 755 bdev-backup /sbin;
	install --mode 755 bdev-clone /sbin;
