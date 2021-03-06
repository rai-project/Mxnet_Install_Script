#!bin/bash

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

git clone --recursive https://github.com/apache/incubator-mxnet.git ./mxnet 
tar -zcvf mxnet.tar.gz ./mxnet

git clone --recursive https://github.com/baidu-research/warp-ctc.git ./warp-ctc 
tar -zcvf warp-ctc.tar.gz ./warp-ctc

echo_success "Clone Done!"
