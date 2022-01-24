#!/bin/bash

# Copyright (c) 2020 Western Digital Corporation or its affiliates.
#
# This code is CONFIDENTIAL and a TRADE SECRET of Western Digital
# Corporation or its affiliates ("WD").  This code is protected
# under copyright laws as an unpublished work of WD.  Notice is
# for informational purposes only and does not imply publication.
#
# The receipt or possession of this code does not convey any rights to
# reproduce or disclose its contents, or to manufacture, use, or sell
# anything that it may describe, in whole or in part, without the
# specific written consent of WD.  Any reproduction or distribution
# of this code without the express written consent of WD is strictly
# prohibited, is a violation of the copyright laws, and may subject you
# to criminal prosecution.

export KBUILD_BUILD_USER=kman
export KBUILD_BUILD_HOST=kmachine
export KCFLAGS="-DWD_CUSTOMIZE"
export BUILDNO=1
kernel_version=linux-4.14.22
netatop_version=netatop-2.0
cryptodev_version=cryptodev-linux-1.10
exfat_linux_version=exfat-linux
rstbtn_version=rstbtn
paragon_driver_ver=
soc_chip=
log_name=build_kernel.log
BUILD_KERNEL_ROOT_PATH=
build_kernel_out_list=built_kernel.txt

#chip_vendor need to modify in build linux root folder mode
#ex:chip_vendor=marvell
chip_vendor=
#normal build , root_folder_build=NO
#build in linux folder , root_folder_build=YES
root_folder_build=NO
g_model_name=

PROJECT_LIST=(
    "Yellowstone" "marvell" "WDMyCloudEX4100" \
    "Yosemite" "marvell" "WDMyCloudEX2100" \
    "GrandTeton" "marvell" "WDMyCloudMirror" \
    "RangerPeak" "marvell" "WDMyCloudEX2Ultra" \
    "Glacier" "marvell" "WDMyCloud" \
    "BlackCanyon" "intel" "WDMyCloudPR4100" \
    "BryceCanyon" "intel" "WDMyCloudPR2100" \
    "Sprite" "intel" "WDMyCloudDL4100" \
    "Aurora" "intel" "WDMyCloudDL2100"
)

PARAGON_VERSION_LIST=(
    "Yellowstone" "k4.14.22_2020-07-27__RC_31" \
    "Yosemite" "k4.14.22_2020-07-27__RC_31" \
    "GrandTeton"  "k4.14.22_2020-02-13__RC_13" \
    "RangerPeak"  "k4.14.22_2020-07-27__RC_31" \
    "Glacier"  "k4.14.22_2020-03-31__RC_20" \
    "BlackCanyon" "k4.14.22_2019-12-30__RC_13" \
    "BryceCanyon" "k4.14.22_2019-12-30__RC_13" \
    "Sprite"      "k4.14.22_2020-01-20__RC_16" \
    "Aurora"      "k4.14.22_2020-01-20__RC_16"
)

function die()
{
    echo "$@"
    if [ -n "$BUILD_KERNEL_ROOT_PATH" ]; then
        echo "$@" >> ${BUILD_KERNEL_ROOT_PATH}/${log_name}
    fi
    exit 1
}

function LOG()
{
    echo "$@"
    if [ -n "$BUILD_KERNEL_ROOT_PATH" ]; then
        echo "$@" >> ${BUILD_KERNEL_ROOT_PATH}/${log_name}
    fi
}

function Help()
{
    echo "Usage:"
    if [ -e platform_chip_vendor.txt ]; then
        echo "    ./xbuild.sh [build/clean]"
        echo "ex: ./xbuild.sh build"
        echo "ex: ./xbuild.sh clean"
    else
        if [ "${root_folder_build}" = "NO" ]; then
            echo "    ./xbuild.sh [Build_Num/clean/untar/src] [platform]"
            echo "ex: ./xbuild.sh 1 GrandTeton"
            echo "ex: ./xbuild.sh clean GrandTeton"
            echo "ex: ./xbuild.sh untar GrandTeton"
            echo "ex: ./xbuild.sh src GrandTeton"
        else
            echo "    ./xbuild.sh [build/clean]"
            echo "ex: ./xbuild.sh build"
            echo "ex: ./xbuild.sh clean"
        fi
    fi
    exit 0
}

function Get_Chip_Vendor()
{
    local model_name=$1
    for index in ${!PROJECT_LIST[@]}; do
        if [ $(($index%3)) == 0 ] ; then
            project=${PROJECT_LIST[index]}
            index=$index+1
            if [ "${model_name}" = "${project}" ]; then
                g_model_name=${project}
                chip_vendor=${PROJECT_LIST[index]}
                index=$index+1
                product=${PROJECT_LIST[index]}
            fi
        fi
    done
    LOG "chip_vendor=$chip_vendor"
}

function Chk_Model_Name()
{
    local model_name=$1
    local chk_model_status=0

    for index in ${!PROJECT_LIST[@]}; do
        if [ $(($index%3)) == 0 ] ; then
            project=${PROJECT_LIST[index]}
            #echo "project=$project"
            index=$index+1
            if [ "${model_name}" = "${project}" ]; then
                chk_model_status=1
            fi
            index=$index+1
            product=${PROJECT_LIST[index]}
        fi
    done
    if [ $chk_model_status -eq 0 ]; then
        die "Not support $model_name mode."
    fi
}

function Get_Paragon_Version()
{
    local model_name=$1
    for index in ${!PARAGON_VERSION_LIST[@]}; do
        if [ $(($index%2)) == 0 ] ; then
            project=${PARAGON_VERSION_LIST[index]}
            index=$index+1
            if [ "${model_name}" = "${project}" ]; then
                paragon_driver_ver=${PARAGON_VERSION_LIST[index]}
                break
            fi
        fi
    done
    echo "paragon_driver_ver=$paragon_driver_ver"
}

function Untar_File()
{
    local file_name=$1

    rm -rf ${file_name}

    if [ ! -e ${file_name}.tar.gz ]; then
        die "Can not find ${file_name}.tar.gz"
    fi

    LOG "Decompress ${file_name}.tar.gz"
    tar -zxf ${file_name}.tar.gz || die "Can not decompress ${file_name}.tar.gz"
}

function Patch_File()
{
    local patch_kver=$1
    local patch_path=$2

    cd $patch_kver
    for patch_name in `ls ../${patch_path} 2>/dev/null`; do
        LOG "-->patch name=$patch_name"
        patch -p1 -i ../${patch_path}/${patch_name} || die "patch $patch_name failed"
    done
    cd ..
}

function Decompress_Kernel()
{
    local kver=${1}
    local model_name=${2}
    local platform_patch_path=${kver}_patch/platform/${model_name}/
    local build_name=${kver}.${model_name}

    LOG "Decompress Kernel ${kver}"
    LOG "model_name=$model_name"
    LOG "platform_patch_path=$platform_patch_path"

    #if jenkins build , always remove folder
    if [ "${ROLE}" = "jenkins" ] ; then
        rm -rf -d ${build_name}
    fi

    if [ ! -d ${build_name} ]; then
        if [ ! -d ${platform_patch_path} ]; then
            die "Can not find $patch folder"
        fi
        Untar_File ${kver}
        if [ "${chip_vendor}" = "marvell" ] && [ "${g_model_name}" != "Glacier" ]; then
            echo "--> marvell SOC patch"
            soc_chip=A38X
            local SOC_patch_path=${kver}_patch/SOC/${soc_chip}/
            Patch_File ${kver} ${SOC_patch_path}
        fi
        Patch_File ${kver} ${platform_patch_path}
        mv ${kver} ${build_name}
    fi

    if [ -e ${build_name}/jenkins_build_test ]; then
        rm -f ${build_name}/jenkins_build_test
    fi

    LOG "Decompress Kernel Success"
}

function Compress_Platform_Kernel_SRC
{
    local model_name=$1
    local platform_chip_vendor=platform_chip_vendor.txt
    local out_src_file=
    local platform_kernel_name=${kernel_version}.${model_name}

    date_time=`date +%Y%m%d`
    echo "date_time=$date_time"
    out_src_file=kernel-${kernel_version#*-}_${model_name}_src_${date_time}.tar.gz

    LOG "Compress kernel binary ${out_src_file}"

    Get_Chip_Vendor $model_name

    if [ "$chip_vendor" != "marvell" ] && [ "$chip_vendor" != "intel" ]; then
        die "$chip vendor is not support."
    fi

    echo $chip_vendor > ${platform_kernel_name}/${platform_chip_vendor}
    cp xbuild.sh ${platform_kernel_name}

    if [ ! -d ../out/${model_name} ]; then
        mkdir -p ../out/${model_name}
    fi

    rm -rf ../out/${model_name}/${out_src_file}
    tar zcf ../out/${model_name}/${out_src_file} ${platform_kernel_name}

    LOG "output src file : ../out/${model_name}/${out_src_file}"
}

function Compress_Platform_Kernel_GPL_SRC
{
    local model_name=$1
    local platform_chip_vendor=platform_chip_vendor.txt
    local out_src_file=
    local platform_kernel_name=${kernel_version}.${model_name}

    out_src_file=${kernel_version}.tar.gz
    LOG "Compress kernel binary ${out_src_file}"

    Get_Chip_Vendor $model_name

    if [ "$chip_vendor" != "marvell" ] && [ "$chip_vendor" != "intel" ]; then
        die "$chip vendor is not support."
    fi

    echo $chip_vendor > ${platform_kernel_name}/${platform_chip_vendor}
    cp xbuild.sh ${platform_kernel_name}

    if [ ! -d ../out/${model_name} ]; then
        mkdir -p ../out/${model_name}
    fi

    rm -rf ../out/${model_name}/${out_src_file}
    mv ${platform_kernel_name} ${kernel_version}
    tar zcf ../out/${model_name}/${out_src_file} ${kernel_version}
    rm -rf ${kernel_version}
    LOG "output src file : ../out/${model_name}/${out_src_file}"
}

function Decompress_module()
{
    current_path=`pwd`
    module_name=$1
    LOG "Decompress ext_kernel_modules ${module_name}"

    folder=ext_kernel_modules/${module_name}
    cd ../$folder
    if [ -d ${module_name} ]; then
        rm -rf ${module_name}
    fi
    tar -zxf ${module_name}.tar.gz || die "Can not untar ${module_name}.tar.gz"
    Patch_File ${module_name} patch
    cd $current_path
}

function build_external_module()
{
    module_path=$1
    cd ${BUILD_KERNEL_ROOT_PATH}/../ext_kernel_modules/${module_path}/
    ./xbuild.sh build || die "build external module ${module_path} failed"
    cd ${KERNELDIR}
}

function prepare_paragon_driver()
{
    paragon_version=$1
    echo "Build ${model_name} Paragon driver version : $paragon_version"
    cd ${BUILD_KERNEL_ROOT_PATH}/../ext_kernel_modules/Paragon/${model_name}/${paragon_version}
    paragon_driver_name=`ls ufsd_driver_package_Build*`
    cd -
    echo "paragon_driver_name=$paragon_driver_name"
    rm -rf ${BUILD_KERNEL_ROOT_PATH}/../ext_kernel_modules/Paragon/ufsd_driver
    mkdir ${BUILD_KERNEL_ROOT_PATH}/../ext_kernel_modules/Paragon/ufsd_driver
    tar zxvf ${BUILD_KERNEL_ROOT_PATH}/../ext_kernel_modules/Paragon/${model_name}/${paragon_version}/${paragon_driver_name} -C ${BUILD_KERNEL_ROOT_PATH}/../ext_kernel_modules/Paragon/ufsd_driver
    cp ${BUILD_KERNEL_ROOT_PATH}/../ext_kernel_modules/Paragon/xbuild.sh ${BUILD_KERNEL_ROOT_PATH}/../ext_kernel_modules/Paragon/ufsd_driver
    cd ${BUILD_KERNEL_ROOT_PATH}/../ext_kernel_modules/Paragon/ufsd_driver
    sed -i 's/KERNEL_SOURCE_PATH=/#KERNEL_SOURCE_PATH=/g' build-ufsd.conf
    sed -i 's/KERNEL_BUILD_PATH=/#KERNEL_BUILD_PATH=/g' build-ufsd.conf
    #sed -i 's/BUILD_DEBUG_VERSION=0/BUILD_DEBUG_VERSION=1/g' build-ufsd.conf
    if [ "${chip_vendor}" = "marvell" ]; then
        sed -i 's/COMPILER_PATH=/COMPILER_PATH=\/usr\/bin/g' build-ufsd.conf
    fi
    cd -
}

function build_paragon_driver()
{
    export KERNEL_SOURCE_PATH=`pwd`
    export KERNEL_BUILD_PATH=`pwd`
    Get_Paragon_Version ${model_name}
    prepare_paragon_driver $paragon_driver_ver || exit 1
    build_external_module Paragon/ufsd_driver || exit 1
}

function build_marvell()
{
    echo ""
    echo "--> Build Marvell Kernel <--"
    export BASEVERSION=ga-18.09.3

    export ARCH=arm
    export CROSS_COMPILE=arm-linux-gnueabihf-
    export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

    if [ "${g_model_name}" = "Glacier" ]; then
        dbs_file="armada-375-db.dts"
    else
        cp arch/arm/boot/dts/WD/* arch/arm/boot/dts/
        dbs_file=`ls arch/arm/boot/dts/WD/ | awk '{ print $1 }'`
    fi
    dtb_file=${dbs_file%.*}.dtb

    rm -f arch/arm/boot/zImage .version
    rm -f arch/arm/boot/zImage_dtb

    make -j`nproc` zImage || exit 1
    make dtbs || exit 1
    cat arch/arm/boot/zImage arch/arm/boot/dts/${dtb_file} > arch/arm/boot/zImage_dtb || exit 1

    ./scripts/mkuboot.sh -A arm -O linux -T kernel -C none -a 0x00008000 -e 0x00008000 -n 'Kernel' -d arch/arm/boot/zImage_dtb arch/arm/boot/uImage || exit 1
    rm -rf _install
    make -j`nproc` modules || exit 1
    make modules_install INSTALL_MOD_PATH=_install
    if [ "${root_folder_build}" = "NO" ]; then
        # netatop
        export KERNELDIR=`pwd`
        build_external_module ${netatop_version} || exit 1
        build_external_module ${cryptodev_version} || exit 1

	if [ "${g_model_name}" != "GrandTeton" -a "${g_model_name}" != "Glacier" ]; then
		build_external_module ${exfat_linux_version} || exit 1
	fi

        build_paragon_driver
    fi
    rm -f arch/arm/boot/dts/${dbs_file}
}

function build_intel()
{
    echo ""
    echo "--> Build Intel Kernel <--"
    export ARCH=x86_64

    # ITR-99975, for Intel platforms, leave BASEVERSION empty.
    export BASEVERSION=

    IMAGE_NAME=bzImage
    if [ -z "$ARCH" ] ; then
    echo "do \"export ARCH=x86_64\" first."
    exit 1
    fi

    rm -f .version

    make -j`nproc` ${IMAGE_NAME} || exit 1
    make -j`nproc` modules || exit 1
    make modules_install INSTALL_MOD_PATH=_install
    if [ "${root_folder_build}" = "NO" ]; then
        # netatopa
        export KERNELDIR=`pwd`
        build_external_module ${netatop_version} || exit 1
	build_external_module ${exfat_linux_version} || exit 1
        export KERN_DIR=`pwd`
        if [ "${g_model_name}" = "BlackCanyon" -o "${g_model_name}" = "BryceCanyon" ]; then
            build_external_module rstbtn/bbc_drivers || exit 1
        elif [ "${g_model_name}" = "Sprite" -o "${g_model_name}" = "Aurora" ]; then
            build_external_module rstbtn/sprite_drivers || exit 1
        fi
	build_paragon_driver
    fi

    #mkimage -A x86 -O linux -T kernel -C gzip -n kernel -d ./arch/${ARCH}/boot/bzImage uImage || exit 1
    ./scripts/mkuboot.sh -A x86 -O linux -T kernel -C gzip -n kernel -d ./arch/${ARCH}/boot/bzImage ./arch/${ARCH}/boot/uImage || exit 1

}

function xbuild()
{
    if [ "${chip_vendor}" = "marvell" ]; then
        build_marvell
    elif [ "${chip_vendor}" = "intel" ]; then
        build_intel
    else
        LOG "Not support ${chip_vendor} chip vendor"
    fi
}

function xinstall_external_module()
{
    local tmp_current_path=`pwd`
    local module_name=$1
    cd ${BUILD_KERNEL_ROOT_PATH}/../ext_kernel_modules/${module_name}/
    ./xbuild.sh install
    cd $tmp_current_path
}

function xinstall_one_bay()
{
    local model_name=$1
    install_kernel=${BUILD_KERNEL_ROOT_PATH}/../out/${model_name}/${model_name}
    install_driver=${BUILD_KERNEL_ROOT_PATH}/../out/${model_name}/${model_name}/driver
    export KERNEL_DRIVER_INSTALL_PATH=$install_driver

    if  [ ! -d ${install_kernel} ]; then
        mkdir -p ${install_kernel}
    fi

    if  [ ! -d ${install_driver} ]; then
        mkdir -p ${install_driver}
    fi

    cp -avf arch/${ARCH}/boot/uImage ${install_kernel}/

    cp -avf \
        drivers/net/ppp/ppp_generic.ko \
        drivers/net/ppp/ppp_mppe.ko \
        drivers/net/ppp/ppp_synctty.ko \
        drivers/net/ppp/pppoe.ko \
        drivers/net/slip/slhc.ko \
        drivers/net/slip/slip.ko \
        drivers/net/ppp/pppox.ko \
        drivers/net/tun.ko \
        drivers/scsi/scsi_transport_iscsi.ko \
        fs/hfs/hfs.ko \
        fs/udf/udf.ko \
        fs/xfs/xfs.ko \
        lib/crc-ccitt.ko \
        net/ipv4/ip_tunnel.ko \
        net/ipv4/netfilter/ip_tables.ko \
        net/ipv4/netfilter/nf_conntrack_ipv4.ko \
        net/ipv4/netfilter/iptable_filter.ko \
        net/ipv4/netfilter/nf_defrag_ipv4.ko \
        net/ipv4/netfilter/nf_nat_ipv4.ko \
        net/ipv4/netfilter/nf_log_ipv4.ko \
        net/ipv4/tunnel4.ko \
        net/netfilter/nf_conntrack.ko \
        net/netfilter/nf_log_common.ko \
        net/netfilter/nf_nat.ko \
        net/netfilter/x_tables.ko \
        net/netfilter/xt_LOG.ko \
        net/netfilter/xt_addrtype.ko \
        net/netfilter/xt_state.ko \
        net/netfilter/xt_recent.ko \
        net/netfilter/xt_conntrack.ko \
        net/netfilter/xt_limit.ko \
        net/netfilter/xt_tcpudp.ko \
    ${install_driver}/

    xinstall_external_module Paragon/ufsd_driver

}

function xinstall()
{
    local model_name=$1
    install_kernel=${BUILD_KERNEL_ROOT_PATH}/../out/${model_name}/${model_name}
    install_driver=${BUILD_KERNEL_ROOT_PATH}/../out/${model_name}/${model_name}/driver
    install_addons=${BUILD_KERNEL_ROOT_PATH}/../out/${model_name}/${model_name}/addons
    install_rstbtn=${BUILD_KERNEL_ROOT_PATH}/../out/${model_name}/${model_name}/opt/wd/kmodules/
    export KERNEL_DRIVER_INSTALL_PATH=$install_driver
    export WD_KERNEL_DRIVER_INSTALL_PATH=$install_rstbtn

    if  [ ! -d ${install_kernel} ]; then
        mkdir -p ${install_kernel}
    fi

    if  [ ! -d ${install_driver} ]; then
        mkdir -p ${install_driver}
    fi

    if [ "${chip_vendor}" = "intel" ]; then
        if [ ! -d ${install_rstbtn} ]; then
            mkdir -p ${install_rstbtn}
        fi
    fi

    cp -avf arch/${ARCH}/boot/uImage ${install_kernel}/

    # for iSCSI Target
    cp -avf \
      drivers/target/iscsi/iscsi_target_mod.ko \
      drivers/target/target_core_mod.ko \
      drivers/target/target_core_file.ko \
      ${install_driver}/

    # for Virtual Volume
    cp -avf \
      drivers/scsi/scsi_transport_iscsi.ko \
      drivers/scsi/iscsi_tcp.ko \
      drivers/scsi/libiscsi_tcp.ko \
      drivers/scsi/libiscsi.ko \
      ${install_driver}/

    # Bonding, We have 2 ethernets!
    cp -avf \
      drivers/net/bonding/bonding.ko \
      ${install_driver}/

    # Tunnels
    cp -avf \
      net/ipv4/tunnel4.ko \
      net/ipv6/ipv6.ko \
      net/ipv6/sit.ko \
      net/ipv6/xfrm6_mode_beet.ko \
      net/ipv6/xfrm6_mode_transport.ko \
      net/ipv6/xfrm6_mode_tunnel.ko \
      net/ipv6/tunnel6.ko \
      net/ipv6/ip6_tunnel.ko \
      drivers/net/tun.ko \
      ${install_driver}/

    # for VPN - PPTP
    install_VPN_path=${install_addons}/VPN/lib/modules
    mkdir -p ${install_addons}/VPN/lib/modules
    cp -avf drivers/net/ppp/bsd_comp.ko ${install_VPN_path}
    cp -avf drivers/net/ppp/ppp_async.ko ${install_VPN_path}
    cp -avf drivers/net/ppp/ppp_deflate.ko ${install_VPN_path}
    cp -avf drivers/net/ppp/ppp_generic.ko ${install_VPN_path}
    cp -avf drivers/net/ppp/ppp_mppe.ko ${install_VPN_path}
    cp -avf drivers/net/ppp/ppp_synctty.ko ${install_VPN_path}
    cp -avf drivers/net/ppp/pppoe.ko ${install_VPN_path}
    cp -avf drivers/net/ppp/pppox.ko ${install_VPN_path}
    cp -avf drivers/net/slip/slhc.ko ${install_VPN_path}
    cp -avf lib/crc-ccitt.ko ${install_VPN_path}

    # Docker dependencies
    cp -avf \
      net/netfilter/nf_conntrack.ko \
      net/netfilter/nf_nat.ko \
      net/netfilter/x_tables.ko \
      net/netfilter/xt_addrtype.ko \
      net/netfilter/xt_conntrack.ko \
      net/netfilter/xt_nat.ko \
      net/netfilter/xt_tcpudp.ko \
      net/ipv4/ip_tunnel.ko \
      net/ipv4/netfilter/ip_tables.ko \
      net/ipv4/netfilter/nf_nat_ipv4.ko \
      net/ipv4/netfilter/nf_defrag_ipv4.ko \
      net/ipv4/netfilter/nf_conntrack_ipv4.ko \
      net/ipv4/netfilter/iptable_nat.ko \
      net/ipv4/netfilter/ipt_MASQUERADE.ko \
      net/ipv4/netfilter/nf_nat_masquerade_ipv4.ko \
      net/ipv4/netfilter/iptable_filter.ko \
      net/llc/llc.ko \
      net/802/stp.ko \
      net/bridge/bridge.ko \
      net/bridge/br_netfilter.ko \
      ${install_driver}/

    # iptable - ipv6 netfilter, recent and log module - for ssh brute force protection
    cp -avf \
      net/netfilter/nf_log_common.ko \
      net/netfilter/xt_LOG.ko \
      net/netfilter/xt_limit.ko \
      net/netfilter/xt_recent.ko \
      net/netfilter/xt_state.ko \
      net/ipv4/netfilter/nf_log_ipv4.ko \
      net/ipv6/netfilter/ip6_tables.ko \
      net/ipv6/netfilter/ip6table_filter.ko \
      net/ipv6/netfilter/nf_defrag_ipv6.ko \
      net/ipv6/netfilter/nf_conntrack_ipv6.ko \
      net/ipv6/netfilter/nf_log_ipv6.ko \
      ${install_driver}/

    # for 4.14.22 kernel build in driver change to kernel module
    cp -avf \
      crypto/async_tx/async_memcpy.ko \
      crypto/async_tx/async_pq.ko \
      crypto/async_tx/async_raid6_recov.ko \
      crypto/async_tx/async_tx.ko \
      crypto/async_tx/async_xor.ko \
      crypto/xor.ko \
      drivers/md/dm-bio-prison.ko \
      drivers/md/dm-bufio.ko \
      drivers/md/dm-crypt.ko \
      drivers/md/dm-mod.ko \
      drivers/md/dm-snapshot.ko \
      drivers/md/dm-thin-pool.ko \
      drivers/md/linear.ko \
      drivers/md/persistent-data/dm-persistent-data.ko \
      drivers/md/raid0.ko \
      drivers/md/raid1.ko \
      drivers/md/raid10.ko \
      drivers/md/raid456.ko \
      lib/raid6/raid6_pq.ko \
      ${install_driver}/

    cp -avf \
      fs/fat/fat.ko \
      fs/fat/msdos.ko \
      fs/fat/vfat.ko \
      fs/hfs/hfs.ko \
      fs/isofs/isofs.ko \
      fs/lockd/lockd.ko \
      fs/nfs/nfs.ko \
      fs/nfs/nfsv2.ko \
      fs/nfs/nfsv3.ko \
      fs/nfs_common/grace.ko \
      fs/nfs_common/nfs_acl.ko \
      fs/nfsd/nfsd.ko \
      fs/nls/nls_cp850.ko \
      fs/nls/nls_iso8859-1.ko \
      fs/nls/nls_iso8859-2.ko \
      fs/nls/nls_utf8.ko \
      fs/udf/udf.ko \
      fs/xfs/xfs.ko \
      fs/cifs/cifs.ko \
      ${install_driver}/

    cp -avf \
      net/sunrpc/sunrpc.ko \
      ${install_driver}/

    if [ "${ARCH}" = "arm" ]; then
        cp -avf \
        net/sunrpc/auth_gss/auth_rpcgss.ko \
        net/sunrpc/auth_gss/rpcsec_gss_krb5.ko \
        lib/oid_registry.ko \
        ${install_driver}/
    fi

    if [ "${ARCH}" = "x86_64" ]; then
        cp -avf \
          fs/exportfs/exportfs.ko \
          fs/fuse/fuse.ko \
          fs/nls/nls_ascii.ko \
          fs/nls/nls_cp437.ko \
          fs/nls/nls_cp850.ko \
          fs/quota/quota_tree.ko \
          fs/quota/quota_v2.ko \
          ${install_driver}/
    fi

    # netatop
    xinstall_external_module ${netatop_version}

    #cryptodev
    if [ "${chip_vendor}" = "marvell" ]; then
       xinstall_external_module ${cryptodev_version}
       xinstall_external_module Paragon/ufsd_driver
    fi

    if [ "${chip_vendor}" = "intel" ]; then
        if [ "${g_model_name}" = "BlackCanyon" -o "${g_model_name}" = "BryceCanyon" ]; then
            cp -avf \
            fs/fscache/fscache.ko \
            fs/pstore/pstore.ko \
            ${install_driver}/
            xinstall_external_module rstbtn/bbc_drivers
        elif [ "${g_model_name}" = "Sprite" -o "${g_model_name}" = "Aurora" ]; then
            xinstall_external_module rstbtn/sprite_drivers
        fi
	xinstall_external_module Paragon/ufsd_driver
    fi

    if [ "${g_model_name}" != "GrandTeton" -a "${g_model_name}" != "Glacier" ]; then
	    xinstall_external_module ${exfat_linux_version}
    fi

    ${CROSS_COMPILE}strip --strip-debug ${install_driver}/* || die "driver strip failed"
    LOG "--> Install dirver success."
}

function Build_Kernel()
{
    local model_name=$1
    local out_model_path=${BUILD_KERNEL_ROOT_PATH}/../out/$model_name
    local out_list_path=${BUILD_KERNEL_ROOT_PATH}/../out/${build_kernel_out_list}

    LOG "Build Kernel"
    LOG "model_name=$model_name"

    if [ "${root_folder_build}" = "NO" ]; then
        Chk_Model_Name $model_name

        if [ ! -d ../ext_kernel_modules/$netatop_version ]; then
            die "Can not find Kernel $netatop_version version."
        fi

        Get_Chip_Vendor $model_name

        if [ "$chip_vendor" != "marvell" ] && [ "$chip_vendor" != "intel" ]; then
            die "$chip vendor is not support."
        fi

        #if [ ! -e kernel_config/.config_${model_name} ]; then
        #  die "Can not find kernel config .config_${model_name}"
        #fi

        rm -rf ${out_model_path}

        #cd $kernel_version

        Decompress_Kernel $kernel_version ${model_name}
        Decompress_module ${netatop_version}
        Decompress_module ${cryptodev_version}

        sync
        sleep 1

        cd ${kernel_version}.$model_name
    fi
    PREV_CROSS_COMPILE=$CROSS_COMPILE
    PREV_PATH=$PATH

    xbuild $model_name
    if [ "${root_folder_build}" = "NO" ]; then
        if [ "${model_name}" = "Glacier" ]; then
            xinstall_one_bay $model_name
        else
            xinstall $model_name
        fi

    fi
    export CROSS_COMPILE=$PREV_CROSS_COMPILE
    export PATH=$PREV_PATH

    if [ "${root_folder_build}" = "NO" ]; then
        cd ${out_model_path}/${model_name}
        if [ "$chip_vendor" = "marvell" ]; then
            echo "only marvell platfrom copy crypto include"
            mkdir -p include/linux
            cp -avf ${BUILD_KERNEL_ROOT_PATH}/../ext_kernel_modules/${cryptodev_version}/${cryptodev_version}/crypto include/linux/
        fi

        compress_name=kernel-${kernel_version#*-}-${BUILDNO}_${product}.tar.gz
        LOG "Compress kernel binary ${compress_name}"
        tar zcf ../${compress_name} . || die "Can not compress file ${compress_name}"
        cd ..
        rm -rf ${model_name}

        #write out list
        if [ ! -e ${out_list_path} ]; then
            echo "${model_name} ${compress_name}" >> ${out_list_path}
        else
            check_build=`cat ${out_list_path} | grep ${model_name}`
            if [ -z "${check_build}" ]; then
                echo "${model_name} ${compress_name}" >> ${out_list_path}
            fi
        fi

        cd $BUILD_KERNEL_ROOT_PATH
    fi
}

function local_build()
{
    BUILD_KERNEL_ROOT_PATH=`pwd`
    BUILDNO=1
    LOG "local build"
    if [ "$1" = "clean" ]; then
        xclean clean
    elif [ "$1" = "build" ]; then
        rm -f ${BUILD_KERNEL_ROOT_PATH}/${log_name}
        Build_Kernel build
    else
        LOG "Input parameter incorrent!"
        Help
    fi
}

function clean_marvell()
{
    export ARCH=arm
    export CROSS_COMPILE=arm-linux-gnueabihf-

    make clean
}

function clean_intel()
{
    export ARCH=x86_64
    make clean
}

function xclean()
{
    local model_name=$1
    local clean_kernel_path=${kernel_version}.${model_name}
    LOG "make clean"

    if [ "${root_folder_build}" = "NO" ]; then
        LOG "model_name=$model_name"
        Get_Chip_Vendor $model_name
        if [ "$chip_vendor" != "marvell" ] && [ "$chip_vendor" != "intel" ]; then
            die "$chip vendor is not support."
        fi
        cd ${clean_kernel_path}
    fi

    if [ "${chip_vendor}" = "marvell" ]; then
        clean_marvell
    elif [ "${chip_vendor}" = "intel" ]; then
        clean_intel
    else
        LOG "Not support ${chip_vendor} chip vendor"
    fi
    exit 0
}

num=$#

if [ $num -eq 2 ]; then
    if [ "${root_folder_build}" = "NO" ]; then
        BUILD_KERNEL_ROOT_PATH=`pwd`
        if [ "$1" = "clean" ]; then
            platform=$2
            xclean $platform
        elif [ "$1" = "untar" ]; then
            platform=$2
            Get_Chip_Vendor $platform
            if [ -d ${kernel_version}.${platform} ]; then
              rm -rf ${kernel_version}.${platform}
            fi
            Decompress_Kernel ${kernel_version} ${platform}
            exit 0
        elif [ "$1" = "src" ]; then
            platform=$2
            Get_Chip_Vendor $platform
            if [ -d ${kernel_version}.${platform} ]; then
              rm -rf ${kernel_version}.${platform}
            fi
            Decompress_Kernel ${kernel_version} ${platform}
            Compress_Platform_Kernel_SRC $platform
            exit 0
        elif [ "$1" = "gpl" ]; then
            platform=$2
            Get_Chip_Vendor $platform
            if [ -d ${kernel_version}.${platform} ]; then
              rm -rf ${kernel_version}.${platform}
            fi
            Decompress_Kernel ${kernel_version} ${platform}
            Compress_Platform_Kernel_GPL_SRC $platform
            Decompress_module ${netatop_version}
            Decompress_module ${cryptodev_version}
            exit 0
        fi
        BUILDNO=$1
        rm -f ${BUILD_KERNEL_ROOT_PATH}/${log_name}
        if [ "${2}" = "all" ]; then
            for index in ${!PROJECT_LIST[@]}; do
                if [ $(($index%3)) == 0 ] ; then
                    platform=${PROJECT_LIST[index]}
                    index=$index+1
                    index=$index+1
                    LOG "platform is $platform"
                    Build_Kernel $platform
                fi
            done
        else
            platform=$2
            Build_Kernel ${platform}
        fi
    else
        echo "Please check \"root_folder_build\" parameter setting"
    fi
elif [ $num -eq 1 ]; then
    if [ "${root_folder_build}" = "YES" ]; then
        local_build $1
    elif [ -e platform_chip_vendor.txt ]; then
        chip_vendor=`cat platform_chip_vendor.txt`
        root_folder_build="YES"
        echo "chip_vendor=$chip_vendor"
        local_build $1
    else
        echo "Please check \"root_folder_build\" parameter setting"
    fi
else
    LOG "Input parameter incorrent!"
    Help
fi
