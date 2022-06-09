#! /bin/bash

MYTMP=$(mktemp -d /tmp/hpctoys.XXXXX)

if ! [[ -f etc/profile.d/zzz-users.sh ]]; then 
  echo "You need to switch to the root 
    of the Hpctoys Git repos before running this script."
  exit
fi
. etc/profile.d/zzz-users.sh
MYTMP=$(mktemp -d /tmp/hpctoys.XXXXX)
CURRDIR=$(pwd)

if ! inpath 'curl'; then
  echo "This script requires 'curl'. Please ask your system administrator to install wget and add it to your PATH."
  exit 1
fi

# installing jq, the json processor 
if ! inpath 'jq'; then
  DURL="https://github.com/stedolan/jq/releases/download/jq-1.6/jq-linux64"
  curl -skL ${DURL} -o ${HPCTOYS_ROOT}/bin/jq
  chmod +x ${HPCTOYS_ROOT}/bin/jq
fi

# installing dialog util for ncurses GUI 
if ! inpath 'dialog'; then
  cd ${MYTMP}
  DURL="https://invisible-island.net/datafiles/release/dialog.tar.gz"
  curl -OskL ${DURL}
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
  curl -OskL ${DURL}
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
  VER=4.8.28
  cd ${MYTMP}
  DURL="http://ftp.midnight-commander.org/mc-${VER}.tar.bz2"
  #curl -OskL ${DURL}
  if [[ -f mc-${VER}.tar.bz2 ]]; then
    tar xf mc-${VER}.tar.bz2
    cd mc-*
    ./configure --prefix ${HPCTOYS_ROOT}/opt/mc
    make -j 4
    make install
    ln -s ${HPCTOYS_ROOT}/opt/mc/bin/mc ${HPCTOYS_ROOT}/bin/mc
  else 
    echo "unable to download ${DURL}, exiting !"
  fi
  cd ${CURRDIR}
fi

# rclone 
if ! [[ -d "${HPCTOYS_ROOT}/opt/rclone" ]]; then
  cd ${MYTMP}
  DURL="https://downloads.rclone.org/rclone-current-linux-amd64.zip"
  curl -OskL ${DURL}
  if [[ -f rclone-current-linux-amd64.zip ]]; then
    unzip rclone-current-linux-amd64.zip
    cd rclone-v*
    mkdir -p ${HPCTOYS_ROOT}/opt/rclone
    mkdir -p ${HPCTOYS_ROOT}/opt/rclone/man
    cp -f * ${HPCTOYS_ROOT}/opt/rclone
    ln -s ${HPCTOYS_ROOT}/opt/rclone/rclone ${HPCTOYS_ROOT}/bin/rclone
    ln -s ${HPCTOYS_ROOT}/opt/rclone/rclone.1 ${HPCTOYS_ROOT}/opt/rclone/man/rclone.1
  else
    echo "unable to download ${DURL}, exiting !"
  fi
  cd ${CURRDIR}
fi

# Miniconda
if ! [[ -d "${HPCTOYS_ROOT}/opt/miniconda" ]]; then
  cd ${MYTMP}
  DURL="https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh"
  curl -OskL ${DURL}
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

rm -rf ${MYTMP}


