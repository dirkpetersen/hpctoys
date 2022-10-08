#! /bin/bash

#set -x

### required packages on redhat based systems:
###   gcc-c++ make git
### required packages on debian based systems: 
### build-essential git

CURRDIR=$(pwd)
if [[ -f ${BASH_SOURCE} ]]; then
  cd $(dirname "$(realpath "${BASH_SOURCE}")")
else
  echo 'Your shell does not support ${BASH_SOURCE}. Please use "bash" to setup hpctoys.'
  exit
fi
if ! [[ -f etc/profile.d/zzz-hpctoys.sh ]]; then 
  echo "You need to switch to the root 
    of the Hpctoys Git repos before running this script."
  exit
fi
. etc/profile.d/zzz-hpctoys.sh
INTMP=$(mktemp -d "${TMPDIR}/hpctoys.XXX")
SCR=${0##*/}
SUBCMD=$1
ERRLIST=""
export DIALOGRC=${HPCTOYS_ROOT}/etc/.dialogrc
RUNCPUS=8
[[ -n ${SLURM_CPUS_ON_NODE} ]] && RUNCPUS=$((${SLURM_CPUS_ON_NODE}*2))

[[ -n $1 ]] && shift
while getopts "a:b:c:d:e:f:g:h:i:j:k:l:m:n:o:p:q:r:s:t:u:v:w:x:y:z:" OPTION; do
  #echo "OPTION: -${OPTION} ARG: ${OPTARG}"
  eval OPT_${OPTION}=\$OPTARG
done
shift $((OPTIND - 1))


if ! [[ -f ${HPCTOYS_ROOT}/etc/hpctoys/install_success ]]; then 
  echoerr "\n *** Preparing Installation of HPC Toys ***"
  echoerr " \n If you have sudo rights, cancel this installer,"  
  echoerr " run 'sudo test' and restart the install"
  echoerr " \n This installer may take up to 5 minutes to"
  echoerr " install source packages into the ./opt subfolder."
  echoerr " \n *** Waiting for 3 sec *** ..."
  echoerr " "
  read -t 3 -n 1 -r -s -p $' (Press any key to cancel the setup)\n'
  if [[ $? -eq 0 ]]; then
    echoerr " Setup interrupted, exiting ...\n"
    exit
  fi
  echoerr "\n * Purging environment modules *"
  [ -x module ] && module purge
fi

umask 0000
# bin folder for other single binaries
mkdir -p ${HPCTOYS_ROOT}/opt/other/bin

ipackages() {

  # install OS PKG if we have sudo access now
  if sudo -n true 2>/dev/null; then
    echoerr "\n Installing packages with Sudo access"
    PKG="vim jq mc dialog pkgconf gettext curl "
    PKGDNF="gcc openssl-devel bzip2-devel libffi-devel "
    PKGAPT="build-essential uuid-dev zlib1g-dev liblzma-dev libbz2-dev libgdbm-dev "
    PKGAPT+="libssl-dev  libreadline-dev libsqlite3-dev libncurses5-dev libffi-dev "
    if htyInPath 'dnf'; then
      echoerr "\n *** Installing packages :${PKG}${PKGDNF}"
      sudo dnf -y groupinstall "Development Tools" #--with-optional
      sudo dnf install -y ${PKG}${PKGDNF}
    elif htyInPath 'yum'; then
      echoerr "\n *** Installing packages :${PKG}${PKGDNF}"
      sudo yum -y groupinstall "Development Tools" #--with-optional
      sudo yum install -y ${PKG}${PKGDNF}
    elif htyInPath 'apt'; then
      echoerr "\n *** Installing packages :${PKG}${PKGAPT}"
      sudo apt install -y ${PKG}${PKGAPT}
    fi
  else
    MISS=""
    ! htyInPath 'curl'  && MISS+="curl "
    ! htyInPath 'pkg-config'  && MISS+="pkgconf "
    if [[ -n ${MISS} ]]; then
      echoerr "\n Missing packages! Please have these packages installed:\n ${MISS}"
      exit 1
    fi
  fi

}


# installing generic (other) dependencies 
iother() {

  # optionally install any version of ncurses 
  NCURSESOPT=''
  if [[ -z $(pkg-config --silence-errors --modversion ncurses) ]]; then
    VER="6.3"
    if [[ ! -f ${HPCTOYS_ROOT}/opt/other/lib/libncurses.a ]]; then
      echoerr "\n * Installing 'ncurses' lib for 'dialog' ... *\n"
      sleep 1
      cd ${INTMP}
      DURL="https://ftp.gnu.org/pub/gnu/ncurses/ncurses-${VER}.tar.gz"
      if ! htyInstallSource "${DURL}" "opt/other" "bin/ncurses6-config"; then
        htyEcho "Error in htyInstallSource ${DURL}"
      fi
    fi
    NCURSESOPT="--with-curses-dir=${HPCTOYS_ROOT}/opt/other"
  fi

  # optionally install libffi >= 3.0.0
  CURRVER=$(pkg-config --silence-errors --modversion libffi)
  if [[ $(htyIntVersion ${CURRVER}) -lt $(htyIntVersion "3.0.0") ]]; then
    VER="3.4.2"
    if [[ ! -f ${HPCTOYS_ROOT}/opt/other/lib/libffi.a && 
          ! -f ${HPCTOYS_ROOT}/opt/other/lib64/libffi.a ]]; then
      echoerr "\n * Installing 'libffi for mc and python' ${VER} ... *\n"
      sleep 1
      cd ${INTMP}
      DURL="https://github.com/libffi/libffi/releases/download/v${VER}/libffi-${VER}.tar.gz"
      if ! htyInstallSource "${DURL}" "opt/other"; then
        htyEcho "Error in htyInstallSource ${DURL}"
      fi
    fi
    export LIBFFI_LIBS="-L${HPCTOYS_ROOT}/opt/other/lib -lffi"
    export LIBFFI_CFLAGS="-I${HPCTOYS_ROOT}/opt/other/include"
  fi

  # optionally install zlib >=1
  CURRVER=$(pkg-config --silence-errors --modversion zlib)
  if [[ $(htyIntVersion ${CURRVER}) -lt $(htyIntVersion "1.0") ]]; then
    VER="1.2.12"
    if [[ ! -f ${HPCTOYS_ROOT}/opt/other/lib/libz.a ]]; then
      echoerr "\n * Installing 'zlib for glib-2.0' ${VER} ... *\n"
      sleep 1
      cd ${INTMP}
      DURL="https://zlib.net/zlib-${VER}.tar.gz"
      if ! htyInstallSource "${DURL}" "opt/other"; then
        htyEcho "Error in htyInstallSource ${DURL}"
      fi
    fi
    export ZLIB_LIBS="-L${HPCTOYS_ROOT}/opt/other/lib -lz"
    export ZLIB_CFLAGS="-I${HPCTOYS_ROOT}/opt/other/include"
  fi

  # optionally install readline >= 3.0.0
  CURRVER=$(pkg-config --silence-errors --modversion readline)
  if [[ $(htyIntVersion ${CURRVER}) -lt $(htyIntVersion "3.0.0") ]]; then
    VER="8.1"
    if [[ ! -f ${HPCTOYS_ROOT}/opt/other/lib/libreadline.a ]]; then
      echoerr "\n * Installing 'readline for python' ${VER} ... *\n"
      sleep 1
      cd ${INTMP}
      DURL="https://ftp.gnu.org/gnu/readline/readline-${VER}.tar.gz"
      if ! htyInstallSource "${DURL}" "opt/other"; then
        htyEcho "Error in htyInstallSource ${DURL}"
      fi
    fi
    export READLINE_LIBS="-L${HPCTOYS_ROOT}/opt/other/lib -lreadline"
    export READLINE_CFLAGS="-I${HPCTOYS_ROOT}/opt/other/include"
  fi
}


# installing dialog util for ncurses GUI
idialog() {
if ! htyInPath 'dialog'; then
  # if ncurses is garbled run 'sudo update-locale' 
  # or 'sudo update-locale LANG=en_US.UTF-8'
  echoerr "\n * Installing 'dialog' ... *\n"
  sleep 1
  cd ${INTMP}
  DURL="https://invisible-island.net/datafiles/release/dialog.tar.gz"
  if ! htyInstallSource "${DURL}" "opt/dialog ${NCURSESOPT}" "bin/dialog"; then
    htyEcho "Error in htyInstallSource ${DURL}"
  fi
  cd ${CURRDIR}
fi
}

# installing jq, the json processor 
ijq() {
if ! htyInPath 'jq'; then
  VER="1.6"
  echoerr "\n * Installing 'jq' ${VER} ... *\n"
  sleep 1
  DURL="https://github.com/stedolan/jq/releases/download/jq-${VER}/jq-linux64"
  curl -kL ${DURL} -o ${HPCTOYS_ROOT}/opt/other/bin/jq
  chmod +x ${HPCTOYS_ROOT}/opt/other/bin/jq
  ln -sfr ${HPCTOYS_ROOT}/opt/other/bin/jq ${HPCTOYS_ROOT}/bin/jq
fi
}

# installing yq, the yaml processor
iyq() {
if ! htyInPath 'yq'; then
  VER=4.25.3
  echoerr "\n * Installing 'yq' ${VER} ... *\n"
  sleep 1
  DURL="https://github.com/mikefarah/yq/releases/download/v${VER}/yq_linux_amd64"
  curl -kL ${DURL} -o ${HPCTOYS_ROOT}/opt/other/bin/yq
  chmod +x ${HPCTOYS_ROOT}/opt/other/bin/yq
  ln -sfr ${HPCTOYS_ROOT}/opt/other/bin/yq ${HPCTOYS_ROOT}/bin/yq
fi
}

# Keychain
ikeychain() {
if ! htyInPath 'keychain'; then
  VER="2.8.5"
  echoerr "\n * Installing 'keychain' ${VER} ... *\n"
  sleep 1
  cd ${INTMP}
  DURL="https://github.com/funtoo/keychain/archive/refs/tags/${VER}.tar.gz"
  if htyDownloadUntarCd "${DURL}" "keychain-"; then
    make keychain
    cp -f ./keychain ${HPCTOYS_ROOT}/bin/keychain
    chmod +x ${HPCTOYS_ROOT}/bin/keychain
    mkdir -p ~/bin
    cp -f ${HPCTOYS_ROOT}/bin/keychain ~/bin
  fi
  cd ${CURRDIR}
fi
}

# Github CLI
igithub() {
if ! htyInPath 'gh'; then
  VER="2.13.0"
  echoerr "\n * Installing 'github cli' ${VER} ... *\n"
  sleep 1
  cd ${INTMP}
  DURL="https://github.com/cli/cli/releases/download/v${VER}/gh_${VER}_linux_amd64.tar.gz"
  curl -OkL ${DURL}
  if [[ -f gh_${VER}_linux_amd64.tar.gz ]]; then
    tar xf gh_${VER}_linux_amd64.tar.gz
    cd gh_${VER}_linux_amd64
    #echo $INTMP
    #exit
    cp -f ./bin/* ${HPCTOYS_ROOT}/opt/other/bin/
    mkdir -p ${HPCTOYS_ROOT}/opt/other/share/man/man1
    cp -f ./share/man/man1/* ${HPCTOYS_ROOT}/opt/other/share/man/man1/
    chmod +x ${HPCTOYS_ROOT}/opt/other/bin/gh
    ln -sfr ${HPCTOYS_ROOT}/opt/other/bin/gh ${HPCTOYS_ROOT}/bin/gh
  else
    echo "unable to download ${DURL}, exiting !"
    ERRLIST+=" Github"
  fi
  cd ${CURRDIR}
fi
}

# aws cli version 2 
iawscli2() {
if ! [[ -d "${HPCTOYS_ROOT}/opt/awscli2" ]]; then 
  echoerr "\n * Installing 'awscli2' ${VER} ... *\n"
  sleep 1
  cd ${INTMP}
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


# Midnight Commander 
imc() {
#if ! [[ -f "${HPCTOYS_ROOT}/opt/mc/bin/mc" ]]; then
if ! htyInPath 'mc'; then
  #export LD_LIBRARY_PATH=${HPCTOYS_ROOT}/opt/mc/lib:${LD_LIBRARY_PATH}

  # compiling gettext from source is not detected by glib-2
  #https://ftp.gnu.org/gnu/gettext/gettext-0.21.tar.xz
  #disabled
  if ! htyInPath 'msgfmt'; then
    echo '#! /bin/bash' > ${HPCTOYS_ROOT}/bin/msgfmt
    echo 'echo "This is a dummy wrapper for msgfmt"' \
                      >> ${HPCTOYS_ROOT}/bin/msgfmt
    echo 'echo "install the gettext package and delete msgfmt"' \
                      >> ${HPCTOYS_ROOT}/bin/msgfmt
    chmod +x ${HPCTOYS_ROOT}/bin/msgfmt
    ${HPCTOYS_ROOT}/bin/msgfmt
    sleep 1
  fi

  # optionally install glib-2 >= 2.30
  CURRVER=$(pkg-config --silence-errors --modversion glib-2.0)
  if [[ $(htyIntVersion ${CURRVER}) -lt $(htyIntVersion "2.30") ]]; then
    VER="2.56"
    echoerr "\n * Installing 'glib-2.0 for mc' ${VER} ... *\n"
    sleep 1
    cd ${INTMP}
    DURL="https://download.gnome.org/sources/glib/${VER}/glib-${VER}.0.tar.xz"
    GLIB_MYOPT="--disable-libmount --disable-selinux  --with-pcre=internal"
    if ! htyInstallSource "${DURL}" "opt/mc ${GLIB_MYOPT}"; then
      htyEcho "Installing glib-2.0 failed, exiting mc install"
      return 1
    fi
    export GLIB_LIBS="-L${HPCTOYS_ROOT}/opt/mc/lib -lglib-2.0"
    export GLIB_CFLAGS="-I${HPCTOYS_ROOT}/opt/mc/include/glib-2.0"
           GLIB_CFLAGS+=" -I${HPCTOYS_ROOT}/opt/mc/lib/glib-2.0/include"
  fi

  # install s-lang dependency
  VER="2.3.2"
  echoerr "\n * Installing 'slang for mc' ${VER} ... *\n"
  cd ${INTMP}
  DURL=https://www.jedsoft.org/releases/slang/slang-${VER}.tar.bz2
  DURL2=https://www.jedsoft.org/releases/slang/old/slang-${VER}.tar.bz2
  downok=0
  htyDownloadUntarCd "${DURL}" && downok=1
  [[ ! downok ]] && htyDownloadUntarCd "${DURL2}" && downok=1
  if [[ downok ]]; then
    ./configure --prefix ${HPCTOYS_ROOT}/opt/mc
    #static & dynamic: make && make check && make install-all
    make static  
    make install-static
    [[ "$?" -ne 0 ]] && ERRLIST+=" s-lang"
  fi

  # then install MC
  VER="4.8.26" # .27 and .28 fail with s-lang compile errors
  echoerr "\n * Installing 'mc' ${VER} ... *\n"
  cd ${INTMP}
  DURL="http://ftp.midnight-commander.org/mc-${VER}.tar.bz2"
  if htyDownloadUntarCd "${DURL}"; then
    ./configure --prefix ${HPCTOYS_ROOT}/opt/mc \
                --with-slang-includes=${HPCTOYS_ROOT}/opt/mc/include \
                --with-slang-libs=${HPCTOYS_ROOT}/opt/mc/lib \
                --enable-charset
    make -j ${RUNCPUS}
    make install
    if [[ "$?" -ne 0 ]]; then 
      ERRLIST+=" Midnight-Commander"
    else
      ln -sfr ${HPCTOYS_ROOT}/opt/mc/bin/mc ${HPCTOYS_ROOT}/bin/mc
    fi
  fi
  cd ${CURRDIR}
fi
}

# Rclone 
irclone() {
if ! [[ -d "${HPCTOYS_ROOT}/opt/rclone" ]]; then
  echoerr "\n * Installing 'rclone' ... *\n"
  cd ${INTMP}
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
iminiconda() {
if ! [[ -d "${HPCTOYS_ROOT}/opt/miniconda" ]]; then
  echoerr "\n * Installing 'miniconda' ... *\n"
  cd ${INTMP}
  DURL="https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh"
  echo -e "\n *** Installing ${DURL} ...\n"
  curl -OkL ${DURL}
  if [[ -f Miniconda3-latest-Linux-x86_64.sh ]]; then
    # install to network 
    bash Miniconda3-latest-Linux-x86_64.sh -b -p ${HPCTOYS_ROOT}/opt/miniconda
    ${HPCTOYS_ROOT}/opt/miniconda/bin/conda update -y python
    ${HPCTOYS_ROOT}/opt/miniconda/bin/python3 \
                 -m pip install --upgrade pip
    ${HPCTOYS_ROOT}/opt/miniconda/bin/python3 \
                 -m pip install --upgrade \
                 -r ${HPCTOYS_ROOT}/requirements.txt

    # 2nd install locally called lpython
    ME=$(whoami)
    mkdir -p /tmp/${ME}/lpython
    bash Miniconda3-latest-Linux-x86_64.sh -b -p /tmp/${ME}/lpython
    /tmp/${ME}/lpython/bin/conda update -y python
    /tmp/${ME}/lpython/bin/python3 \
                 -m pip install --upgrade pip
    /tmp/${ME}/lpython/bin/python3 \
                 -m pip install --upgrade \
                 -r ${HPCTOYS_ROOT}/requirements.txt
  else
    echo "unable to download ${DURL}, exiting !"
    ERRLIST+=" Miniconda"
  fi
  cd ${CURRDIR}
fi
}

# OpenSSL needed for lpython
iopenssl() {
SSLVER=$(pkg-config --silence-errors --modversion openssl)
if [[ $(htyIntVersion ${SSLVER}) -lt $(htyIntVersion "1.1.1") ]]; then
  if ! [[ -f "${HPCTOYS_ROOT}/opt/openssl/bin/openssl" ]]; then
    VER="1_1_1p"
    echoerr "\n * Installing 'openssl' ${VER} ... *\n"
    cd ${INTMP}
    DURL="https://github.com/openssl/openssl/archive/refs/tags/OpenSSL_${VER}.tar.gz"
    echo -e "\n *** Installing ${DURL} ...\n"
    curl -OkL ${DURL}
    if [[ -f OpenSSL_${VER}.tar.gz ]]; then
      tar xf OpenSSL_${VER}.tar.gz
      cd openssl-OpenSSL_${VER}
      ./Configure --prefix=${HPCTOYS_ROOT}/opt/openssl \
               --openssldir=${HPCTOYS_ROOT}/opt/openssl/ssl \
               linux-x86_64
      make -j ${RUNCPUS}
      make install
      ln -sfr ${HPCTOYS_ROOT}/opt/openssl/bin/openssl ${HPCTOYS_ROOT}/bin/openssl
      rmdir ${HPCTOYS_ROOT}/opt/openssl/ssl/certs
      if [[ -d /etc/pki/tls/certs ]]; then
        # RHEL systems
        ln -sf /etc/pki/tls/certs ${HPCTOYS_ROOT}/opt/openssl/ssl/certs
      else
        # Xbuntu systems
        ln -sf /etc/ssl/certs ${HPCTOYS_ROOT}/opt/openssl/ssl/certs
      fi
    else
      echo "unable to download ${DURL}, exiting !"
      ERRLIST+=" OpenSSL"
    fi
  fi 
  export OPENSSL_ROOT=${HPCTOYS_ROOT}/opt/openssl
  cd ${CURRDIR}
fi
}


# a special Python for a user group that is optimzed and locally cached. 
ilpython() {
VER="3.10.5"
VER_B="" # beta ver such as b1, b2 or b3
cd ${INTMP}
if ! [[ -f "${HPCTOYS_ROOT}/opt/lpython-${VER}.tar.xz" ]]; then
  echoerr "\n * Installing 'lpython' ${VER}${VER_B} ... *\n"
  #htyLoadLmod gcc
  #libffi sqlite ncurses readline libreadline
  GCCVER=$(gcc -dumpfullversion)
  #echo -e "\n Using GCC ${GCCVER} ...\n"
  if [[ $(htyIntVersion ${GCCVER}) -ge $(htyIntVersion "8.1.0") ]]; then
    echo -e "\n *** compiling Python ${VER}${VER_B} with optimizations using GCC ${GCCVER}\n"
    EXTRA_TUNING_OPTIONS="--enable-optimizations" #--disable-test-modules"
    sleep 2
  fi
  if [[ -d ${HPCTOYS_ROOT}/opt/openssl/ssl ]]; then
    export OPENSSL_ROOT=${HPCTOYS_ROOT}/opt/openssl
  fi
  DURL="https://www.python.org/ftp/python/${VER}/Python-${VER}${VER_B}.tar.xz" 
  echo -e "\n *** Installing ${DURL} ...\n"
  curl -OkL ${DURL}
  if [[ -f Python-${VER}${VER_B}.tar.xz ]]; then 
    tar xf Python-${VER}${VER_B}.tar.xz           
    cd Python-${VER}${VER_B}
    OPENSSL_OPTIONS=""
    if [[ -d ${HPCTOYS_ROOT}/opt/openssl/lib ]]; then 
      export LD_LIBRARY_PATH=${LD_LIBRARY_PATH}:${HPCTOYS_ROOT}/opt/openssl/lib
      OPENSSL_OPTIONS="--with-openssl=${OPENSSL_ROOT}"
      htyAddLineToFile '_socket socketmodule.c' Modules/Setup
      htyAddLineToFile 'OPENSSL=${HPCTOYS_ROOT}/opt/openssl' Modules/Setup
      #if [[ -z ${EXTRA_TUNING_OPTIONS} ]]; then
        # this builds statically linked
        htyAddLineToFile '_ssl _ssl.c -I$(OPENSSL)/include -L$(OPENSSL)/lib -l:libssl.a -Wl,--exclude-libs,libssl.a -l:libcrypto.a -Wl,--exclude-libs,libcrypto.a' Modules/Setup
        htyAddLineToFile '_hashlib _hashopenssl.c -I$(OPENSSL)/include -L$(OPENSSL)/lib -l:libcrypto.a -Wl,--exclude-libs,libcrypto.a' Modules/Setup
      #else
        #htyAddLineToFile '_ssl _ssl.c $(OPENSSL_INCLUDES) $(OPENSSL_LDFLAGS) $(OPENSSL_LIBS)' Modules/Setup
        #htyAddLineToFile '_hashlib _hashopenssl.c $(OPENSSL_INCLUDES) $(OPENSSL_LDFLAGS) -lcrypto' Modules/Setup
      #fi
    fi
    #LDFLAGS     linker flags, e.g. -L<lib dir>
    #LIBS        libraries to pass to the linker, e.g. -l<library>
    #CPPFLAGS     -I<include dir>

    #INC="${HPCTOYS_ROOT}/opt/other/include"
    #export LIBS="-lffi -lreadline -lncurses"
    #export LDFLAGS="-L${HPCTOYS_ROOT}/opt/other/lib"
    #export CPPFLAGS="-I${INC} -I${INC}/ncurses -I${INC}/readline"
    ##export CPPFLAGS="-I${HPCTOYS_ROOT}/opt/other/include"
    echoerr "LIBS: ${LIBS}, LDFLAGS: ${LDFLAGS}, CPPFLAGS: ${CPPFLAGS}"
    echoerr "READLINE_LIBS: ${READLINE_LIBS}, READLINE_CFLAGS: ${READLINE_CFLAGS}"
    echoerr "LIBFFI_LIBS: ${LIBFFI_LIBS}, LIBFFI_CFLAGS: ${LIBFFI_CFLAGS}"
    sleep 1
    ./configure --prefix="/tmp/hpctoys/lpython" \
         --libdir="${HPCTOYS_ROOT}/opt/other/lib" \
	 --includedir="${HPCTOYS_ROOT}/opt/other/include" \
         ${OPENSSL_OPTIONS} ${EXTRA_TUNING_OPTIONS} 2>&1 | tee configure.output
    sleep 3
    # move PYTHONUSERBASE from ~/.local to a shared location under HPCTOYS_ROOT
    SEA='    return joinuser("~", ".local")'
    REP='    return os.path.join(os.environ.get("HPCTOYS_ROOT", ""), "opt/python")'
    htyCommentAndReplaceLineInFile "${SEA}" "${REP}" Lib/site.py
    htyCommentAndReplaceLineInFile "${SEA}" "${REP}" Lib/sysconfig.py  
    #exit 1
    make -j ${RUNCPUS} 2>&1 | tee make.output
    rm -rf "${TMPDIR}/hpctoys/lpython"
    make install 2>&1 | tee make.install.output
    if [[ -f ${TMPDIR}/hpctoys/lpython/bin/python${VER::-2} ]]; then
      ### fix permissions so others can overwrite the cache
      chmod -R go+w ${TMPDIR}/hpctoys/lpython 
      ### addional packages install
      "${TMPDIR}/hpctoys/lpython/bin/python${VER::-2}" \
               -m pip install --upgrade pip
      echo -e "\n *** installing additional packages from requirements.txt ...\n"
      "${TMPDIR}/hpctoys/lpython/bin/python${VER::-2}" \
               -m pip install -r ${HPCTOYS_ROOT}/requirements.txt
      cd "${TMPDIR}/hpctoys"
      echo -e "\n *** creating archive lpython-${VER}.tar.xz ...\n"
      tar cfvJ lpython-${VER}.tar.xz ./lpython
      FSIZE=$(stat -c%s lpython-${VER}.tar.xz)
      if [[ (( ${FSIZE} -gt 50000000 )) ]]; then     
        echo -e "\n *** copying archive ...\n"
        mv -vf lpython-${VER}.tar.xz ${HPCTOYS_ROOT}/opt/
        #ln -sf "${TMPDIR}/hpctoys/lpython/bin/python${VER::-2}" "${HPCTOYS_ROOT}/bin/python${VER::-2}"
        ### addional packages in ${HPCTOYS_ROOT}/opt/python
        lpip install -r ${HPCTOYS_ROOT}/requirements_opt.txt        
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
##################### setting default config  ####################################
idefaults_group() {
# default settings for all users who share this HPC Toys install

  # a group administrator can activate custom.env
  if [[ -f ${HPCTOYS_ROOT}/custom.env ]]; then
    . ${HPCTOYS_ROOT}/custom.env
  fi

  # if spack exists, configure it for the group
  if [[ -d ${SPACK_ROOT} ]]; then
    . ${SPACK_ROOT}/share/spack/setup-env.sh
    if ! [[ -f ${HPCTOYS_ROOT}/etc/hpctoys/spack_lmod_bash ]]; then
       printf "configure Spack environment ... "
       echo "${SPACK_ROOT}" > \
              ${HPCTOYS_ROOT}/etc/hpctoys/spack_root

       echo "$(spack location -i lmod)/lmod/lmod/init/bash" > \
              ${HPCTOYS_ROOT}/etc/hpctoys/spack_lmod_bash
       echo "Done!"
    fi
    . $(cat ${HPCTOYS_ROOT}/etc/hpctoys/spack_lmod_bash)
  fi
  
}

idefaults_user() {
# default settings for the current user

if [[ -f ~/.profile ]]; then
  PROF=~/.profile
  MYRC=~/.bashrc
  if [[ -f ~/.zshrc ]]; then
    MYRC=~/.zshrc
  fi
elif [[ -f ~/.bash_profile ]]; then
  PROF=~/.bash_profile
  MYRC=~/.bashrc
else
  PROF=~/.profile_hpctoys_template
  MYRC=~/.bashrc_hpctoys_template
  echo "No profile exists, using ${PROF} for now !"
fi

# initialize HPC Toys variables and paths for non-login shell (batch mode)
htyAddLineToFile "test -d ${HPCTOYS_ROOT} && source ${HPCTOYS_ROOT}/etc/profile.d/zzz-hpctoys.sh" ${MYRC}

# replace dark blue color in vim and dir list
COL=$(dircolors)
NEWCOL=${COL/di=01;34/di=01;36}
eval ${NEWCOL}
echo ${NEWCOL} > "${HPCTOYS_ROOT}/etc/hpctoys/dircolors"
if ! [[ -f ~/.vimrc ]]; then
  echo -e "syntax on\ncolorscheme desert" > ~/.vimrc
fi

# Midnight Commander defaults
if ! [[ -d ~/.config/mc ]]; then
  mkdir -p ~/.config/mc
  echo "[Midnight-Commander]" > ~/.config/mc/ini
  printf "skin=darkfar" >> ~/.config/mc/ini
fi

# git defaults 
if [[ -z $(git config --global pull.rebase) ]]; then
  git config --global pull.rebase false
fi
if [[ -z $(git config --global push.default) ]]; then
  git config --global push.default simple
fi
DEFBRANCH=$(git config --global init.defaultBranch)
if [[ -z "${DEFBRANCH}" ]] || [[ "${DEFBRANCH}" == "master" ]]; then
  git config --global init.defaultBranch main
fi

}


########### settings requiring user input ##################################  

iquestions_user() {

#Examples:
#https://www.geeksforgeeks.org/creating-dialog-boxes-with-the-dialog-tool-in-linux/

# QST should not be more than 50 chars wide

QST=$(cat << EOF
*** Welcome to the HPC Toys installer. ***

For a good configuration you need to answer a
few questions. Please hit cancel or ESC if you
would like to skip this step for now. 

Hit OK to continue (default)
EOF
)

dialog --pause "${QST}" 15 50 30
[[ $? -ne 0 ]] && return 1


# #####  Setting up ssh keys 
QST=$(cat << EOF
No public SSH keys were found in folder ~/.ssh
You will now be asked for a passphrase for a new ssh 
key pair. You will need this for many services such 
as Github.com and other cloud services. You will not
have to re-enter this passphrase at login, except  
after this computer has been restarted. 
Please do not use your enterprise password NOR ENTER
AN EMPTY PASSPHRASE UNDER ANY CIRCUMSTANCES.
EOF
)

# available ssh keys and default keys
KEYS=$(htyFilesPlain ~/.ssh "*.pub")
#htyEcho "KEYS1: ${KEYS}" 0
SELKEYS=""
[[ "${KEYS}" == "id_ecdsa.pub" ]] && KEYS="" # don't use Bright CM key
if [[ -z ${KEYS} ]]; then
  dialog --msgbox  "${QST}" 0 0
  ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519
  htyAddLineToFile 'eval $(keychain --quiet --eval id_ed25519)' ${PROF}
  KEYS="id_ed25519.pub"
fi 

if [[ $(wc -w <<< ${KEYS}) -gt 1 ]]; then
  if htyIsItemInList "id_ed25519.pub" "${KEYS}"; then
    SELKEYS="id_ed25519.pub"
  elif htyIsItemInList "id_rsa.pub" "${KEYS}"; then
    SELKEYS="id_rsa.pub"
  fi
fi
#htyEcho "KEYS2: ${KEYS}" 0

# ask which keys should be loaded in keychain/ssh-agent
QST=$(cat << EOF
Which of your ssh public keys should be
loaded into your keychain and ssh-agent
when you login? By default only the marked
key is loaded. Please confirm.
EOF
)
if [[ $(wc -w <<< ${KEYS}) -gt 1 ]]; then
  htyDialogChecklist "${QST}" "${KEYS}" "${SELKEYS}"
  KEYS="${RES}" 
elif [[ $(wc -w <<< ${KEYS}) -eq 0 ]]; then
  dialog --msgbox  "No *.pub keys found in ~/.ssh folder. " 0 0
fi
echo ${KEYS} > ~/.config/hpctoys/load_sshkeys
#htyEcho "KEYS3: ${KEYS}" 0

# clean up existing profile from ssh-agent and keychain
sed -i '/^eval `ssh-agent*/d' ${PROF} 
sed -i '/^eval $(ssh-agent*/d' ${PROF}
sed -i '/^eval $(keychain*/d' ${PROF}
echo "eval \$(keychain --quiet --eval ${KEYS//.pub/})" >> ${PROF}

# add each selected key to authorized_keys if not already added
touch ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
#htyEcho "KEYS4: ${KEYS}" 0
for K in ${KEYS}; do
  #htyEcho "K $K" 0
  PK=$(cat ~/.ssh/$K)
  #htyEcho "PK $PK" 0
  if ! grep -q "${PK}" ~/.ssh/authorized_keys; then
    echo "${PK}" >> ~/.ssh/authorized_keys
  fi
done


# #### Github Metadata

# git user.name
QST=$(cat << EOF
Now we need to setup git which is an essential 
tool for every person who writes code. Please 
enter your first and last name or confirm the 
default setting. 
EOF
)
RES=""
if htyDialogInputbox "${QST}" \
      "$(git config --global user.name)" \
      "Enter your first and last name" ; then
  git config --global user.name "${RES}"
else
  exit
fi


# git user.email
QST=$(cat << EOF
Please enter or confirm the email address that git 
uses for tracking when storing a new version of 
your code. 
This will be your work email address in most 
cases. 
EOF
)
RES=""
if htyDialogInputbox "${QST}" \
       "$(git config --global user.email)" \
       "Enter your eMail address"; then
  git config --global user.email "${RES}"
else
  exit
fi


# github.com login user
QST=$(cat << EOF
Please enter or confirm your Github.com login user 
name. If you do not have a Github.com account yet, 
please create one. HOW SELECT A GOOD LOGIN NAME ? 
* Your github login name should be simple and easy 
  to memorize as it is part of the github URL and 
  others can use it to share their code with you. 
* Use only ONE Github login and not one for each 
  organization you work for. Github has enterprise 
  products that can link your Github login name to 
  the enterprise user id of your organization. 
* Ideally you keep your ONE Github id for your 
  entire career to ensure that ALL your 
  contributions are recognized. 
Go to https://github.com/join [e.g. Ctrl+Click] 
NOW and create your github login which will take 
about two minutes. Once you have a new login name, 
come back here and enter it below. 
EOF
)
if htyDialogInputbox "${QST}" \
        "$(htyReadConfigOrDefault github_login)" \
	"Enter your Gihub login name"; then 
  echo "${RES}" > ~/.config/hpctoys/github_login
  GHL=$(cat ~/.config/hpctoys/github_login)
  echoerr " connecting to github.com/${GHL} ..."
  GHJSON=$(curl -sL https://api.github.com/users/${GHL})
  GHID=$(echo ${GHJSON} | jq -r '.id')
  GHLOG=$(echo ${GHJSON} | jq -r '.login')
  GHNAM=$(echo ${GHJSON} | jq -r '.name')
  GHORG=$(echo ${GHJSON} | jq -r '.company')
  GHLOC=$(echo ${GHJSON} | jq -r '.location')
  GHUPD=$(echo ${GHJSON} | jq -r '.updated_at')

  # verify Github Metadata 
QST=$(cat << EOF
${GHLOG}, you are the ${GHID}th Github.com 
user and you should have these 3 fields filled 
out in your public Github profile: 

 Your Full Name:  ${GHNAM} 
   Organization:  ${GHORG} 
       Location:  ${GHLOC} 

If any of this information is 'null' please go 
back to https://github.com/settings/profile 
[Ctrl+Click] and update your profile. 
[last updated: ${GHUPD}]
EOF
)
  if [[ "${GHID}" == "null" ]]; then
    QST="Github user ${GHL} does not exist."
  fi
  dialog --msgbox  "${QST}" 0 0
else
  exit
fi


# check key that should be uploaded to github
QST=$(cat << EOF
Which ssh public key would you like
to use to authenticate with Github? 
Please select one public key. Likely 
you will just need to confirm if one 
is already pre-selected for you.
EOF
)
SELKEYS="$(htyReadConfigOrDefault load_sshkeys)"
if [[ $(wc -w <<< ${KEYS}) -gt 1 ]]; then
  htyDialogChecklist "${QST}" "${KEYS}" "${SELKEYS}" \
          "SSH key for Github?"
elif [[ $(wc -w <<< ${KEYS}) -eq 1 ]]; then
  RES=${KEYS}
else
  dialog --msgbox  "No *.pub keys found in ~/.ssh folder. " 0 0
fi
echo ${RES} > ~/.config/hpctoys/github_sshkey

echo "Please mark and copy the key (text) between the "
echo "two -SNIP- lines, paste it at the Github page "
echo "https://github.com/settings/ssh/new (Ctrl+Click) " 
echo "in the 'Key' field and enter a description for "
echo "this key in the 'Title' field. " 
echo ""
echo "------------SNIP-------------------------"
i=0
for R in ${RES}; do
  [[ $i -gt 0 ]] && echo "-----"
  cat ~/.ssh/${R}
  let "i++"
done
i=0
echo "------------SNIP-------------------------"
read -n 1 -r -s -p $'\n Press enter to continue...\n'
}

cd ${CURRDIR}
if [[ -z ${SUBCMD} ]]; then
  # Run all installations or comment out
  ipackages
  iother
  idialog
  ijq
  iyq
  ikeychain
  imc
  irclone
  igithub
  # disabling openssl, python and awscli2
  #iopenssl
  #ilpython
  #iawscli2
  iminiconda
  PATH=${PATH}:${HPCTOYS_ROOT}/bin
  idefaults_group
  idefaults_user
  if [[ -z ${ERRLIST} ]]; then
    iquestions_user
  fi
elif [[ ${SUBCMD} =~ ^(other|jq|yq|keychain|dialog|github|awscli2|openssl|\
     mc|rclone|miniconda|lpython|defaults_group|defaults_user|questions_user)$ ]]; then
  i${SUBCMD} "$@"
else
  echo "Invalid subcommand: ${SUBCMD}" >&2
  help
  exit 1
fi

# cleanup
if [[ -z ${ERRLIST} ]]; then
  rm -rf ${INTMP}
  echoerr " HPC Toys installed ! "
  echoerr " Please logout/login or run this command:"
  echoerr " source ${PROF}"
  touch ${HPCTOYS_ROOT}/etc/hpctoys/install_success
else
  echoerr "Errors in these installations: ${ERRLIST}"
  echoerr "Check ${INTMP} for troubleshooting"
  rm -f ${HPCTOYS_ROOT}/etc/hpctoys/install_success
fi
cd ${CURRDIR}

