#!bin/bash

cur_path=$(cd "$(dirname "$0")"; pwd)
cur_workdir=${cur_path}/Nvidia_CUDA
cur_sys=`cat /etc/*-release | sed -r "s/^ID=(.*)$/\\1/;tA;d;:A;s/^\"(.*)\"$/\\1/" | tr -d '\n'`

# Stop the script when any Error occur
set -e

# Functions
Color_Error='\E[1;31m'
Color_Success='\E[1;32m'
Color_Res='\E[0m'

function echo_error(){
    echo -e "${Color_Error}${1}${Color_Res}"
}

function echo_success(){
    echo -e "${Color_Success}${1}${Color_Res}"
}

function service_detect(){
    tmp_status=`service --status-all | sed -r "s/^\s*\[\s*[+|-]\s*\]\s*${1}\$/true/;tA;d;:A;" | tr -d '\n'`
    printf ${tmp_status:-false}
}

function modules_detect(){
    tmp_status=`lsmod | sed -r "s/^${1}\s+[0-9]+\s+[0-9]+.*\$/true/;tA;d;:A;" | tr -d '\n'`
    printf ${tmp_status:-false}
}

function runlevel_detect(){
    tmp_status=`runlevel | sed -r "s/^[N0-6]\s+${1}\$/true/;tA;d;:A;" | tr -d '\n'`
    printf ${tmp_status:-false}
}

CUDA_Kit_list=(
    # CUDA
    cuda_*_*_linux.run
    # CUDNN
    cudnn-*.tgz
)

# Detect CUDA & CUDNN
echo_error "Detecting CUDA runtime"
for v in ${CUDA_Kit_list[@]}; do
    if [ ! -e ${cur_workdir}/${v} ]; then
        echo_error 'Please make sure u had download CUDA & CUDNN Kit'
        echo_success "Problem could be solved by reading ${cur_workdir}/readme.md"
        echo_error "${cur_workdir}/${v} Needed"
        exit 1
    fi
done
echo_success "Detecting CUDA runtime : [ Done ]"

# Detect Desktop Service
echo_error "Detecting Graphical Service"
Desktop_Service=false
case ${cur_sys} in
    "ubuntu")
        Desktop_Service=`service_detect "lightdm"`
        if ${Desktop_Service}; then
            sudo service lightdm stop
        fi
    ;;
    "centos")
        Desktop_Service=`runlevel_detect "5"`
        if ${Desktop_Service}; then
            sudo systemctl set-default multi-user.target
            sudo systemctl isolate multi-user.target
        fi
    ;;
esac
echo_success "Detecting Graphical Service : [ ${Desktop_Service} ]"

# Disable the Nouveau
echo_error "Detecting Nouveau module"
Nouveau_Blacklist_Root=/etc/modprobe.d/nvidia-installer-disable-nouveau.conf
var_auto_reboot=`modules_detect "nouveau"`
echo_success "Detecting Nouveau module : [ ${var_auto_reboot} ]"

if ${var_auto_reboot}; then
    echo '# generated by nvidia-installer' > ${Nouveau_Blacklist_Root}
    echo 'blacklist nouveau' >> ${Nouveau_Blacklist_Root}
    echo 'options nouveau modeset=0' >> ${Nouveau_Blacklist_Root}

    case ${cur_sys} in
        "ubuntu")
            # Update Source
            sudo apt-get update
            sudo update-initramfs -u
        ;;
        "centos")
            sudo sed -ri "s/^\s*#?(\s*blacklist\s+nvidiafb)\$/#\\1/g" /usr/lib/modprobe.d/dist-blacklist.conf
            sudo dracut --force
        ;;
    esac
fi

# Install Basic Env
echo_error "Installing OS Env"
case ${cur_sys} in
    "ubuntu")
        sudo apt-get install -y dkms linux-headers-$(uname -r) build-essential cmake
    ;;
    "centos")
        sudo yum install -y epel-release
        sudo yum install -y dkms kernel-headers-$(uname -r) kernel-devel-$(uname -r) cmake
    ;;
esac
echo_success "Installing OS Env : [ Done ]"

# Nvidia Driver Detect
echo_error "Detecting Nvidia module"
var_nvidia_exist=`modules_detect "nvidia"`
echo_success "Detecting Nvidia module : [ ${var_nvidia_exist} ]"

# CUDA Install
if ${var_nvidia_exist}; then
    sudo bash ${cur_workdir}/cuda_*_*_linux.run --toolkit --override --silent
else
    Nvidia_Driver=${cur_workdir}/NVIDIA-Linux-x86_64-*.*.run
    if [ -e ${Nvidia_Driver} ]; then
        if ! ${var_auto_reboot}; then
            sudo bash ${Nvidia_Driver} --dkms --disable-nouveau --run-nvidia-xconfig --silent
            echo_error "ReDetecting Nvidia module"
            var_nvidia_exist=`modules_detect "nvidia"`
            echo_success "ReDetecting Nvidia module : [ ${var_nvidia_exist} ]"
            if ${var_nvidia_exist}; then
                sudo bash ${cur_workdir}/cuda_*_*_linux.run --toolkit --override --silent
            fi
        fi
    else
        sudo bash ${cur_workdir}/cuda_*_*_linux.run --driver --no-opengl-libs --run-nvidia-xconfig --toolkit --override --silent
    fi
fi

# Reboot was needed for disable nouveau
if ${var_auto_reboot}; then
    echo_error "Please rerun this script after reboot ! ! !"
    read -n1 -sp "Press any key except 'ESC' to reboot: " var_ikey
    case ${var_ikey:=*} in
        $'\e')
            echo_success "Reboot has been canceled"
        ;;
        *)
            sudo reboot now
        ;;
    esac
else
    # CUDA Env
    CUDA_Profile_Root=/etc/profile.d/cuda.sh
    CUDA_HOME=/usr/local/cuda
    echo "export CUDA_HOME=${CUDA_HOME}" > ${CUDA_Profile_Root}
    echo 'export PATH=$CUDA_HOME/bin:$PATH' >> ${CUDA_Profile_Root}
    echo 'export LD_LIBRARY_PATH=$CUDA_HOME/lib64:$LD_LIBRARY_PATH' >> ${CUDA_Profile_Root}
    echo 'export INCLUDE=$CUDA_HOME/include:$INCLUDE' >> ${CUDA_Profile_Root}
    source ${CUDA_Profile_Root}

    # CUDA Conf Env
    CUDA_Conf_Root=/etc/ld.so.conf.d/cuda.conf
    echo '/usr/local/cuda/lib64' > ${CUDA_Conf_Root}
    sudo ldconfig

    # CUDNN Install
    sudo tar -zxvf ${cur_workdir}/cudnn-*.tgz -C /usr/local
    
    read -n1 -sp "Press any key except 'ESC' to launch desktop: " var_ikey
    case ${var_ikey:=*} in
        $'\e')
            echo_success "Desktop launch has been canceled"
        ;;
        *)
            case ${cur_sys} in
                "ubuntu")
                    if ${Desktop_Service}; then
                        sudo service lightdm start
                    fi
                ;;
                "centos")
                    if ${Desktop_Service}; then
                        sudo systemctl set-default graphical.target
                        sudo systemctl isolate graphical.target
                    fi
                ;;
            esac
        ;;
    esac
    echo_success "CUDA Ready"
fi
