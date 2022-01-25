#!/bin/sh
#
# SPDX-FileCopyrightText: 2020 Western Digital Corporation or its affiliates.
#
# SPDX-License-Identifier: GPL-2.0-or-later
#

KERNEL_MODULE_DIR="/usr/local/modules/driver"

check_module_exist()
{
	module=$1
	if [ -e "${KERNEL_MODULE_DIR}/$module" ]; then
		return 0
	fi
	return 1
}

blocking_wait_module_ready()
{
	module=$1
	name=$(echo -n $module | sed 's/.ko$//g')

	retry=10
	while [ $retry -gt 0 ]
	do
		if lsmod | grep -q -e "^$name[[:space:]]" ; then
			return;
		fi
		retry=$(expr $retry - 1)
		usleep 100000
	done
}

insmod_when_not_loaded()
{
	module=$1
	shift 1

	if ! check_module_exist "$module" ; then
		return 0
	fi

	name=$(echo -n $module | sed 's/.ko$//g')
	if [ -z "$name" ]; then
		return 1
	fi

	if ! lsmod | grep -q -e "^$name[[:space:]]" ; then
		echo "Loading $module"
		if ! insmod "${KERNEL_MODULE_DIR}/$module" $@ ; then
			echo failed to load $module
			return 1
		fi

		# Wait up to 1 second to make sure the module is ready
		blocking_wait_module_ready $module
	fi
	return 0
}

insmod_no_check()
{
	module=$1
	shift 1

	if ! check_module_exist "$module" ; then
		return 0
	fi

	echo "Loading $module"
	if ! insmod "${KERNEL_MODULE_DIR}/$module" $@ > /dev/null 2>&1 ; then
		return 1
	fi

	# Wait up to 1 second to make sure the module is ready
	blocking_wait_module_ready $module

	return 0
}

check_ipv6_installed()
{
	if [ -e /sys/module/ipv6 ]; then
		return 0
	fi
	return 1
}

iptables_common_setup()
{
	# Create soft link of iptables to iptables-legacy
	if [ ! -e /usr/sbin/iptables ]; then
		ln -s /usr/sbin/iptables-legacy /usr/sbin/iptables
		ln -s /usr/sbin/iptables-legacy-save /usr/sbin/iptables-save
		ln -s /usr/sbin/iptables-legacy-restore /usr/sbin/iptables-restore
	fi

	# Insert kernel modules for iptables and netfilter
	insmod_when_not_loaded "x_tables.ko" || return 1
	insmod_when_not_loaded "nf_conntrack.ko"
	insmod_when_not_loaded "xt_conntrack.ko"
	insmod_when_not_loaded "xt_state.ko"
	insmod_when_not_loaded "xt_tcpudp.ko"

	# Load recent, log, limit modules for brute force protection on ssh service.
	insmod_when_not_loaded "xt_recent.ko" ip_list_tot=100 ip_pkt_list_tot=210
	insmod_when_not_loaded "xt_LOG.ko"
	insmod_when_not_loaded "nf_log_common.ko"
	insmod_when_not_loaded "xt_limit.ko"
	return 0
}

iptables_setup()
{
	# Insert kernel modules for iptables
	insmod_no_check "ip_tables.ko"
	insmod_no_check "iptable_filter.ko"
	insmod_no_check "nf_defrag_ipv4.ko"
	insmod_no_check "nf_conntrack_ipv4.ko"

	# Load log module for brute force protection on ssh service.
	insmod_no_check "nf_log_ipv4.ko"
	insmod_no_check "ipt_LOG.ko"
}

ip6tables_setup()
{
	if ! check_ipv6_installed ; then
		return
	fi

	# Create soft link of ip6tables to ip6tables-legacy
	if [ ! -e /usr/sbin/ip6tables ]; then
		ln -s /usr/sbin/ip6tables-legacy /usr/sbin/ip6tables
		ln -s /usr/sbin/ip6tables-legacy-save /usr/sbin/ip6tables-save
		ln -s /usr/sbin/ip6tables-legacy-restore /usr/sbin/ip6tables-restore
	fi

	# Insert kernel modules for ip6tables
	insmod_no_check "ip6_tables.ko"
	insmod_no_check "ip6table_filter.ko"
	insmod_no_check "nf_defrag_ipv6.ko"
	insmod_no_check "nf_conntrack_ipv6.ko"

	# Load log module for brute force protection on ssh service.
	insmod_no_check "nf_log_ipv6.ko"
	insmod_no_check "ip6t_LOG.ko"
}

if [ "$1" == "ipv4" ]; then
	iptables_common_setup
	iptables_setup
elif [ "$1" == "ipv6" ]; then
	iptables_common_setup
	ip6tables_setup
elif [ "$1" == "all" ]; then
	iptables_common_setup
	iptables_setup
	ip6tables_setup
else
	echo "$0 : wrong parameter!"
fi

exit 0
