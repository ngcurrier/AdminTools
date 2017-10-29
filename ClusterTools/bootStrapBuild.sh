7!/bin/bash
sqset -e

WORK_DIR="$(mktemp --directory --tmpdir build-root.XXXXXXXX)"
trap 'rm -rf "${WORK_DIR}"' EXIT

echo "WORKING DIRECTORY IS: "
echo "${WORK_DIR}"

# if rootcache.tar.gz exists then just create the squashfs and move on
# this is useful if we need to hand edit something there are want to deploy that work
if [ -f rootcache.tar.gz ]; then
    tar --extract --numeric-owner --gzip --file rootcache.tar.gz --directory "${WORK_DIR}" 
    echo "NOT extracting new debootstrap from network, compiling rootcache.tar.gz to squashfs and deploying"
else
    debootstrap --variant=minbase --components=main,non-free --include=linux-image-amd64,net-tools,ifupdown,isc-dhcp-client,openssh-server,less,nano,python,emacs,lvm2,debootstrap,initramfs-tools,libopenmpi-dev,syslinux-common,firmware-bnx2 stretch  "${WORK_DIR}" http://httpredir.debian.org/debian

    # Clean up file with misleading information from host
    rm "${WORK_DIR}/etc/hostname"

    # TODO: create an /etc/init.d/hostname.sh script which does
    # [ -f /etc/hostname ] && HOSTNAME="$(/bin/whereami)"

    # cp whereami script to /bin/whereami
    cp whereami "${WORK_DIR}/bin/"
    
    # Disable installation of recommended packages
    echo 'APT::Install-Recommends "false";' >"${WORK_DIR}/etc/apt/apt.conf.d/50norecommends"

    # Configure networking
    cat >"${WORK_DIR}/etc/network/interfaces" << EOF
auto lo
iface lo inet loopback
auto eno1
auto eno2
iface eth0 inet dhcp
EOF

    # Configure /etc/defaults
    echo ASYNCMOUNTNFS=no >> "${WORK_DIR}/etc/default/rcS"
    echo RAMPTMP=yes >> "${WORK_DIR}/etc/default/tmpfs"

    # copy sources for Debian in case we need live installs, not permanent but maybe useful?
    cp /etc/apt/sources.list "${WORK_DIR}/etc/apt/sources.list"
    
    # This is using google DNS servers
    cat >"${WORK_DIR}/etc/resolv.conf" << EOF
nameserver 8.8.8.8
nameserver 8.8.4.4
EOF
    
    # Setup /etc/fstab for booting to ramdisk root and NFS
    cat > "${WORK_DIR}/etc/fstab" << EOF
#This FSTAB is designed for use on the smaug cluster
proc                    /proc      proc     defaults     0  0
/dev/nfs                /          nfs      tcp,nolock   0  0
none                    /tmp       tmpfs    defaults     0  0
none                    /var/tmp   tmpfs    defaults     0  0
none                    /media     tmpfs    defaults     0  0
none                    /var/log   tmpfs    defaults     0  0
192.168.1.51:/home      /home      nfs      tcp,nolock   1  2
192.168.1.51:/scratch1  /scratch1  nfs      tcp,nolocak  1  2
192.168.1.51:/scratch2  /scratch2  nfs      tcp,nolocak  1  2
EOF

    # create scratch drives for HPC work
    mkdir "${WORK_DIR}/scratch1"
    mkdir "${WORK_DIR}/scratch2"
    
    # Set up initramfs for booting with squashfs+aufs
    cat >> "${WORK_DIR}/etc/initramfs-tools/modules" << EOF
squashfs
aufs
EOF

# we also need to edit the init scripts prior to calling 
# in particular, we need to edit /usr/share/initramfs-tools/scripts/local
# replace line 'mount ${roflag} ${ROOTFLAGS} ${ROOT} ${rootmnt}'
# with :
##mount ${roflag} -t ${FSTYPE} ${ROOTFLAGS} ${ROOT} /ramboottmp
# - Create directory where we will unsquash our filesystem temporarily
# - Create a root filesystem in ram
# - cd into the ramdisk and copy over the unsquash'd rootfs#
#mkdir /ramboottmp
#mount -t squashfs br.squashfs /ramboottmp
#mount -t tmpfs -o size=100% none ${rootmnt}
#cd ${rootmnt}
#cp -rfa /ramboottmp/* ${rootmnt}
#umount /ramboottmp
# This does the above--- only with sed, which is... complex
#    sed -i 's/mount ${roflag} ${ROOTFLAGS} ${ROOT} ${rootmnt}/mkdir \/ramboottmp'\\n'echo "Unwrapping squashed FS"'\\n'echo "PWD"'\\n'pwd'\\n'echo "List of local directory"'\\n'ls'\\n'mount -t squashfs br.squashfs \/ramboottmp'\\n'mount -t tmpfs -o size=100% none ${rootmnt}'\\n'echo "Copying squashfs to tmpfs"'\\n'cp -rfa \/ramboottmp\/* ${rootmnt}'\\n'echo "Unmounting squashfs"'\\n'umount \/ramboottmp/g' '/usr/share/initramfs-tools/scripts/local'

# This uses aufs to glue together two filesystems, we don't need that here
#cat >"${WORK_DIR}/etc/initramfs-tools/scripts/init-bottom/aufs" << EOF
##!/bin/sh -e
#case $1 in
#  prereqs)
#    exit 0
#    ;;
#esac
#mkdir /ro
#mkdir /rw
#mount -n -o mode=0755 -t tmpfs root-rw /rw
#mount -n -o move ${rootmnt} /ro
#mount -n -o dirs=/rw:/ro=ro -t aufs root-aufs ${rootmnt}
#mkdir ${rootmnt}/ro
#mkdir ${rootmnt}/rw
#mount -n -o move /ro ${rootmnt}/ro
#mount -n -o move /rw ${rootmnt}/rw
#EOF
    
    # Implement insecurity
    chroot "${WORK_DIR}" passwd -d root # remove password on root account
    sed -i 's/pam_unix.so nullok_secure/pam_unix.so nullok/' "${WORK_DIR}/etc/pam.d/common-auth"
    sed -i 's/PermitRootLogin without-password/PermitRootLogin yes/' "${WORK_DIR}/etc/ssh/sshd_config"
    sed -i 's/PermitEmptyPasswords no/PermitEmptyPasswords yes/' "${WORK_DIR}/etc/ssh/sshd_config"
    
    # Clean up temporary files
    rm -rf "${WORK_DIR}"/var/cache/apt/*
    
    tar --create --numeric-owner --gzip --file rootcache.tar.gz --directory "${WORK_DIR}" .
fi

# This should happen in case we manually make any changes in all cases
echo "Rebuilding the initramfs"
chmod +x "${WORK_DIR}/etc/initramfs-tools/scripts/init-bottom/aufs"
chroot "${WORK_DIR}" update-initramfs -u
#    chroot "${WORK_DIR}" mkinitramfs -o /boot/initrd.img-ramboot; update-initramfs -u

# Copy across configuration details for users, groups, hosts, etc
echo "Copying passwd, shadow, group, and gshadow over to working image"
cp -p /etc/passwd "${WORK_DIR}/etc/"
cp -p /etc/shadow "${WORK_DIR}/etc/"
cp -p /etc/group "${WORK_DIR}/etc/"
cp -p /etc/gshadow "${WORK_DIR}/etc/"
cp -p /etc/hosts "${WORK_DIR}/etc/"

# Build the root filesystem image, and extract the accompanying kernel and initramfs
echo "Making squashfs, extracting kernel parts"
mksquashfs "${WORK_DIR}" br.squashfs.new -noappend; mv br.squashfs.new br.squashfs
cp -p "${WORK_DIR}/boot"/vmlinuz-* br.vmlinuz.new; mv br.vmlinuz.new br.vmlinuz
cp -p "${WORK_DIR}/boot"/initrd.img-* br.initrd.new; mv br.initrd.new br.initrd
#cp -p "${WORK_DIR}/boot"/initrd.img-ramboot br.initrd.new; mv br.initrd.new br.initrd
cp -p "${WORK_DIR}/usr/lib/syslinux/modules/bios/ldlinux.c32" ldlinux.c32.new; mv ldlinux.c32.new br.ldlinux.c32

# This needs to be copied to the html server
echo "Copying squashfs, vmlinuz, ldlinux.c32, and initrd to servers"
cp br.squashfs /var/www/html/debian-live/br.squashfs
cp br.squashfs /srv/tftpdboot/br.squashfs
cp br.vmlinuz  /srv/tftpdboot/vmlinuz
cp br.initrd   /srv/tftpdboot/initrd.img
cp br.ldlinux.c32 /srv/tftpdboot/ldlinux.c32
