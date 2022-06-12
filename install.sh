#! /bin/bash

if ! [[ -f etc/profile.d/zzz-users.sh ]]; then 
  echo "You need to switch to the root 
    of the Hpctoys Git repos before running this script."
  exit
fi
. etc/profile.d/zzz-users.sh
MYTMP=$(mktemp -d /tmp/hpctoys.XXXXX)
CURRDIR=$(pwd)

if ! inpath 'curl'; then
  echo "This script requires 'curl'. Please ask your system administrator to install curl and add it to your PATH."
  exit 1
fi

# bin folder for other single binaries
mkdir -p ${HPCTOYS_ROOT}/opt/other/bin

# installing jq, the json processor 
if ! inpath 'jq'; then
  DURL="https://github.com/stedolan/jq/releases/download/jq-1.6/jq-linux64"
  curl -kL ${DURL} -o ${HPCTOYS_ROOT}/opt/other/bin/jq
  chmod +x ${HPCTOYS_ROOT}/opt/other/bin/jq
  ln -sfr ${HPCTOYS_ROOT}/opt/other/bin/jq ${HPCTOYS_ROOT}/bin/jq
fi

# installing dialog util for ncurses GUI 
if ! inpath 'dialog'; then
  cd ${MYTMP}
  DURL="https://invisible-island.net/datafiles/release/dialog.tar.gz"
  curl -OkL ${DURL}
  if [[ -f dialog.tar.gz ]]; then
    tar xf dialog.tar.gz
    cd dialog*
    ./configure --prefix ${HPCTOYS_ROOT}/opt/dialog
    make -j 4
    make install
    ln -s ${HPCTOYS_ROOT}/opt/dialog/bin/dialog ${HPCTOYS_ROOT}/bin/dialog
  else
    echo "unable to download ${DURL}, exiting !"
  fi
  cd ${CURRDIR}
fi

# aws cli version 2 
if ! [[ -d "${HPCTOYS_ROOT}/opt/awscli2" ]]; then 
  cd ${MYTMP}
  DURL="https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip"
  curl -OkL ${DURL}
  if [[ -f awscli-exe-linux-x86_64.zip ]]; then
    unzip awscli-exe-linux-x86_64.zip
    ./aws/install --bin-dir ${HPCTOYS_ROOT}/bin --install-dir ${HPCTOYS_ROOT}/opt/awscli2 --update
  else
    echo "unable to download ${DURL}, exiting !"
  fi
  cd ${CURRDIR}
fi

# midnight commander 
if ! [[ -d "${HPCTOYS_ROOT}/opt/mc" ]]; then
  # first install s-lang dependency
  VER=2.3.2
  cd ${MYTMP}
  DURL=https://www.jedsoft.org/releases/slang/slang-${VER}.tar.bz2
  DURL2=https://www.jedsoft.org/releases/slang/old/slang-${VER}.tar.bz2
  curl -OkL ${DURL}
  if ! [[ -f slang-${VER}.tar.bz2 ]]; then
    curl -OkL ${DURL2}
  fi
  if [[ -f slang-${VER}.tar.bz2 ]]; then
    tar xf slang-${VER}.tar.bz2
    cd slang-${VER}
    ./configure --prefix ${HPCTOYS_ROOT}/opt/mc
    #static & dynamic: make && make check && make install-all
    make static  
    make install-static
  fi
  # then install MC
  VER=4.8.26 # .27 and .28 fail with s-lang compile errors
  cd ${MYTMP}
  DURL="http://ftp.midnight-commander.org/mc-${VER}.tar.bz2"
  curl -OkL ${DURL}
  if [[ -f mc-${VER}.tar.bz2 ]]; then
    tar xf mc-${VER}.tar.bz2
    cd mc-${VER}
    ./configure --prefix ${HPCTOYS_ROOT}/opt/mc \
                --with-slang-includes=${HPCTOYS_ROOT}/opt/mc/include \
                --with-slang-libs=${HPCTOYS_ROOT}/opt/mc/lib \
                --enable-charset
    make -j 4
    make install
    ln -sfr ${HPCTOYS_ROOT}/opt/mc/bin/mc ${HPCTOYS_ROOT}/bin/mc
  else 
    echo "unable to download ${DURL}, exiting !"
  fi
  cd ${CURRDIR}
fi

# rclone 
if ! [[ -d "${HPCTOYS_ROOT}/opt/rclone" ]]; then
  cd ${MYTMP}
  DURL="https://downloads.rclone.org/rclone-current-linux-amd64.zip"
  curl -OkL ${DURL}
  if [[ -f rclone-current-linux-amd64.zip ]]; then
    unzip rclone-current-linux-amd64.zip
    cd rclone-v*
    mkdir -p ${HPCTOYS_ROOT}/opt/rclone
    mkdir -p ${HPCTOYS_ROOT}/opt/rclone/man
    cp -f * ${HPCTOYS_ROOT}/opt/rclone
    ln -sfr ${HPCTOYS_ROOT}/opt/rclone/rclone ${HPCTOYS_ROOT}/bin/rclone
    ln -sfr ${HPCTOYS_ROOT}/opt/rclone/rclone.1 ${HPCTOYS_ROOT}/opt/rclone/man/rclone.1
  else
    echo "unable to download ${DURL}, exiting !"
  fi
  cd ${CURRDIR}
fi

# Miniconda
if ! [[ -d "${HPCTOYS_ROOT}/opt/miniconda" ]]; then
  cd ${MYTMP}
  DURL="https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh"
  curl -OkL ${DURL}
  if [[ -f Miniconda3-latest-Linux-x86_64.sh ]]; then
    bash Miniconda3-latest-Linux-x86_64.sh -b -p ${HPCTOYS_ROOT}/opt/miniconda
  else
    echo "unable to download ${DURL}, exiting !"
  fi
  cd ${CURRDIR}
fi

# Python 
mypip install --upgrade pip
mypip install --upgrade openstackclient pyyaml pandas paramiko pythondialog easybuild

cd ${CURRDIR}
bash setdefaults.sh ${MYTMP}

rm -rf ${MYTMP}


