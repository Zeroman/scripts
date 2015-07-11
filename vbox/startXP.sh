#!/bin/bash - 
#===============================================================================
#
#          FILE: startXP.sh
# 
#         USAGE: ./startXP.sh 
# 
#   DESCRIPTION: 
# 
#       OPTIONS: ---
#  REQUIREMENTS: ---
#          BUGS: ---
#         NOTES: ---
#        AUTHOR: YOUR NAME (), 
#  ORGANIZATION: 
#       CREATED: 07/20/2013 10:31:52 AM HKT
#      REVISION:  ---
#===============================================================================


xp_img=xp.vdi
work_img=work.vdi
dvd_img=xp.iso
vm_name="xp"

freeMemMB=`free -m | grep Mem | awk '{print $3}'`
freeMemMB=`expr $freeMemMB / 4`
# maxMemMb=`VBoxManage list systemproperties | grep 'Maximum guest RAM' | awk '{print $5}'`
maxMemMb=2048
if [ $freeMemMB -gt $maxMemMb ];then
    freeMemMB=2048
fi

cpu_counts=`cat /proc/cpuinfo | grep "processor" | wc -l`
if [ $cpu_counts -gt 4 ];then
    cpu_counts=4
fi

setup_disk()
{
    VBoxManage storageattach $vm_name --storagectl "ide" \
        --port 0 --device 0 --type dvddrive --medium $dvd_img
    VBoxManage storageattach $vm_name --storagectl "ide" \
        --port 0 --device 1 --type hdd --medium $xp_img --mtype multiattach
    VBoxManage storageattach $vm_name --storagectl "ide" \
        --port 1 --device 1 --type hdd --medium $work_img --mtype multiattach
    VBoxManage internalcommands sethduuid $xp_img c0b03984-b368-9999-a7e3-20b4f122cded
}

create_XP()
{
    if VBoxManage showvminfo $vm_name > /dev/null;then
        echo "Already have vm xp!"
        return
    fi

    VBoxManage createvm --name $vm_name --register --basefolder $PWD
    VBoxManage modifyvm $vm_name --accelerate2dvideo on --audio alsa
    VBoxManage modifyvm $vm_name --clipboard bidirectional
    VBoxManage modifyvm $vm_name --memory $freeMemMB --cpus $cpu_counts 
    VBoxManage modifyvm $vm_name --pae off --ioapic on --ostype WindowsXP
    VBoxManage modifyvm $vm_name --nic1 nat
    VBoxManage modifyvm $vm_name --macaddress1 080027233532 
    VBoxManage modifyvm $vm_name --vram 128
    VBoxManage storagectl $vm_name --name "ide" --add ide

    if [ ! -e $xp_img ];then
        VBoxManage createhd --size 10000 --format VDI --filename $xp_img
    fi
    if [ ! -e $work_img ];then
        VBoxManage createhd --size 64000 --format VDI --filename $work_img
    fi

}

start_XP()
{
    if VBoxManage list runningvms | grep $vm_name;then
        return
    fi

    if VBoxManage showvminfo $vm_name > /dev/null;then
        #dvd_img=emptydrive

        mkdir -p /tmp/virtual/$vm_name
        VBoxManage modifyvm $vm_name --snapshotfolder /tmp/virtual/$vm_name

        setup_disk

        VBoxManage modifyvm $vm_name --boot1 disk 
        # VBoxManage modifyvm $vm_name --boot1 dvd

        VBoxManage startvm $vm_name -type sdl
        return
    fi
}

delete_XP()
{
    VBoxManage unregistervm $vm_name
    VBoxManage closemedium disk $xp_img 
    VBoxManage closemedium disk $work_img 
    rm -rf ~/VirtualBox\ VMs/$vm_name
    rm -rf xp/
}

if [ -z "$1" ];then
    echo "$0 start|delete"
    exit 0
fi

case "$1" in 
    start)
        create_XP
        start_XP
        ;;
    delete)
        delete_XP
        ;;
    *)
        ;;
esac

