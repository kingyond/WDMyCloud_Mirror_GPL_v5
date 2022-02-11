#!/bin/sh
#
# SPDX-FileCopyrightText: 2020 Western Digital Corporation or its affiliates.
#
# SPDX-License-Identifier: GPL-2.0-or-later
#

insmod	/usr/local/modules/driver/ipv6.ko disable_ipv6=1
insmod	/usr/local/modules/driver/tunnel4.ko
if [ -e /usr/local/modules/driver/ip_tunnel.ko ]; then
insmod	/usr/local/modules/driver/ip_tunnel.ko	2>/dev/null
fi
insmod	/usr/local/modules/driver/sit.ko
insmod	/usr/local/modules/driver/tunnel6.ko	2>/dev/null
insmod	/usr/local/modules/driver/ip6_tunnel.ko	2>/dev/null
insmod	/usr/local/modules/driver/xfrm6_mode_beet.ko
insmod	/usr/local/modules/driver/xfrm6_mode_transport.ko
insmod	/usr/local/modules/driver/xfrm6_mode_tunnel.ko
#insmod	/usr/local/modules/driver/ipip.ko		2>/dev/null

#for new sysctl
if [ -x /usr/bin/sysctl ]; then
	rm /bin/sysctl
	rm /sbin/sysctl
	ln -s /usr/bin/sysctl /bin/sysctl
	ln -s /usr/bin/sysctl /sbin/sysctl
fi

sysctl -w net.ipv6.conf.default.accept_dad=2
sysctl -w net.ipv6.conf.egiga0.accept_dad=2
sysctl -w net.ipv6.conf.default.dad_transmits=1
sysctl -w net.ipv6.conf.egiga0.dad_transmits=1
#sysctl -w net.ipv6.conf.default.optimistic_dad=1
sysctl -w net.ipv6.conf.default.forwarding=0
sysctl -w net.ipv6.conf.default.accept_redirects=1
#sysctl -w net.ipv6.conf.default.use_tempaddr=1

##for tunnel broker
#mkdir /dev/net
#mknod -m 644 /dev/net/tun c 10 200
##insmod /usr/local/modules/driver/tun.ko
#mkdir /etc/template
#cp /usr/local/modules/files/linux.sh /etc/template
#chmod +x /etc/template/linux.sh
##ln -s /bin/ip /sbin/ip
##cp /usr/local/config/gogoc.conf /etc

# for wide-dhcpv6
#cp /usr/local/modules/default/dhcp6c.conf        /usr/local/config/dhcp6c.conf
#cp /usr/local/modules/default/dhcp6c.conf.egiga0 /usr/local/config/dhcp6c.conf.egiga0
#cp /usr/local/modules/default/dhcp6c.conf.egiga1 /usr/local/config/dhcp6c.conf.egiga1 2>/dev/null
#cp /usr/local/modules/default/dhcp6c.conf.bond0  /usr/local/config/dhcp6c.conf.bond0  2>/dev/null
mkdir /var/db
#mkdir /etc/wide-dhcpv6
cp /usr/local/modules/files/dhcp6c-script /etc/wide-dhcpv6
chmod +x /etc/wide-dhcpv6/dhcp6c-script
#cp /usr/local/config/dhcp6c.conf /etc/wide-dhcpv6
if [ ! -d /usr/local/etc ]; then
    mkdir /usr/local/etc
fi
openssl rand -base64 64 > /usr/local/etc/dhcp6cctlkey
ln -s /usr/local/etc/dhcp6cctlkey /etc/wide-dhcpv6/dhcp6cctlkey
