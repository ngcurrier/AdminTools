#!/bin/bash

# Remove the artifacts which are around from the last time
rm br.squashfs
rm br.initrd
rm br.ldlinux.c32
rm br.vmlinuz
rm rootcache.tar.gz

# comment out the exports line which corresponds to squashfs
#/srv/tftpdboot/br.squashfs     /smaugNFSRoot squashfs ro,relatime 0 0
sed -i '/smaugNFSRoot/s/^/#/g' /etc/exports

# recycle NFS server
/etc/init.d/nfs-kernel-server reload

# unmount the squashfs
umount /smaugNFSRoot/

# run the boostrap build script (installs to tftp server)
./bootStrapBuild.sh

# remount the squashfs
mount -a

# uncomment the exports line which corresponds to squashfs
sed -i '/smaugNFSRoot/s/^#//g' /etc/exports

# recycle the NFS server, Now the diskless mount is ready to go
/etc/init.d/nfs-kernel-server reload

