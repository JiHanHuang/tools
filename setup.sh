#!/bin/bash

# 用于初始化一个新的Ubuntu环境，主要适用于18和20版本
# 脚本依赖坚果云上的数据包，属于为个人定制。只有部分是通用的
# 执行脚本前，最好使用ssh进行远程登录后，用root的权限执行

####
##############全局配置###############
# 日志 debug 4, info 3, warning 2, error 1, fatal 0
DEBUG_LEVEL=3

LPATH=$(cd $(dirname $0); pwd)
#在GitHub上可公开的tools
TOOLS_DIR="tools"
#不能在GitHub上公开的一些私有数据和包
SOURCES_DIR="sources"

T=1
F=0

##############公共函数###############

out(){
    local D=`date +%F~%T`
    if [ $# -eq 0 ];then
        echo "${D}"
    else
    case "$1" in
    'D'|'d')
        if [ $DEBUG_LEVEL -ge 4 ];then
            echo -e "${D}\033[34m DEBUG\033[0m: $2"
        fi
        ;;
    'I'|'i')
        if [ $DEBUG_LEVEL -ge 3 ];then
            echo -e "${D}\033[1;34m INFO\033[0m: $2"
        fi
        ;;
    'W'|'w')
        if [ $DEBUG_LEVEL -ge 2 ];then
            echo -e "${D}\033[1;37m WARNING\033[0m: $2"
        fi
        ;;
    'E'|'e')
        if [ $DEBUG_LEVEL -ge 1 ];then
            echo -e "${D}\033[1;31m ERROR\033[0m: $2"
        fi
        ;;
    'F'|'f')
        if [ $DEBUG_LEVEL -ge 0 ];then
            echo -e "${D}\033[1;31;5m FATAL\033[0m: $2"
        fi
        ;;
    'H'|'h')
            echo -e "Usage:  Msg [OPTION] [MESSAGE]
                OPTIONS:
                \033[34mD|d\033[0m	for debug
                \033[1;34mI|i\033[0m	for information (default)
                \033[1;37mW|w\033[0m	for warning
                \033[1;31mE|e\033[0m	for error
                \033[1;31;5mF|f\033[0m	for fatal
                H|h       for help

        Now debug level is ${DEBUG_LEVEL}
                ${D}
            "
        ;;
        *)
        if [ $DEBUG_LEVEL -ge 3 ];then
            echo -e "${D}\033[1;34m INFO\033[0m: $1"
        fi
        ;;
    esac
    fi
}

cmd_msg_exsit(){
    if [ $# -lt 2 ];then
        out F "input error in cmd_msg_exsit"
        exit 1
    fi
    out D "$1 | grep $2 > /dev/null"
    $1 | grep "$2" > /dev/null
    if [ $? -eq 0 ];then
        return $T
    fi
    return $F
}

loop_callback_proxy(){
    cat /var/log/clash.log | grep '127.0.0.1:7890 create success' >  /dev/null
    return $?
}

loop(){
    if [ $# -lt 1 ];then
        out F "input error in loop"
        exit 1
    fi
    for t in 5 4 3 2 2 2 2 1 1 1 
    do
        sleep $t
        $1
        if [ $? -eq 0 ];then
            return 0
        fi
    done
    out F "loop timeout:$1"
    return 2
}

####################################


##############设置国内源###############
set_sources(){
    out "set aliyun sources"
    if [ ! -f /etc/apt/sources.list.org ];then
        cp /etc/apt/sources.list /etc/apt/sources.list.org
    fi
    cat /etc/os-release | grep 'VERSION='
    code_name=`lsb_release -a | grep Codename | awk '{print $2}'`
    if [ "X" = "X$code_name" ];then
        out E "not find Codename"
        lsb_release -a
        return
    fi
echo "
deb http://mirrors.aliyun.com/ubuntu/ $code_name main multiverse restricted universe
deb http://mirrors.aliyun.com/ubuntu/ $code_name-backports main multiverse restricted universe
deb http://mirrors.aliyun.com/ubuntu/ $code_name-proposed main multiverse restricted universe
deb http://mirrors.aliyun.com/ubuntu/ $code_name-security main multiverse restricted universe
deb http://mirrors.aliyun.com/ubuntu/ $code_name-updates main multiverse restricted universe
deb-src http://mirrors.aliyun.com/ubuntu/ $code_name main multiverse restricted universe
deb-src http://mirrors.aliyun.com/ubuntu/ $code_name-backports main multiverse restricted universe
deb-src http://mirrors.aliyun.com/ubuntu/ $code_name-proposed main multiverse restricted universe
deb-src http://mirrors.aliyun.com/ubuntu/ $code_name-security main multiverse restricted universe
deb-src http://mirrors.aliyun.com/ubuntu/ $code_name-updates main multiverse restricted universe" > /etc/apt/sources.list

    apt update
    if [ $? -ne 0 ];then
        out F "set sources failed"
        exit 2
    fi
    out "set aliyun sources success"
}

##############设置基础命令行环境###############
set_bash_env(){
    out "set bash env"
    out "make dir"
    mkdir -p ~/code ~/local ~/opensource ~/test ~/tmp
    cp $SOURCES_DIR/git_token ~/code/

    out "set jihanrc"
    cp $TOOLS_DIR/jihanrc ~/.jihanrc

    out "set vim"
    cp $TOOLS_DIR/vimrc ~/.vimrc

    out "cp clang-format"
    cp $TOOLS_DIR/clang-format ~/.clang-format
    out "set bash success"
}

##############设置zsh###############
# 需要先配置代理
set_zsh(){
    out "set zsh"
    apt install -y zsh git autojump
    if [ $? -ne 0 ];then
        out F "install zsh failed"
        exit 2
    fi
    rm -f ~/.zshrc
    rm -rf ~/.oh-my-zsh
    out "run proxy, details see /var/log/clash.log"
    if [ ! -f ~/.config/clash/config.yaml ]; then
        out F "clash not installed"
        exit 2
    fi
    . ~/proxy
    loop loop_callback_proxy
    if [ $? -ne 0 ];then
        exit 2
    fi
    sleep 3
    echo n | sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
    . ~/proxy x
    cp $TOOLS_DIR/zsh/zshrc ~/.zshrc
    cp -rf $TOOLS_DIR/zsh/oh-my-zsh/plugins/* ~/.oh-my-zsh/plugins/
    out "set zsh success"
}

##############设置代理###############
set_proxy(){
    out "set proxy"
    cp $TOOLS_DIR/proxy ~/
    rm -rf ~/local/clash
    mkdir -p ~/local/clash
    cp $SOURCES_DIR/clash-linux-amd64* ~/local/clash/
    cd ~/local/clash
    rm -f clash
    clash_name=`ls | grep clash-linux-amd64`
    ln -s $clash_name clash
    out "run proxy, details see  /var/log/clash.log"
    rm -rf ~/.config/clash
    ./clash > /var/log/clash.log &
    loop loop_callback_proxy
    if [ $? -ne 0 ];then
        exit 2
    fi
    if [ ! -f ~/.config/clash/config.yaml ]; then
        out F "run clash failed"
        kill `pidof clash`
        exit 2
    fi
    kill `pidof clash`
    cd -
    clash_url=`cat $SOURCES_DIR/clash_url`
    wget -O ~/.config/clash/config.yaml "$clash_url" --no-check-certificate
    out "set proxy success" 
    
}


##############设置代理###############
install_golang(){
    out "install golang"
    rm -rf ~/local/go*
    cd $SOURCES_DIR
    golang_pak=`ls go*.tar.gz`
    if [ "X" = "X$golang_pak" ];then
        out E "not find golang install pacakge"
        return
    fi
    mkdir -p ~/local
    cp $golang_pak ~/local/
    cd ~/local
    tar -zxf $golang_pak
    golang_dir=`ls -d */ | grep go`
    ln -s $golang_dir go
    cd -    
    echo "GOPATH=/root/local/go/bin
    export PATH=${PATH}:${GOPATH}" >> ~/.jihanrc
    out "install golang success"
}

##############参数处理###############
default_action(){
    set_sources
    set_proxy
    set_bash_env
    set_zsh
    install_golang
}

show_help(){
                echo '
Usage: >_< [-h|s|e|p|g]
install all if not input arg

Emergency help:  
-h              Show this message  
-s              set apt sources
-e              set bash env
-p              set proxy, manual: 
                    1. rm -rf ~/.config/clash; ~/local/clash/clash
                    2. wget -O ~/.config/clash/config.yaml `cat sources/clash_url` --no-check-certificate
-z              set zsh, manual:
                    1. . ~/proxy 
                    2. sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
-g              install golang
'
}

runopt (){
    while getopts "hsepzg" opts
    do
        case $opts in
            "h")
                show_help
                exit 0
                ;;
            "s")
                set_sources
                exit 0
                ;;
            "e")
                set_bash_env
                exit 0
                ;;
            "p")
                set_proxy
                exit 0
                ;;
            "z")
                set_zsh
                exit 0
                ;;
            "g")
                install_golang
                exit 0
                ;;
            "?")
                show_help
                exit 1
                ;;
            ":")
                show_help
                exit 1
                ;;
        esac
    done
    return $OPTIND
}

##############环境检查###############
if [ ! -d $TOOLS_DIR ];then
    out F "$TOOLS_DIR not exist"
    exit 1
fi

if [ ! -d $SOURCES_DIR ];then
    out F "$SOURCES_DIR not exist"
    exit 1
fi

##############执行###############
if [ $# -gt 0 ];then
    runopt "$@"
    if [ $? -le 1 ];then
        echo "Cannot parse args: $@"
        show_help
        exit 1
    fi
    multi_args_do
    exit 0
fi
default_action

##############清理###############
