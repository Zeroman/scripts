#!/bin/sh

download_file()
{
    src=$1
    dst=$2
    md5=$3
    DL="wget -c"

    test -n "$src" || err "don't have file"
    if which axel;then
        if [ ! -e "$2" ];then
            axel -o $2 $1 
        fi
    else
        wget -c $1 -O $2
    fi

    if [ -n "$md5" ];then
        echo "$md5 $dst" | md5sum -c 
    fi
}

download_virtualbox_file()
{
    dl_file=$1
    dl_file_md5=$2

    download_file http://download.virtualbox.org/virtualbox/$vbox_ver/$dl_file $dl_file $dl_file_md5
}

get_new_virtualbox ()
{
    if [ ! -e /tmp/LATEST.TXT ];then
        wget http://download.virtualbox.org/virtualbox/LATEST.TXT -O /tmp/LATEST.TXT
    fi
    read vbox_ver < /tmp/LATEST.TXT

    if [ -n $vbox_ver ];then
        if [ ! -e /tmp/MD5SUMS ];then
            wget http://download.virtualbox.org/virtualbox/$vbox_ver/MD5SUMS -O /tmp/MD5SUMS 
        fi

        mkdir -p virtualbox_setup
        cd virtualbox_setup

        win_setup_regex="VirtualBox-$vbox_ver-.*-Win.exe"
        win_setup_file=`grep $win_setup_regex /tmp/MD5SUMS | awk -F\* '{print $2}'`
        win_setup_md5=`grep $win_setup_regex /tmp/MD5SUMS | awk '{print $1}'`
        download_virtualbox_file $win_setup_file $win_setup_md5

        linux_x86_regex="VirtualBox-$vbox_ver-.*-Linux_x86.run"
        linux_x86_md5=`grep "$linux_x86_regex" /tmp/MD5SUMS | awk '{print $1}'`
        linux_x86_file=`grep "$linux_x86_regex" /tmp/MD5SUMS | awk -F\* '{print $2}'`
        download_virtualbox_file $linux_x86_file $linux_x86_md5

        linux_amd64_regex="VirtualBox-$vbox_ver-.*-Linux_amd64.run"
        linux_amd64_md5=`grep "$linux_amd64_regex" /tmp/MD5SUMS | awk '{print $1}'`
        linux_amd64_file=`grep "$linux_amd64_regex" /tmp/MD5SUMS | awk -F\* '{print $2}'`
        download_virtualbox_file $linux_amd64_file $linux_amd64_md5

        ext_pack_regex="Oracle_VM_VirtualBox_Extension_Pack-${vbox_ver}.vbox-extpack"
        ext_pack_md5=`grep "$ext_pack_regex" /tmp/MD5SUMS | awk '{print $1}'`
        ext_pack_file=`grep "$ext_pack_regex" /tmp/MD5SUMS | awk -F\* '{print $2}'`
        download_virtualbox_file $ext_pack_file $ext_pack_md5

        # rm /tmp/LATEST.TXT
        # rm /tmp/MD5SUMS
        cd ..
    fi
}

get_new_virtualbox
