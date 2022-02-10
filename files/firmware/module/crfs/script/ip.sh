#!/bin/sh
#
# SPDX-FileCopyrightText: 2020 Western Digital Corporation or its affiliates.
#
# SPDX-License-Identifier: GPL-2.0-or-later
#

# ip.sh booting ( for system booting )
# ip.sh web_guide_page $interface $ip $netmask $gateway (for web guide page)
# ip.sh dhcp $interface
# ip.sh static $interface $ip $netmask $gateway $dns1 $dns2
# ip.sh stop $interface
# ip.sh set_default_route $interface (0 or 1)
# note : 1. run ip.sh stop $interface before

source /usr/local/modules/files/project_features
SUPPORT_BONDING=$PROJECT_FEATURE_BONDING
SUPPORT_VLAN=$PROJECT_FEATURE_VLAN
SUPPORT_IPV6=$PROJECT_FEATURE_IPV6
LAN_PORT_NUM=$PROJECT_FEATURE_LAN_PORT

#echo "SUPPORT_VLAN=$SUPPORT_VLAN"
#echo "SUPPORT_BONDING=$SUPPORT_BONDING"
#echo "SUPPORT_IPV6=$SUPPORT_IPV6"
#echo "LAN_PORT_NUM=$LAN_PORT_NUM"

iscsi_target_change_ipaddr()
{
	# Run iscsictl to change the listening ip addresses of iSCSI targets.
	if [ "${PROJECT_FEATURE_ISCSI}" = "1" ] ; then
		iSCSI_TARGET=$(xmldbc -g "/system_mgr/iscsi/enable")
		if [ "$iSCSI_TARGET" = "1" ]; then
			iscsictl --change_ipaddr >/dev/null 2>&1 &
		fi
	fi
}

set_route_table()
{
	if [ -e /tmp/dfroute ]; then
		ROUTE=$(awk '{print $1}' /tmp/dfroute)
		if [ "$ROUTE" == "" ];then
			#echo route*******
			DEFAULT_ROUTE=$(route -n | grep 'UG' | awk '{print $8}')
			route -n | grep "$DEFAULT_ROUTE" | sed 's/^.*UG.*$//g' | sed '/^$/d' | \
			awk '{print "route del -net "$1 " netmask "$3 " dev "$8}' > /tmp/dfroute
			chmod +x /tmp/dfroute
			/tmp/dfroute 2>/dev/null
			sed -i 's/route del/route add/g' /tmp/dfroute
			/tmp/dfroute 2>/dev/null
			rm -f /tmp/dfroute
		fi
	fi
}

set_default_gw()
{
	LAN=lan$1
	LANIF=egiga$1

	if [ "$LAN_PORT_NUM" = "2" ]; then
		BOND_ENABLE=$(xmldbc -g "/network_mgr/bonding/enable")
		VLAN_ENABLE=$(xmldbc -g "/network_mgr/lan$1/vlan_enable")
		if [ "$BOND_ENABLE" == "1" ]; then
			if [ "$VLAN_ENABLE" == "1" ];then
				LAN=lan0
				VID=$(xmldbc -g "/network_mgr/$LAN/vlan_id")
				LANIF=bond0.${VID}
			else
				LAN=lan0
				LANIF=bond0
			fi
		else
			if [ "$VLAN_ENABLE" == "1" ];then
				VID=$(xmldbc -g "/network_mgr/$LAN/vlan_id")
				LANIF=$LANIF.${VID}
			fi
		fi
	fi

	while route delete default ; do
		:
	done
	
	if [ "$LAN_PORT_NUM" = "2" ]; then
		if [ "$BOND_ENABLE" == "1" ]; then
			GATEWAY=$(xmldbc -g "/network_mgr/lan0/gateway")
		else
			GATEWAY=$(xmldbc -g "/network_mgr/$LAN/gateway")
		fi
	else
		GATEWAY=$(xmldbc -g "/network_mgr/lan0/gateway")
	fi
	
	if [ "$GATEWAY" != "" ]; then
		route add default gw $GATEWAY dev $LANIF
	else
		route add default dev $LANIF metric 99
	fi
	network -o -s ""
	# zoe_sun 20130814 Mask set_toute_table
	# One day if we have lan0 and lan1 two interface not just bond0, we need to open this and modify it again
#	if [ "$LAN_PORT_NUM" = "2" ]; then
#		if [ "$BOND_ENABLE" == "0" ]; then
#			echo "set_route_table"
#			set_route_table
#		fi
#	fi
}


set_ip()
{
	
	if [ "$SUPPORT_BONDING" == "1" ]; then
		BOND_ENABLE=$(xmldbc -g "/network_mgr/bonding/enable")
	else
		BOND_ENABLE=0	
	fi
	
	if [ "$SUPPORT_VLAN" == "1" ]; then
		if [ "$BOND_ENABLE" == "1" ]; then
			VLAN_ENABLE=$(xmldbc -g "/network_mgr/lan0/vlan_enable")
		else	
			VLAN_ENABLE=$(xmldbc -g "/network_mgr/lan$1/vlan_enable")
		fi
	else
		VLAN_ENABLE=0
	fi
		
    if [ "$BOND_ENABLE" == "1" ]; then 
    	#if [ "$1" == "0" ]; then 
	    	MODE=$(xmldbc -g "/network_mgr/bonding/mode") 
	    	echo "ip.sh bonding {$MODE $2}"
	    	bonding.sh $MODE $2
	
			if [ "$VLAN_ENABLE" == "1" ];then
				echo "ip.sh vlane"
				vlan.sh 0
			fi
	
		#fi
	else
		/etc/rc.d/rc.init.sh $1
	
		if [ "$VLAN_ENABLE" == "1" ]; then
			vlan.sh $1
		fi

		upnpnas.sh restart
	fi
		
	#We don't need to set route table again,because we just have bonding mode 
	#set_route_table
	
	### for ipv6
	if [ "$SUPPORT_IPV6" == "1" ]; then
	    if [ "$BOND_ENABLE" == "1" ]; then
			IPV6_MODE=`xmldbc -g /network_mgr/lan0/ipv6/mode`
		else
			IPV6_MODE=`xmldbc -g /network_mgr/lan$1/ipv6/mode`
		fi

		if [ "$IPV6_MODE" != "off" ]; then
			ipv6.sh $1 start
		fi

		if [ "$IPV6_MODE" == "dhcp" ]; then
			dhcp6c.sh $1 start
		fi
	fi
	### end  for ipv6

	# iSCSI Target
	iscsi_target_change_ipaddr
}

set_ip_down()
{
	
	if [ "$SUPPORT_BONDING" == "1" ]; then
		BOND_ENABLE=$(xmldbc -g "/network_mgr/bonding/enable")
		MODE=$(xmldbc -g "/network_mgr/bonding/mode")
	else
		BOND_ENABLE=0
	fi
	
	if [ "$SUPPORT_VLAN" == "1" ]; then	
		VLAN_ENABLE=$(xmldbc -g "/network_mgr/lan$1/vlan_enable")
		VID=$(xmldbc -g "/network_mgr/lan$1/vlan_id")
	else
		VLAN_ENABLE=0	
	fi	
		
	LANIF=egiga$1
	
#	if [ "$BOND_ENABLE" == "1" ] && [ "$1" == "0" ]; then	#
	if [ "$BOND_ENABLE" == "1" ]; then						# L4A
		if [ "$MODE" == "5" ] || [ "$MODE" == "6" ]; then
			#echo "bond mode $MODE"
			if [ "$VLAN_ENABLE" == "1" ];then
				LANIF=bond0.${VID}
			else
				LANIF=bond0
			fi
			sleep 1						# L4A
			/sbin/ifconfig $LANIF down
			sleep 1						# L4A
			/sbin/ifconfig $LANIF up
			route add -net 224.0.0.0 netmask 240.0.0.0 dev $LANIF
			sleep 1
			set_default_gw 0
		fi
	else
		if [ "$VLAN_ENABLE" == "1" ];then
			LANIF=egiga$1.${VID}
		fi
		/sbin/ifconfig $LANIF 0.0.0.0
	fi

	# iSCSI Target
	iscsi_target_change_ipaddr
}

boot()
{
	if [ "$LAN_PORT_NUM" = "2" ]; then
		LAN0_STATE=`cat /sys/class/net/egiga0/carrier`
		LAN1_STATE=`cat /sys/class/net/egiga1/carrier`
		BOND_ENABLE=$(xmldbc -g "/network_mgr/bonding/enable")
		if [ "1" == "$BOND_ENABLE" ]; then
			set_ip 0 restart
			if [ "$PROJECT_FEATURE_OLED" = "1" ] && [ "1" != "$LAN0_STATE" ] && [ "1" != "$LAN1_STATE" ]; then
				up_send_ctl SysIP1Dis
				up_send_ctl SysIP2Dis
				up_send_ctl SysIPBondSet
			fi
		else
			if [ "1" = "$LAN0_STATE" ]; then
				set_ip 0 restart
			else
				ifconfig egiga0 0.0.0.0
				if [ "$PROJECT_FEATURE_OLED" = "1" ]; then
					up_send_ctl SysIP1Dis
				fi
			fi
		
			if [ "1" = "$LAN1_STATE" ]; then
				set_ip 1 restart
			else
				ifconfig egiga1 0.0.0.0
				if [ "$PROJECT_FEATURE_OLED" = "1" ]; then
					up_send_ctl SysIP2Dis
				fi
			fi
		fi
	else
		set_ip 0
	fi
}

stop_lan()
{
	
	if [ "$SUPPORT_VLAN" == "1" ]; then	
		vlan.sh $1 stop
	fi	
	
	if [ "$SUPPORT_BONDING" == "1" ]; then
		bonding.sh stop
	fi
}

MODEL=$(cat "/usr/local/modules/files/model")
case $1 in
	"booting")
		boot
		;;

	"dhcp")
		set_ip $2 $3
		;;

	"set_ip_down")
		set_ip_down $2
		;;

	"static")
		set_ip $2 $3
		;;

	"set_default_route")
		set_default_gw $2
		;;

	"stop")
		stop_lan $2
		;;

	*)
		echo "Usage $0 {booting|dhcp|static|set_default_route|stop|web_guide_page}"
		;;

esac

exit 0
