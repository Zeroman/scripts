#!/bin/bash

cur_file_path=$(realpath $0)
cur_file_dir=${cur_file_path%/*}


share_sets=""
iso_sets=""
disk_sets=""
console_sets=""
bios_sets=""
sys_img=""
work_img=""
sd_img=""
create_img="no"
sd_img_size="4096M"
sys_img_size="64000M"
work_img_size="64000M"
slic_name=""
daemonize=false

err()
{   
    echo "Error: $*"
    exit 1
}

check_udev()
{
    rules_file=/etc/udev/rules.d/99-color.rules
    if [ -e $rules_file ];then
        return
    fi
    echo 'ATTRS{idVendor}=="1782", ATTRS{idProduct}=="4d00", MODE="0660", GROUP="user"' > $rules_file
    sudo service udev reload
}

defalutConfig()
{
    vncPort=3389
    spicePort=5900
    clientSSHPort=""
    consolePort=""
    macaddr=08:00:27:23:35:32
    memSize=1536
    # usbIDs="1782:4d00 1782:3d00"
    usbIDs=""

    cpuCores=1
    cpuThreads=2

    diskIF=ide
    # diskIF=none
    # diskIF=scsi
    # diskIF=virtio
    netType=e1000 # ne2k_pci,i82551,i82557b,i82559er,rtl8139,e1000,pcnet,virtio

    extName=tmp
    extImgDir=$PWD

    other_args=""
}

genUsbDeviceSet()
{
    for dev in $usbIDs; do 
        echo -n "-usb -usbdevice host:$dev "
    done
}

createExtImg()
{
    baseImg=$1
    extImg=$2

    if [ ! -e $baseImg ];then
        echo "$baseImg is not exist!"
        exit 1
    fi

    if [ -e $extImg ];then
        echo "$extImg is exist!"
    else
        qemu-img create -f qcow2 -b $baseImg $extImg
    fi
}

getDiskImgFmt()
{
    if [ -e $1 ];then
        qemu-img info $1 | grep -w format | awk '{print $3}'
    fi
}

usage()
{
    echo "config:
    --vnc-port $vncPort
    --spice-port $spicePort
    --console-port $consolePort
    --macaddr $macaddr
    --mem-size $memSize
    --usb-ids $usbIDs
    --cpu-cores $cpuCores
    --cpu-threads $cpuThreads
    --disk-if $diskIF
    --net-type $netType
    --sys-img $sys_img
    --work-img $work_img
    --sd-img $sd_img
    --sd-size $sd_img_size
    --noaudio
    --boot-iso
    --with-iso test.iso
excute:
    --start-server-vnc
    --conncet-vnc
    --start-server-spice
    --conncet-spice
    --spice
    --compact-disk old new
    "
    exit 0
}

kvmConfig()
{
    argv=""
    while [ $# -gt 0 ]; do
        case $1 in
            --vnc-port) shift; vncPort=$1; shift;
                ;;
            --spice-port) shift; spicePort=$1; shift;
                ;;
            --client-ssh-port) shift; clientSSHPort=$1; shift;
                ;;
            --console-port) shift; consolePort=$1; shift;
                ;;
            --macaddr) shift; macaddr=$1; shift;
                ;;
            --mem-size) shift; memSize=$1; shift;
                ;;
            --usb-ids) shift; usbIDs+="$1 "; shift;
                ;;
            --cpu-cores) shift; cpuCores=$1; shift;
                ;;
            --cpu-threads) shift; cpuThreads=$1; shift;
                ;;
            --disk-if) shift; diskIF=$1; shift;
                ;;
            --net-type) shift; netType=$1; shift;
                ;;
            --sys-img) shift; sys_img=$1; shift;
                ;;
            --work-img) shift; work_img=$1; shift;
                ;;
            --sd-img) shift; sd_img=$1; shift;
                ;;
            --sd-size) shift; sd_img_size=$1; shift;
                ;;
            --ext-name) shift; extName=$1; shift;
                ;;
            --ext-img-dir) shift; extImgDir=$1; shift;
                ;;
            --noaudio) export QEMU_AUDIO_DRV=none; shift;
                ;;
            --boot-iso) iso_sets+="-boot d "; shift;
                ;;
            --with-iso) shift; iso_sets+="-cdrom $1 "; shift;
                ;;
            --with-slic) shift; slic_name="$1"; shift;
                ;;
            --create-img) create_img="yes";shift;
                ;;
            --daemonize) shift; daemonize=true;
                ;;
            --append) shift; other_args="$1"; shift;
                ;;
            *) argv+="$1 "; shift; 
                ;;
      esac
  done 
}

initConfig()
{
    if [ -z $sys_img ];then
        echo "sys_img is null"
        return
    fi

    if [ -z $work_img ];then
        echo "work_img is null"
        return
    fi

    test -d $extImgDir || mkdir -p $extImgDir

    if [ ! -e $sys_img ];then
        if [ $create_img = "no" ];then
            err "No file sys_img = $sys_img"
        fi
        qemu-img create -f qcow2 $sys_img $sys_img_size
    fi

    if [  ! -e $work_img ];then
        if [ $create_img = "no" ];then
            err "No file work_img = $work_img"
        fi
        qemu-img create -f qcow2 $work_img $work_img_size
    fi

    fmt=$(getDiskImgFmt $sys_img)
    if [ "$fmt" = "qcow2" ];then
        baseSysImg=$(realpath $sys_img)
        sys_img=$extImgDir/$(basename $sys_img).$extName
        createExtImg $baseSysImg $sys_img
    fi

    fmt=$(getDiskImgFmt $work_img)
    if [ "$fmt" = "qcow2" ];then
        baseWorkImg=$(realpath $work_img)
        work_img=$extImgDir/$(basename $work_img).$extName
        createExtImg $baseWorkImg $work_img
    fi

    # -usbdevice disk:format=raw:/virt/usb_disk.raw
    # telnet localhost $consolePort ;
    # (qemu) drive_add 0 id=my_usb_disk,if=none,file=udisk.img
    # (qemu) device_add usb-storage,id=my_usb_disk,drive=my_usb_disk,removable=on
    # (qemu) device_del my_usb_disk

    vnc_sets="-vnc 127.0.0.1:0 -redir tcp:$vncPort::$vncPort"
    usb_sets="-usb -usbdevice tablet $(genUsbDeviceSet)"
    disk_sets="-drive file=${sys_img},if=$diskIF,cache=writeback -drive file=${work_img},if=$diskIF,cache=writeback"
    # -cpu kvm64 -M pc 
    base_sets="-localtime -smp cores=$cpuCores,threads=$cpuThreads -soundhw hda -m $memSize -enable-kvm"
    if $daemonize;then
        base_sets+=" --daemonize"
    fi
    net_sets="-net nic,model=$netType,macaddr=$macaddr -net user"
    if [ -n "$consolePort" ];then
        console_sets="-monitor telnet::$consolePort,server,nowait"
    fi
    if [ -n "$clientSSHPort" ];then
        net_sets+=" -redir tcp:$clientSSHPort::22"
    fi
    if [ -e "/usr/share/doc/qemu-system-common/ich9-ehci-uhci.cfg" ];then
        ich9_cfg_path=/usr/share/doc/qemu-system-common/ich9-ehci-uhci.cfg
    else
        ich9_cfg_path=$cur_file_path/ich9-ehci-uhci.cfg
    fi

    spice_sets="-vga qxl -spice port=$spicePort,image-compression=quic,\
jpeg-wan-compression=auto,zlib-glz-wan-compression=auto,\
streaming-video=all,playback-compression=on,agent-mouse=on,disable-ticketing \
-readconfig $ich9_cfg_path \
-device virtio-serial-pci \
-chardev spicevmc,id=spicechannel0,name=vdagent \
-device virtserialport,chardev=spicechannel0,name=com.redhat.spice.0 \
-chardev spicevmc,name=usbredir,id=usbredirchardev1 \
-device usb-redir,chardev=usbredirchardev1,id=usbredirdev1,debug=3 \
-chardev spicevmc,name=usbredir,id=usbredirchardev2 \
-device usb-redir,chardev=usbredirchardev2,id=usbredirdev2,debug=3 \
-chardev spicevmc,name=usbredir,id=usbredirchardev3 \
-device usb-redir,chardev=usbredirchardev3,id=usbredirdev3,debug=3
"
    if [ -n "$sd_img" ];then
        if [ ! -e "$sd_img" ];then
            qemu-img create -f raw $sd_img $sd_img_size
        fi
        disk_sets+=" -usb -drive if=none,file=$sd_img,cache=writeback,id=udisk -device usb-storage,drive=udisk,removable=on"
    fi
    # macaddr=88:88:88:88:88:88
    # base_sets="-localtime -cpu kvm32 -smp cpus=8 -soundhw es1370 -m 2048 -usbdevice tablet -vga vmware"
    # net_sets="-net nic,model=virtio,macaddr=$macaddr -net user,smb=/work/com/color/,smbserver=10.0.2.8"
    # share_sets="-virtfs local,path=/work/com/color/,mount_tag=color,readonly"

    if [ -n "$slic_name" ];then
        bios_bin=$cur_file_dir/bios.bin
        slic_bin=$cur_file_dir/${slic_name}.bin
        echo $bios_bin $slic_bin
        if [ -e "$bios_bin" -a -e "$slic_bin" ];then
            bios_sets="--bios $bios_bin --acpitable file=$slic_bin"
        fi
    fi

    common_sets=$(echo $base_sets $console_sets $net_sets $usb_sets $share_sets $disk_sets $iso_sets $bios_sets $other_args)
    echo "--------------------------------------"
    echo $common_sets
    echo "--------------------------------------"
}

kvmExcute()
{
    case $1 in
        --start-server-vnc)
            kvm $common_sets $vnc_sets
            ;;
        --connect-vnc)
            rdesktop 127.0.0.1:$vncPort -g 1024x768 -u root -p root -D -P -K -r sound:local -r clipboard:PRIMARYCLIPBOARD
            # rdesktop localhost:$vncPort -x 0x80 -u root -p root -f -D -z -P -r sound:local -clipboard # for win7
            ;;
        --start-server-spice)
            kvm $common_sets $spice_sets
            ;;
        --conncet-spice)
            # spicec -h 127.0.0.1 -p $spicePort
            spicy -h 127.0.0.1 -p $spicePort
            ;;
        --spice)
            shift
            kvm $common_sets $spice_sets $@ &
            sleep 3
            spicy -f -h 127.0.0.1 -p $spicePort
            ;;
        --local)
            kvm $common_sets -vga std
            ;;
        --compact-disk)
            if [ -e $2 ];then
                file $2
                qemu-img convert -c -O qcow2 $2 $3
            fi
            ;;
        --commit-disk)
            if [ -e $2 ];then
                file $2
                qemu-img commit -f qcow2 $2
                \rm -i $2
            fi
            ;;
        --create-base-disk)
            if [ ! -e $2 ];then
                qemu-img create -f qcow2 $2 $3
            fi
            ;;
        --create-ext-disk) createExtImg $2 $3
            ;;
        *)
            ;;
    esac
}

defalutConfig
test $# = 0 && usage
kvmConfig "$@"
initConfig
kvmExcute $argv
