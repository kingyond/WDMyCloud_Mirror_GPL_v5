#!/bin/bash
apt-get update && apt-get --no-install-recommends install -y \
apt-utils apt-file pkg-config git vim net-tools locales pax \
wget curl intltool tree build-essential devscripts ca-certificates python \
libncurses-dev bc squashfs-tools \
automake autotools-dev autoconf autopoint autoconf-archive \
libltdl-dev libtool debhelper \
gettext bison texinfo doxygen cmake help2man chrpath \
flex nasm cdbs dh-exec quilt mingw-w64 gperf dejagnu lsb-release cpio \
systemd sharutils time zip xsltproc libxml2-dev zlib1g-dev libselinux1-dev \
dh-php uuid-dev libblkid-dev libdevmapper-dev libpopt-dev libreadline-dev unzip \
dos2unix libusb-dev
apt-get upgrade -y
#dpkg --add-architecture armhf
#apt-get update
apt-get install -y crossbuild-essential-armhf
apt-get install -y u-boot-tools libelf-dev
