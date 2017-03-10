#!/bin/bash

clear
set -e

#apt-get -y install unzip
#wget https://github.com/kelvinblood/KeluLinuxKit/archive/master.zip
#unzip master.zip
#mv KeluLinuxKit-master/ KeluLinuxKit
#rm master.zip

VERSION=' Version 0.0.1, 2017-1-26, Copyright (c) 2017 kelvinblood';
SOURCE="${BASH_SOURCE[0]}"
KELULINUXKIT=$(pwd)
NOWTIME=$(date)

DOWNLOAD="$KELULINUXKIT/Download"
RESOURCE="$KELULINUXKIT/Resource"
SECRET="$RESOURCE/secret"
LOG_HOME=/var/local/log
DATA_HOME=/var/local/data
UPLOAD_HOME=/var/local/upload
PHP_HOME=/usr/share/php5.6
FPM_POOL_HOME=/var/local/fpm-pools
OPENRESTY_HOME=/usr/share/openresty
NGINX_HOME=/usr/share/openresty/nginx
NGINX_HOME_RUNTIME=/var/local/nginx
LD_LIBRARY_PATH=/usr/share/lib



LONGBIT=`getconf LONG_BIT`


IP=`ifconfig eth0 | grep "inet addr" | awk '{ print $2}' | awk -F: '{print $2}'`

while [ -h "$SOURCE" ]; do
      DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
      SOURCE="$(readlink "$SOURCE")"
      [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE"
done
DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"

cd $KELULINUXKIT
if [ ! -e Download ]; then
  mkdir Download
fi

usage () {
    cat $DIR/help
}

init() {
    cd $KELULINUXKIT

    # time zone
    dpkg-reconfigure tzdata

    # cp $RESOURCE/locale /etc/default/locale
    dpkg-reconfigure locales

    cat $RESOURCE/Home/.inputrc >> $HOME/.inputrc
    cat $RESOURCE/Home/.bash_profile >> $HOME/.bash_profile
    cat $RESOURCE/Home/environment >> /etc/environment

    locale-gen zh_CN.UTF-8
    locale-gen
    apt-get update && apt-get -y autoremove && apt-get -y upgrade
    apt-get -y install vim git ruby zip sudo git rake htop iftop wget
}

install_all() {
    init
    install_zsh
    install_iptable
    install_lnmp
}
install_zsh() {
    apt-get -y install zsh tmux
    # zsh重启生效引入zsh增强插件,支持git,rails等补全，可选多种外观皮肤
    wget https://github.com/robbyrussell/oh-my-zsh/raw/master/tools/install.sh -O - | sh

    echo ''
    echo ''
    echo ''
    echo "-- awesome-tmux -----------------------------------------------------"
    # pass the_silver_searcher install
    apt-get -y install build-essential automake pkg-config libpcre3-dev zlib1g-dev liblzma-dev
    # awesome-tmux
    cd $DOWNLOAD
    if [ ! -e maximum-awesome-linux ]; then
      git clone https://github.com/justaparth/maximum-awesome-linux.git
    fi
    cd maximum-awesome-linux
    rake

    # rake install:solarized['dark']

    cp $DOWNLOAD/maximum-awesome-linux/tmux.conf $DOWNLOAD/maximum-awesome-linux/tmux.conf_backup
    cp $RESOURCE/maximum-awesome-linux/tmux.conf $DOWNLOAD/maximum-awesome-linux/tmux.conf

    # cp $RESOURCE/maximum-awesome-linux/tmux.conf $DOWNLOAD/maximum-awesome
    # cp $RESOURCE/maximum-awesome-linux/.tmux* $HOME
    # cp $RESOURCE/maximum-awesome-linux/.vimrc* $HOME
    # cp $RESOURCE/maximum-awesome-linux/vimrc.bundles $DOWNLOAD/maximum-awesome-linux/vimrc.bundles

    # git clone https://github.com/gmarik/vundle.git ~/.vim/bundle/vundle
    # rm -r $HOME/.vim/bundle/vim-snipmate

    # tmux-powerline
    cd $HOME
    touch .tmux.conf.local

    cd $DOWNLOAD
    if [ ! -e tmux-powerline ]; then
      git clone https://github.com/erikw/tmux-powerline.git
    fi
    cp $DOWNLOAD/tmux-powerline/themes/default.sh $DOWNLOAD/tmux-powerline/themes/default.sh_backup
    cp $RESOURCE/tmux-powerline/default.sh $DOWNLOAD/tmux-powerline/themes/default.sh
cat >> $DOWNLOAD/maximum-awesome-linux/tmux.conf<< EOF
# add by Kelu
set-option -g status-left "#($DOWNLOAD/tmux-powerline/powerline.sh left)"
set-option -g status-right "#($DOWNLOAD/tmux-powerline/powerline.sh right)"
source-file ~/.tmux.conf.local
EOF

    cat $RESOURCE/Home/.zshrc >> $HOME/.zshrc
}

install_() {
    cat $DIR/install_help.md
}


install_iptable() {
    cd $HOME
    # iptables
    cp $RESOURCE/iptables.test.rules /etc
    cp $RESOURCE/iptables /etc/network/if-pre-up.d/iptables
    iptables -F

    iptables-restore < /etc/iptables.test.rules
    iptables-save > /etc/iptables.up.rules
}

init2() {
    cp /etc/sysctl.conf /etc/sysctl.conf_backup
    cp $RESOURCE/sysctl.conf /etc
    sysctl -p
}

install_ss() {
    cd "/var/local" && git clone https://github.com/shadowsocks/shadowsocks.git && cd shadowsocks && git checkout master;
    apt-get install python-pip && pip install shadowsocks;
    cd "/var/local" && git clone https://github.com/hellofwy/ss-bash && cd ss-bash;
    echo '12345 123456 10737418240' > ssusers

    # 开启hybla算法
    /sbin/modprobe tcp_hybla
    # 增加文件大小限制
    cat $RESOURCE/Home/limits.conf >> /etc/security/limits.conf

    ulimit -n 51200
}

install_pptp() {
    PPTP="$RESOURCE/pptp"
    apt-get -y install pptpd
    mv /etc/ppp /etc/ppp_backup
    cp $PPTP/pptpd.conf /etc/pptpd.conf
    cp -r $PPTP/ppp /etc
    service pptpd restart
}

install_lnmp() {
    install_openresty
    install_php
    install_pgsql
    install_composer
}

install_openresty(){
    cd $DOWNLOAD
    aptitude -y install libreadline-dev libpcre3-dev libssl-dev libcloog-ppl0 libpq-dev
    wget https://openresty.org/download/ngx_openresty-1.9.7.1.tar.gz
    tar -xzvf ngx_openresty-1.9.7.1.tar.gz
    cd ngx_openresty-1.9.7.1/
    ./configure --prefix=/usr/share/openresty --with-pcre-jit --with-http_postgres_module --with-http_iconv_module
    make && make install

    mkdir /var/local/nginx
    cp -R $NGINX_HOME /var/local
    cd /var/local/nginx
    mkdir conf/vhost

    cp $RESOURCE/nginx/* /var/local/nginx/
    cd $NGINX_HOME_RUNTIME
    ./test.sh
    ./start.sh
}

install_php(){
    cd $DOWNLOAD
    aptitude -y install libssl-dev libcurl4-openssl-dev libbz2-dev libjpeg-dev libpng-dev libgmp-dev libicu-dev libmcrypt-dev freetds-dev libxslt-dev
    ln -s /usr/lib/x86_64-linux-gnu/libsybdb.a /usr/lib/libsybdb.a
    ln -s /usr/lib/x86_64-linux-gnu/libsybdb.so /usr/lib/libsybdb.so
    ln -s /usr/lib/x86_64-linux-gnu/libct.a /usr/lib/libct.a
    ln -s /usr/lib/x86_64-linux-gnu/libct.so /usr/lib/libct.so
    ln -s /usr/include/x86_64-linux-gnu/gmp.h /usr/include/gmp.h

    wget http://php.net/distributions/php-5.6.16.tar.gz
    tar -xzvf php-5.6.16.tar.gz
    cd php-5.6.16
    ./configure --prefix /usr/share/php5.6 --enable-fpm --with-fpm-user=www-data --with-fpm-group=www-data --with-pcre-regex --with-openssl=shared --with-kerberos --with-zlib=shared --enable-bcmath=shared --with-bz2=shared --enable-calendar=shared --with-curl=shared --enable-exif=shared --with-gd=shared --with-jpeg-dir=/usr/include/jpeg8 --with-png-dir=/usr/include/libpng12 --with-gettext=shared --with-gmp=shared --with-mhash=shared --enable-intl=shared --enable-mbstring=shared --with-mcrypt=shared --enable-opcache --with-pdo-pgsql=shared --with-pgsql=shared --enable-shmop=shared --enable-soap=shared --enable-sockets=shared --with-xsl=shared --enable-zip=shared
    make clean && make && make install
    make test

    cp $RESOURCE/php/lib_php.ini /usr/share/php5.6/lib/php.ini
    cp $RESOURCE/php/etc_php-fpm.conf /usr/share/php5.6/etc/php-fpm.conf
    cp sapi/fpm/php-fpm /usr/share/php5.6/sbin/php-fpm

    mkdir /usr/share/php5.6/etc/pool
    mkdir /var/local/log
    mkdir /var/local/log/fpm-pools/
    mkdir /var/local/fpm-pools/
    mkdir /var/local/fpm-pools/www
    mkdir /var/local/fpm-pools/www/public

    cd /var/local/fpm-pools/www/public
    echo "<?php phpinfo(); ?>" >> index.php

    ln -s /usr/share/php5.6/sbin/php-fpm /usr/local/bin/php-fpm
    ln -s /usr/share/php5.6/bin/php /usr/local/bin/php

    /usr/share/php5.6/sbin/php-fpm
}

install_pgsql(){
    cd $DOWNLOAD
    sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt/ $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list'
    apt-get -y install wget ca-certificates
    wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add -
    apt-get update
    apt-get -y upgrade
    apt-get -y install postgresql-9.4 pgadmin3
}

install_composer(){
    cd $DOWNLOAD
    curl -sS https://getcomposer.org/installer | sudo php -- --install-dir=/usr/local/bin --filename=composer
}

install_l2tp() {
    cd $DOWNLOAD
    apt-get -y install ppp xl2tpd libgmp3-dev gawk flex bison;
    wget https://download.openswan.org/openswan/openswan-2.6.49.tar.gz && tar -xzvf openswan-2.6.49.tar.gz && cd openswan-2.6.49 && make programs && make install;

    rm /etc/ipsec.conf;
cat >> /etc/ipsec.conf << EOF
version 2.0
config setup
    nat_traversal=yes
    virtual_private=%v4:10.0.0.0/8,%v4:192.168.0.0/16,%v4:172.16.0.0/12
    oe=off
    protostack=netkey

conn L2TP-PSK-NAT
    rightsubnet=vhost:%priv
    also=L2TP-PSK-noNAT

conn L2TP-PSK-noNAT
    authby=secret
    pfs=no
    auto=add
    keyingtries=3
    rekey=no
    ikelifetime=8h
    keylife=1h
    type=transport
    left=$IP
    leftprotoport=17/1701
    right=%any
    rightprotoport=17/%any
    dpddelay=15
    dpdtimeout=30
    dpdaction=clear
EOF

    cd /etc
    if [ -e xl2tpd ]; then
        mv "/etc/xl2tpd" "/etc/xl2tpd_backup"
    fi

    cp -r "$RESOURCE/l2tp/xl2tpd" "/etc/xl2tpd"
    cp "$RESOURCE/l2tp/ppp/options.xl2tpd" "/etc/ppp/options.xl2tpd"
    touch /etc/ipsec.secrets
cat >> /etc/ipsec.secrets << EOF
$IP   %any:  PSK "kelu.org"
EOF

    echo 1 > /proc/sys/net/ipv4/ip_forward
    for each in /proc/sys/net/ipv4/conf/*
    do
        echo 0 > $each/accept_redirects
        echo 0 > $each/send_redirects
    done

    ipsec verify
    service ipsec restart
    service pppd-dns restart
    service xl2tpd restart
}

install_docker(){
    curl -sSL https://get.docker.com/ | sh
    sudo usermod -aG docker $USER
    sudo systemctl enable docker
    sudo systemctl start docker
}

install_test() {
    rm /etc/ipsec.conf;
cat >> /etc/ipsec.conf << EOF
version 2.0
config setup
    nat_traversal=yes
    virtual_private=%v4:10.0.0.0/8,%v4:192.168.0.0/16,%v4:172.16.0.0/12
    oe=off
    protostack=netkey

conn L2TP-PSK-NAT
    rightsubnet=vhost:%priv
    also=L2TP-PSK-noNAT

conn L2TP-PSK-noNAT
    authby=secret
    pfs=no
    auto=add
    keyingtries=3
    rekey=no
    ikelifetime=8h
    keylife=1h
    type=transport
    left=$IP
    leftprotoport=17/1701
    right=%any
    rightprotoport=17/%any
    dpddelay=15
    dpdtimeout=30
    dpdaction=clear
EOF


    cd /etc
    if [ -e xl2tpd ]; then
        mv "/etc/xl2tpd" "/etc/xl2tpd_backup"
    fi

    cp -r "$RESOURCE/l2tp/xl2tpd" "/etc/xl2tpd"
    cp "$RESOURCE/l2tp/ppp/options.xl2tpd" "/etc/ppp/options.xl2tpd"
    touch /etc/ipsec.secrets
cat >> /etc/ipsec.secrets << EOF
$IP   %any:  PSK "kelu.org"
EOF

    echo 1 > /proc/sys/net/ipv4/ip_forward
    for each in /proc/sys/net/ipv4/conf/*
    do
        echo 0 > $each/accept_redirects
        echo 0 > $each/send_redirects
    done

    ipsec verify
    service ipsec restart
    service pppd-dns restart
    service xl2tpd restart
}

##############################################################
if [ "$#" -eq 0 ]; then
    usage
    exit 0
fi
case $1 in
    -h|h|help )
        usage
        exit 0;
        ;;
    -v|v|version )
        echo $VERSION;
        exit 0;
        ;;
esac
if [ "$EUID" -ne 0 ]; then
    echo "必需以root身份运行，请使用sudo等命令"
    exit 1;
fi

case $1 in
    init )
        shift
        init
        ;;
    install )
        shift
        install_$1 $2 $3
        ;;
    * )
        usage
        ;;
esac
