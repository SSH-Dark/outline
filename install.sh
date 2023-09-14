#!/usr/bin/env bash

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

cur_dir=$(pwd)

# check root
[[ $EUID -ne 0 ]] && echo -e "${red}No Roots：${plain} No Root！\n" && exit 1

# check os
if [[ -f /etc/redhat-release ]]; then
    release="centos"
elif cat /etc/issue | grep -Eqi "debian"; then
    release="debian"
elif cat /etc/issue | grep -Eqi "ubuntu"; then
    release="ubuntu"
elif cat /etc/issue | grep -Eqi "centos|red hat|redhat"; then
    release="centos"
elif cat /proc/version | grep -Eqi "debian"; then
    release="debian"
elif cat /proc/version | grep -Eqi "ubuntu"; then
    release="ubuntu"
elif cat /proc/version | grep -Eqi "centos|red hat|redhat"; then
    release="centos"
else
    echo -e "${red}System version not detected，Contact the script author！${plain}\n" && exit 1
fi

arch=$(arch)

if [[ $arch == "x86_64" || $arch == "x64" || $arch == "s390x" || $arch == "amd64" ]]; then
    arch="amd64"
elif [[ $arch == "aarch64" || $arch == "arm64" ]]; then
    arch="arm64"
else
    arch="amd64"
    echo -e "${red}Failed to detect schema, use the default schema: ${arch}${plain}"
fi

echo "Architecture: ${arch}"

if [ $(getconf WORD_BIT) != '32' ] && [ $(getconf LONG_BIT) != '64' ]; then
    echo "This software does not support 32-bit systems (x86), please use 64-bit systems (x86_64), if the detection is incorrect, please contact the author"
    exit -1
fi

os_version=""

# os version
if [[ -f /etc/os-release ]]; then
    os_version=$(awk -F'[= ."]' '/VERSION_ID/{print $3}' /etc/os-release)
fi
if [[ -z "$os_version" && -f /etc/lsb-release ]]; then
    os_version=$(awk -F'[= ."]+' '/DISTRIB_RELEASE/{print $2}' /etc/lsb-release)
fi

if [[ x"${release}" == x"centos" ]]; then
    if [[ ${os_version} -le 6 ]]; then
        echo -e "${red}Please use CentOS 7 or later!${plain}\n" && exit 1
    fi
elif [[ x"${release}" == x"ubuntu" ]]; then
    if [[ ${os_version} -lt 16 ]]; then
        echo -e "${red}Please use Ubuntu 16 or later！${plain}\n" && exit 1
    fi
elif [[ x"${release}" == x"debian" ]]; then
    if [[ ${os_version} -lt 8 ]]; then
        echo -e "${red}Use a Debian 8 or later system！${plain}\n" && exit 1
    fi
fi

install_base() {
    if [[ x"${release}" == x"centos" ]]; then
        yum install wget curl tar jq -y
    else
        apt install wget curl tar jq -y
    fi
}

#This function will be called when user installed x-ui out of sercurity
config_after_install() {
    echo -e "${yellow}For security reasons, after the installation/update is completed, you need to forcibly change the port and account password${plain}"
    read -p "Confirm whether to continue, if you select n, skip this port and account password setting[y/n]": config_confirm
    if [[ x"${config_confirm}" == x"y" || x"${config_confirm}" == x"Y" ]]; then
        read -p "Please set your account name:" config_account
        echo -e "${yellow}Your account name will be set to:${config_account}${plain}"
        read -p "Please set your account password:" config_password
        echo -e "${yellow}Your account password will be set to:${config_password}${plain}"
        read -p "Set the panel access port:" config_port
        echo -e "${yellow}Your panel access port will be set to:${config_port}${plain}"
        echo -e "${yellow}Confirm the setting, setting it${plain}"
        /usr/local/x-ui/x-ui setting -username ${config_account} -password ${config_password}
        echo -e "${yellow}The account password is set${plain}"
        /usr/local/x-ui/x-ui setting -port ${config_port}
        echo -e "${yellow}The panel port setting is complete${plain}"
    else
        echo -e "${red}The setting has been canceled...${plain}"
        if [[ ! -f "/etc/x-ui/x-ui.db" ]]; then
            local usernameTemp=$(head -c 6 /dev/urandom | base64)
            local passwordTemp=$(head -c 6 /dev/urandom | base64)
            local portTemp=$(echo $RANDOM)
            /usr/local/x-ui/x-ui setting -username ${usernameTemp} -password ${passwordTemp}
            /usr/local/x-ui/x-ui setting -port ${portTemp}
            echo -e "Detecting that you are a fresh installation, random users and ports have been automatically generated for you for security reasons:"
            echo -e "###############################################"
            echo -e "${green}Panel login username:${usernameTemp}${plain}"
            echo -e "${green}Panel login user password:${passwordTemp}${plain}"
            echo -e "${red}Panel login port:${portTemp}${plain}"
            echo -e "###############################################"
            echo -e "${red}If you have forgotten the panel login information, you can enter HCM after the installation is complete and enter option 7 to view the panel login information${plain}"
        else
            echo -e "${red}The current version upgrade, keep the previous settings, the login method remains unchanged, you can enter the HCM and type the number 7 to view the panel login information${plain}"
        fi
    fi
}

install_x-ui() {
    systemctl stop x-ui
    cd /usr/local/

    if [ $# == 0 ]; then
        last_version=$(curl -Lsk "https://api.github.com/repos/FranzKafkaYu/x-ui/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
        if [[ ! -n "$last_version" ]]; then
            echo -e "${red}detect x-ui Version failure, possibly exceeding Github API limits, please try again later, or manually specify the HCM version installation${plain}"
            exit 1
        fi
        echo -e "DetectedHCM detected Latest version：${last_version}，Start the installation"
        wget -N --no-check-certificate -O /usr/local/x-ui-linux-${arch}.tar.gz https://github.com/FranzKafkaYu/x-ui/releases/download/${last_version}/x-ui-linux-${arch}.tar.gz
        if [[ $? -ne 0 ]]; then
            echo -e "${red}Failed to download HCM, make sure your server is able to download the Github file${plain}"
            exit 1
        fi
    else
        last_version=$1
        url="https://github.com/FranzKafkaYu/x-ui/releases/download/${last_version}/x-ui-linux-${arch}.tar.gz"
        echo -e "Start installing HCM v$1"
        wget -N --no-check-certificate -O /usr/local/x-ui-linux-${arch}.tar.gz ${url}
        if [[ $? -ne 0 ]]; then
            echo -e "${red}Download HCM$1 failed, make sure this version exists${plain}"
            exit 1
        fi
    fi

    if [[ -e /usr/local/x-ui/ ]]; then
        rm /usr/local/x-ui/ -rf
    fi

    tar zxvf x-ui-linux-${arch}.tar.gz
    rm x-ui-linux-${arch}.tar.gz -f
    cd x-ui
    chmod +x x-ui bin/xray-linux-${arch}
    cp -f x-ui.service /etc/systemd/system/
    wget --no-check-certificate -O /usr/bin/x-ui https://raw.githubusercontent.com/FranzKafkaYu/x-ui/main/x-ui.sh
    chmod +x /usr/local/x-ui/x-ui.sh
    chmod +x /usr/bin/x-ui
    config_after_install
    #echo -e "For a fresh installation, the default web port is ${green}56789${plain}, and the username and password are ${green}hha${plain"} by default
    #echo -e "Make sure this port is not occupied by another program, ${yellow} and make sure port 56789 is allowed ${plain}"
    #    echo -e "If you want to change 56789 to a different port, enter the command to modify it, and also make sure that the port you modified is also allowed ..."
    #echo -e ""
    #echo -e "If you're updating the panel, access the panel the way you used to"
    #echo -e ""
    systemctl daemon-reload
    systemctl enable x-ui
    systemctl start x-ui
    echo -e "${green}x-ui v${last_version}${plain} Installation complete, panel started,"
    echo -e ""
    echo -e "How to use HCM Admin Script:"
    echo -e "----------------------------------------------"
    echo -e "x-ui              - Show admin menu (more functions)"
    echo -e "x-ui start        - Launch the     HCM   panel"
    echo -e "x-ui stop         - Stop the       HCM   panel"
    echo -e "x-ui restart      - Restart the    HCM   panel"
    echo -e "x-ui status       - View the       HCM   status"
    echo -e "x-ui enable       - Set            HCM   to boot automatically"
    echo -e "x-ui disable      - Cancel         HCM   boot"
    echo -e "x-ui log          - Review the     HCM   logs"
    echo -e "x-ui v2-ui        - Migrate the v2-HCM    account data of this machine to Ch"
    echo -e "x-ui update       - Update the     HCM   panel"
    echo -e "x-ui install      - Install the    HCM   panel"
    echo -e "x-ui uninstall    -  Uninstall the HCM   panel"
    echo -e "x-ui geo          - Update         geo   data"
    echo -e "----------------------------------------------"
}

echo -e "${green}Start the installation${plain}"
install_base
install_x-ui $1
