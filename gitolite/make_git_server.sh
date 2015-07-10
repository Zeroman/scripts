#!/bin/bash - 

set -e

cur_cmd=`realpath $0`
cur_path=${cur_cmd%/*}

deb_ver=$(cat /etc/debian_version)
server_dir=/work/git
git_passwd="<<<git>>>"
backup_dir=/work/git/backup
temp_dir=/tmp/gitolite


need_root()
{
    if [ "$(id -u)" != "0" ]; then
        echo "This function must be run as root" 1>&2
        exit 1
    fi
}

install_gitolite()
{
    if [ $(echo "$deb_ver > 7.0" | bc) -ne 0 ];then
        apt-get install gitolite3
    else
        apt-get install gitolite
    fi
}

setup_gitolite()
{
    mkdir -p $temp_dir
    mkdir -p $server_dir

    rm -f $temp_dir/admin $temp_dir/admin.pub
    ssh-keygen -t rsa -f $temp_dir/admin
    adduser --system --shell /bin/bash --group git --home $server_dir
    chown -R git.git $server_dir
    adduser git ssh
    echo "git:$git_passwd" | chpasswd
    chown git.git $temp_dir/admin.pub
    if which gl-setup > /dev/null;then
        su git -c "gl-setup $temp_dir/admin.pub"
    else
        su git -c "gitolite setup -pk $temp_dir/admin.pub"
    fi
    ssh -i $temp_dir/admin git@localhost

    /bin/rm -fv $temp_dir/admin.pub
    mv $temp_dir/admin $cur_path

    #ssh-copy-id -i /tmp/admin.pub git@git

    chown $SUDO_USER.$SUDO_USER $cur_path/admin
    echo "please copy $cur_path/admin to .ssh dir in your home dir"
}

backup_gitolite()
{
    ver=$(date +%F)
    mkdir -p $backup_dir
    backup_file=$backup_dir/repo_backup_${ver}.tar.gz
    echo "backup_gitolite to $backup_file ..."
    tar czf $backup_file make_git_server.sh bin repositories
}

case $1 in
    setup|s)
        need_root
        install_gitolite
        setup_gitolite
        ;;
    backup|b)
        need_root
        backup_gitolite
        ;;
    admin|clone_admin)
        chmod +x $cur_path/git.sh
        $cur_path/git.sh -i $temp_dir/admin clone git@localhost:gitolite-admin
        ;;
    show)
        ;;
    *)
        ;;
esac


