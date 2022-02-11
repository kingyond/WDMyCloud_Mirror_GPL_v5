#!/bin/sh
#
# SPDX-FileCopyrightText: 2020 Western Digital Corporation or its affiliates.
#
# SPDX-License-Identifier: GPL-2.0-or-later
#

# $1 : interface ( "0" or "1" )
# $2 : start or stop

Usage()
{
	echo "usage: ipv6.sh interface# {start | stop}"
	echo "    where options are :"
	echo "      interface#:    0 or 1"
	exit 1
}

iscsi_target_change_ipaddr()
{
	# Run iscsictl to change the listening ip addresses of iSCSI targets.
	if command -v iscsictl > /dev/null 2>&1 ; then
		iSCSI_TARGET=$(xmldbc -g "/system_mgr/iscsi/enable")
		if [ "$iSCSI_TARGET" = "1" ]; then
			iscsictl --change_ipaddr >/dev/null 2>&1 &
		fi
	fi
}


# add dns to resolv.conf
set_dns_conf()
{
	network -r
	return
	
	RESOLV_CONF=/etc/resolv.conf
	DNS=$(xmldbc -g "/network_mgr/$LAN/ipv6/dns1")
	if [ "$DNS" != "" ]; then
		DOMAIN_NAME=`cat $RESOLV_CONF | grep "nameserver $DNS$"`
		if [ "$DOMAIN_NAME" == "" ]; then
			echo "nameserver $DNS" >> $RESOLV_CONF
		fi
	fi

	DNS2=$(xmldbc -g "/network_mgr/$LAN/ipv6/dns2")
	if [ "$DNS2" != "" ]; then
		DOMAIN_NAME=`cat $RESOLV_CONF | grep "nameserver $DNS2$"`
		if [ "$DOMAIN_NAME" == "" ]; then
			echo "nameserver $DNS2" >> $RESOLV_CONF
		fi
	fi

	# done by UI
#	if [ "$DNS" != "" -o "$DNS2" != "" ]; then
#		xmldbc -s /network_mgr/$LAN/ipv6/dns_manual 1
#		xmldbc -D /etc/NAS_CFG/config.xml
#		save_mtd  /etc/NAS_CFG/config.xml
#	else
#		xmldbc -s /network_mgr/$LAN/ipv6/dns_manual 0
#	fi
}

if [ "$1" != "0" -a "$1" != "1" ]; then
	Usage
fi

if [ "$1" == "0" ]; then
	LAN=lan0
else
	LAN=lan1
fi

BOND_ENABLE=`xmldbc -g /network_mgr/bonding/enable`
VLAN_ENABLE=$(xmldbc -g "/network_mgr/$LAN/vlan_enable")
VID=$(xmldbc -g "/network_mgr/$LAN/vlan_id")

IPV6_MODE=$(xmldbc -g "/network_mgr/lan0/ipv6/mode")
if [ "$IPV6_MODE" == "off" ]; then
	IPV6_ENABLE_0=0
else
	IPV6_ENABLE_0=1
fi
IPV6_MODE=$(xmldbc -g "/network_mgr/lan1/ipv6/mode")
if [ "$IPV6_MODE" == "off" ]; then
	IPV6_ENABLE_1=0
else
	if [ "$IPV6_MODE" != "" ]; then
		IPV6_ENABLE_1=1
	else
		IPV6_ENABLE_1=0
	fi
fi

if [ "$BOND_ENABLE" == "1" ]; then
	if [ "$1" == "1" ]; then
		echo "only one bonding driver"
		exit 1
	else
		if [ "$VLAN_ENABLE" == "1" ]; then
			IFACE=bond0.$VID
		else
			IFACE=bond0
		fi
	fi
else
	if [ "$VLAN_ENABLE" == "1" ]; then
		IFACE=egiga$1.$VID
	else
		IFACE=egiga$1
	fi
fi

case $2 in
	start)
#		if [ "$IPV6_ENABLE_$1" == "0" ]; then
#			exit 1
#		fi
		sysctl -w net.ipv6.conf.default.disable_ipv6=0
		sysctl -w net.ipv6.conf.$IFACE.disable_ipv6=0
		sysctl -w net.ipv6.conf.lo.disable_ipv6=0

		#
		IPV6_MODE=$(xmldbc -g "/network_mgr/$LAN/ipv6/mode")

		case $IPV6_MODE in
			off)
				;;
			auto)
				sysctl -w net.ipv6.conf.$IFACE.accept_ra=1

				# add dns to resolv.conf
				set_dns_conf

				getIPv6Address.sh $1
				;;
			dhcp)
				sysctl -w net.ipv6.conf.$IFACE.accept_ra=0
				
				xmldbc -s /network_mgr/$LAN/ipv6/dhcp_ipv6address ""
				xmldbc -s /network_mgr/$LAN/ipv6/dhcp_prefix_length ""

				# add dns to resolv.conf
				DNS_MANUAL=$(xmldbc -g "/network_mgr/$LAN/ipv6/dns_manual")
				if [ "$DNS_MANUAL" == "1" ]; then
					set_dns_conf
				fi

				iscsi_target_change_ipaddr
				;;
			static)
				sysctl -w net.ipv6.conf.$IFACE.accept_ra=0
				
				IPV6_ADDR=$(xmldbc -g "/network_mgr/$LAN/ipv6/item:1/ipv6address")
				PREFIX_LENGTH=$(xmldbc -g "/network_mgr/$LAN/ipv6/item:1/prefix_length")
				ip -6 addr  add $IPV6_ADDR/$PREFIX_LENGTH dev $IFACE
				#ip -6 route add $IPV6_ADDR/128 dev lo
				#ip -6 route add $IPV6_ADDR/$PREFIX_LENGTH dev $IFACE
				GATEWAY=$(xmldbc -g "/network_mgr/$LAN/ipv6/gateway")
				if [ "$GATEWAY" != "" ]; then
					ip -6 route add $IPV6_ADDR/$PREFIX_LENGTH via $GATEWAY dev $IFACE
					#route -A inet6 add ::/0 gw $GATEWAY dev $IFACE
					#ip -6 route add ::/0    via $GATEWAY dev $IFACE
					ip -6 route add default via $GATEWAY dev $IFACE
				fi

				# add dns to resolv.conf
				set_dns_conf

				iscsi_target_change_ipaddr
				;;
		esac

		;;

	stop)
#		if [ "$IPV6_ENABLE_$1" == "1" ]; then
#			exit 1
#		fi

		#
		IPV6_MODE=$(xmldbc -g "/network_mgr/$LAN/ipv6/mode")
		case $IPV6_MODE in
			off)
				sysctl -w net.ipv6.conf.$IFACE.disable_ipv6=1

				if [ "$IPV6_ENABLE_0" == "0" -a "$IPV6_ENABLE_1" == "0" ]; then
					sysctl -w net.ipv6.conf.default.disable_ipv6=1
					sysctl -w net.ipv6.conf.lo.disable_ipv6=1
				fi

				iscsi_target_change_ipaddr
				;;
			auto)
				sysctl -w net.ipv6.conf.$IFACE.accept_ra=0

				xmldbc -s /network_mgr/$LAN/ipv6/local_ipv6address ""
				xmldbc -s /network_mgr/$LAN/ipv6/local_prefix_length ""

				COUNT=$(xmldbc -g "/network_mgr/$LAN/ipv6/count")
				#echo COUNT=$COUNT
				item=1
				while [ "$item" -le "$COUNT" ];
				do
					IPV6_ADDR=$(xmldbc -g "/network_mgr/$LAN/ipv6/item:$item/ipv6address")
					PREFIX_LENGTH=$(xmldbc -g "/network_mgr/$LAN/ipv6/item:$item/prefix_length")
					ip -6 addr  del $IPV6_ADDR/$PREFIX_LENGTH dev $IFACE

					xmldbc -s /network_mgr/$LAN/ipv6/item:$item/ipv6address   ""
					xmldbc -s /network_mgr/$LAN/ipv6/item:$item/prefix_length ""
        			item=`expr $item + 1`
					#echo item=$item
				done
				xmldbc -s /network_mgr/$LAN/ipv6/count 0
				
				GATEWAY=$(xmldbc -g "/network_mgr/$LAN/ipv6/gateway")
				if [ "$GATEWAY" != "" ]; then
					route -A inet6 del ::/0 via $GATEWAY 2>/dev/null	# delete default route
					#ip -6 route del ::/0 via $GATEWAY dev $IFACE
				fi

				xmldbc -D /etc/NAS_CFG/config.xml
				;;
			dhcp)
				DHCP_IPV6_ADDR=$(xmldbc -g "/network_mgr/$LAN/ipv6/dhcp_ipv6address")
				if [ "$DHCP_IPV6_ADDR" != "" ]; then
					ip -6 route del $DHCP_IPV6_ADDR/64 dev $IFACE	#? for samba
				fi
				
				xmldbc -s /network_mgr/$LAN/ipv6/dhcp_ipv6address ""
				xmldbc -s /network_mgr/$LAN/ipv6/dhcp_prefix_length ""

				GATEWAY=$(xmldbc -g "/network_mgr/$LAN/ipv6/gateway")
				if [ "$GATEWAY" != "" ]; then
					#route -A inet6 del ::/0 via $GATEWAY 2>/dev/null	# delete default route
					ip -6 route del default via $GATEWAY dev $IFACE		# delete default route
				fi

				# remove dns from resolv.conf
				DNS_MANUAL=$(xmldbc -g "/network_mgr/$LAN/ipv6/dns_manual")
				if [ "$DNS_MANUAL" == "1" ]; then

					RESOLV_CONF=/etc/resolv.conf
					DNS=$(xmldbc -g "/network_mgr/$LAN/ipv6/dns1")
					if [ "$DNS" != "" ]; then
						cat $RESOLV_CONF | sed -e "s/nameserver $DNS//g" -e '/^$/d'  > resolv.conf.tmp
						mv resolv.conf.tmp $RESOLV_CONF
					fi

					RESOLV_CONF=/etc/resolv.conf
					DNS=$(xmldbc -g "/network_mgr/$LAN/ipv6/dns2")
					if [ "$DNS" != "" ]; then
						cat $RESOLV_CONF | sed -e "s/nameserver $DNS//g" -e '/^$/d'  > resolv.conf.tmp
						mv resolv.conf.tmp $RESOLV_CONF
					fi

				fi
				;;
			static)
				IPV6_ADDR=$(xmldbc -g "/network_mgr/$LAN/ipv6/item:1/ipv6address")
				PREFIX_LENGTH=$(xmldbc -g "/network_mgr/$LAN/ipv6/item:1/prefix_length")
							#echo PREFIX_LENGTH:$PREFIX_LENGTH
							#echo IPV6_ADDR:$IPV6_ADDR
				ip -6 addr  del $IPV6_ADDR/$PREFIX_LENGTH dev $IFACE
				
				#ip -6 route del $IPV6_ADDR/128 dev lo
				#ip -6 route del $IPV6_ADDR/$PREFIX_LENGTH dev $IFACE
				GATEWAY=$(xmldbc -g "/network_mgr/$LAN/ipv6/gateway")
				if [ "$GATEWAY" != "" ]; then
					#route -A inet6 del ::/0 dev $IFACE
					ip -6 route del $IPV6_ADDR/$PREFIX_LENGTH via $GATEWAY dev $IFACE
					ip -6 route del default via $GATEWAY dev $IFACE
				fi
				;;
		esac

		;;

	"")
		Usage
		;;
	*)
		Usage
		;;
esac
