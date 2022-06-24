#! /bin/bash

if ! [[ -f etc/profile.d/zzz-users.sh ]]; then 
  echo "You need to switch to the root 
    of the Hpctoys Git repos before running this script."
  exit
fi
. etc/profile.d/zzz-users.sh
MYTMP=$(mktemp -d "${TMPDIR}/hpctoys.XXXXX")
CURRDIR=$(pwd)
SCR=${0##*/}
SUBCMD=$1
ERRLIST=""

shift
while getopts "a:b:c:d:e:f:g:h:i:j:k:l:m:n:o:p:q:r:s:t:u:v:w:x:y:z:" OPTION; do
  #echo "OPTION: -${OPTION} ARG: ${OPTARG}"
  eval OPT_${OPTION}=\$OPTARG
done
shift $((OPTIND - 1))

if ! inpath 'curl'; then
  echo "This script requires 'curl'. Please ask your system administrator to install curl and add it to your PATH."
  exit 1
fi

umask 0000
# bin folder for other single binaries
mkdir -p ${HPCTOYS_ROOT}/opt/other/bin

# installing jq, the json processor 
jq() {
if ! inpath 'jq'; then
  DURL="https://github.com/stedolan/jq/releases/download/jq-1.6/jq-linux64"
  curl -kL ${DURL} -o ${HPCTOYS_ROOT}/opt/other/bin/jq
  chmod +x ${HPCTOYS_ROOT}/opt/other/bin/jq
  ln -sfr ${HPCTOYS_ROOT}/opt/other/bin/jq ${HPCTOYS_ROOT}/bin/jq
fi
}

# Keychain
keychain() {
if ! inpath 'keychain'; then
  VER="2.8.5"
  cd ${MYTMP}
  DURL="https://github.com/funtoo/keychain/archive/refs/tags/${VER}.tar.gz"
  curl -OkL ${DURL}
  if [[ -f ${VER}.tar.gz ]]; then
    tar xf ${VER}.tar.gz
    cd keychain-${VER}
    make keychain
    cp -f ./keychain ${HPCTOYS_ROOT}/bin/keychain
    chmod +x ${HPCTOYS_ROOT}/bin/keychain
  else
    echo "unable to download ${DURL}, exiting !"
    ERRLIST+=" Keychain"
  fi
  cd ${CURRDIR}
fi
}

# installing dialog util for ncurses GUI 
dialog() {
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
    ERRLIST+=" Dialog"
  fi
  cd ${CURRDIR}
fi
}

# aws cli version 2 
awscli2() {
if ! [[ -d "${HPCTOYS_ROOT}/opt/awscli2" ]]; then 
  cd ${MYTMP}
  DURL="https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip"
  curl -OkL ${DURL}
  if [[ -f awscli-exe-linux-x86_64.zip ]]; then
    unzip awscli-exe-linux-x86_64.zip
    ./aws/install --bin-dir ${HPCTOYS_ROOT}/bin --install-dir ${HPCTOYS_ROOT}/opt/awscli2 --update
  else
    echo "unable to download ${DURL}, exiting !"
    ERRLIST+=" AWS-CLI"
  fi
  cd ${CURRDIR}
fi
}

# OpenSSL
openssl() {
if ! [[ -d "${HPCTOYS_ROOT}/opt/openssl" ]]; then
  VER="1_1_1p" 
  cd ${MYTMP}
  DURL="https://github.com/openssl/openssl/archive/refs/tags/OpenSSL_${VER}.tar.gz"
  echo -e "\n *** Installing ${DURL} ...\n"
  curl -OkL ${DURL}
  if [[ -f OpenSSL_${VER}.tar.gz ]]; then
    tar xf OpenSSL_${VER}.tar.gz
    cd openssl-OpenSSL_${VER}
    ./Configure --prefix=${HPCTOYS_ROOT}/opt/openssl \
             --openssldir=${HPCTOYS_ROOT}/opt/openssl/ssl \
             linux-x86_64 
    make -j 4
    make install
    ln -sfr ${HPCTOYS_ROOT}/opt/openssl/bin/openssl ${HPCTOYS_ROOT}/bin/openssl
    rmdir ${HPCTOYS_ROOT}/opt/openssl/ssl/certs
    if [[ -d /etc/pki/tls/certs ]]; then
      ln -sf /etc/pki/tls/certs ${HPCTOYS_ROOT}/opt/openssl/ssl/certs
    else
      ln -sf /etc/ssl/certs ${HPCTOYS_ROOT}/opt/openssl/ssl/certs
    fi
  else
    echo "unable to download ${DURL}, exiting !"
    ERRLIST+=" OpenSSL"
  fi
  export OPENSSL_ROOT=${HPCTOYS_ROOT}/opt/openssl
  cd ${CURRDIR}
fi
}

# Midnight Commander 
mc() {
if ! [[ -f "${HPCTOYS_ROOT}/opt/mc/bin/mc" ]]; then
#if ! inpath 'mc'; then
  # first install s-lang dependency
  VER="2.3.2"
  cd ${MYTMP}
  DURL=https://www.jedsoft.org/releases/slang/slang-${VER}.tar.bz2
  DURL2=https://www.jedsoft.org/releases/slang/old/slang-${VER}.tar.bz2
  echo -e "\n *** Installing ${DURL} ...\n"
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
  VER="4.8.26" # .27 and .28 fail with s-lang compile errors
  cd ${MYTMP}
  DURL="http://ftp.midnight-commander.org/mc-${VER}.tar.bz2"
  echo -e "\n *** Installing ${DURL} ...\n"
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
    if [[ "$?" -ne 0 ]]; then
      ERRLIST+=" Midnight-Commander"
    fi
    ln -sfr ${HPCTOYS_ROOT}/opt/mc/bin/mc ${HPCTOYS_ROOT}/bin/mc
  else 
    echo "unable to download ${DURL}, exiting !"
    ERRLIST+=" Midnight-Commander"
  fi
  cd ${CURRDIR}
fi
}

# Rclone 
rclone() {
if ! [[ -d "${HPCTOYS_ROOT}/opt/rclone" ]]; then
  cd ${MYTMP}
  DURL="https://downloads.rclone.org/rclone-current-linux-amd64.zip"
  echo -e "\n *** Installing ${DURL} ...\n"
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
    ERRLIST+=" Rclone"
  fi
  cd ${CURRDIR}
fi
}

# Miniconda
miniconda() {
if ! [[ -d "${HPCTOYS_ROOT}/opt/miniconda" ]]; then
  cd ${MYTMP}
  DURL="https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh"
  echo -e "\n *** Installing ${DURL} ...\n"
  curl -OkL ${DURL}
  if [[ -f Miniconda3-latest-Linux-x86_64.sh ]]; then
    bash Miniconda3-latest-Linux-x86_64.sh -b -p ${HPCTOYS_ROOT}/opt/miniconda
  else
    echo "unable to download ${DURL}, exiting !"
    ERRLIST+=" Miniconda"
  fi
  cd ${CURRDIR}
fi
}

# Python
lpython() {
# libffi-devel is needed to compile _ctypes
VER="3.11.0"
VER_B="b3" # beta ver such as b1, b2 or b3
lmodLoad gcc libffi sqlite ncurses readline
GCCVER=$(gcc -dumpfullversion)
if [[ ${GCCVER} > '8.1.0' ]]; then 
  echo -e "\n *** compiling with optimizations using GCC ${GCCVER}\n"
  COMP_WITH_OPT="--enable-optimizations --disable-test-modules"
fi
if ! [[ -f "${HPCTOYS_ROOT}/opt/lpython-${VER}.tar.xz" ]]; then
  cd ${MYTMP}
  if [[ -d ${HPCTOYS_ROOT}/opt/openssl/ssl ]]; then
    export OPENSSL_ROOT=${HPCTOYS_ROOT}/opt/openssl
  fi
  DURL="https://www.python.org/ftp/python/${VER}/Python-${VER}${VER_B}.tar.xz" 
  echo -e "\n *** Installing ${DURL} ...\n"
  curl -OkL ${DURL}
  if [[ -f Python-${VER}${VER_B}.tar.xz ]]; then 
    tar xf Python-${VER}${VER_B}.tar.xz           
    cd Python-${VER}${VER_B}                     
    addLineToFile '_socket socketmodule.c' Modules/Setup
    addLineToFile 'OPENSSL=${HPCTOYS_ROOT}/opt/openssl' Modules/Setup
    addLineToFile '_ssl _ssl.c -I$(OPENSSL)/include -L$(OPENSSL)/lib -l:libssl.a -Wl,--exclude-libs,libssl.a -l:libcrypto.a -Wl,--exclude-libs,libcrypto.a' Modules/Setup
    addLineToFile '_hashlib _hashopenssl.c -I$(OPENSSL)/include -L$(OPENSSL)/lib -l:libcrypto.a -Wl,--exclude-libs,libcrypto.a' Modules/Setup
    ./configure --prefix "${TMPDIR}/hpctoys/lpython" \
                --with-openssl=${OPENSSL_ROOT} ${COMP_WITH_OPT} 
    make -j 4
    rm -rf "${TMPDIR}/hpctoys/lpython"
    make install
    if [[ -f ${TMPDIR}/hpctoys/lpython/bin/python${VER::-2} ]]; then
      cd "${TMPDIR}/hpctoys"
      echo -e "\n *** creating archive lpython-${VER}.tar.xz ...\n"
      tar cfvJ lpython-${VER}.tar.xz ./lpython
      FSIZE=$(stat -c%s lpython-${VER}.tar.xz)
      if [[ (( ${FSIZE} -gt 30000000 )) ]]; then     
        echo -e "\n *** copying archive ...\n"
        mv -vf lpython-${VER}.tar.xz ${HPCTOYS_ROOT}/opt/
        ln -sf "${TMPDIR}/hpctoys/lpython/bin/python${VER::-2}" "${HPCTOYS_ROOT}/bin/python${VER::-2}"
        ### addional packages in ${HPCTOYS_ROOT}/opt/python
        lpip install --upgrade pip
        lpip install openstackclient \
             pyyaml pandas paramiko pythondialog easybuild
      else
        echo -e "\n *** There was a problem installing Python ${VER}.\n"
        ERRLIST+=" Python"
      fi
    else
      echo -e "\n *** There was a problem installing Python ${VER}.\n"
      ERRLIST+=" Python"
    fi
  else
    echo "unable to download ${DURL}, exiting !"
    ERRLIST+=" Python"
  fi
  cd ${CURRDIR}
fi
}

cd ${CURRDIR}
bash setdefaults.sh ${MYTMP}

if [[ -z ${SUBCMD} ]]; then
  # Run all installations or comment out
  jq
  keychain
  dialog
  awscli2
  openssl
  mc
  rclone
  miniconda
  lpython
elif [[ ${SUBCMD} =~ ^(jq|keychain|dialog|awscli2|openssl|mc|rclone|miniconda|lpython|)$ ]]; then
  ${SUBCMD} "$@"
else
  echo "Invalid subcommand: ${SUBCMD}" >&2
  help
  exit 1
fi

# cleanup
if [[ -z ${ERRLIST} ]]; then
  rm -rf ${MYTMP}
else
  echo "Errors in these installations: ${ERRLIST}"
  echo "Check ${MYTMP} for troubleshooting"
fi

