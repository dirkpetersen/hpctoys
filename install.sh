#! /bin/bash

CURRDIR=$(pwd)
if [[ -f ${BASH_SOURCE} ]]; then
  cd $(dirname "$(realpath "${BASH_SOURCE}")")
else
  echo 'Your shell does not support ${BASH_SOURCE}. Please use "bash" to setup hpctoys.'
  exit
fi
if ! [[ -f etc/profile.d/zzz-users.sh ]]; then 
  echo "You need to switch to the root 
    of the Hpctoys Git repos before running this script."
  exit
fi
. etc/profile.d/zzz-users.sh
MYTMP=$(mktemp -d "${TMPDIR}/hpctoys.XXXXX")
SCR=${0##*/}
SUBCMD=$1
ERRLIST=""
export DIALOGRC=${HPCTOYS_ROOT}/etc/.dialogrc
RUNCPUS=4
[[ -n ${SLURM_CPUS_ON_NODE} ]] && RUNCPUS=$((${SLURM_CPUS_ON_NODE}*2))

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

echoerr "\n *** Preparing Installation of HPC Toys ***"
echoerr " *** Waiting for 3 sec *** ..."
read -t 3 -n 1 -r -s -p $' (Press any key to cancel the setup)\n'
if [[ $? -eq 0 ]]; then
  echoerr " Setup interrupted, exiting ...\n"
  exit
fi


# installing generic (other) dependencies 
iother() {

  # optionally install any version of ncurses
  NCURSESOPT=''
  if [[ -z $(pkg-config --silence-errors --modversion ncurses) ]]; then
    VER="6.3"
    if [[ ! -f ${HPCTOYS_ROOT}/opt/other/lib/libncurses.a ]]; then
      echoerr "\n * Installing 'ncurses' lib for 'dialog' ... *\n"
      cd ${MYTMP}
      DURL="https://ftp.gnu.org/pub/gnu/ncurses/ncurses-${VER}.tar.gz"
      curl -OkL ${DURL}
      if [[ -f ncurses-${VER}.tar.gz ]]; then
	tar xf ncurses-${VER}.tar.gz
	cd ncurses-${VER}
	./configure --prefix=${HPCTOYS_ROOT}/opt/other
	make -j ${RUNCPUS}
	make install
	if [[ -f ${HPCTOYS_ROOT}/opt/other/bin/ncurses6-config ]]; then
	  ln -sfr ${HPCTOYS_ROOT}/opt/other/bin/ncurses6-config \
		      ${HPCTOYS_ROOT}/bin/ncurses6-config
	  NCURSESOPT="--with-curses-dir=${HPCTOYS_ROOT}/opt/other"
	else
	  ERRLIST+=" Ncurses"
	fi
      else
	echo "unable to download ${DURL}, exiting !"
	ERRLIST+=" Ncurses"
      fi
    fi
  fi

  # optionally install libffi >= 3.0.0
  CURRVER=$(pkg-config --silence-errors --modversion libffi)
  if [[ $(intVersion ${CURRVER}) -lt $(intVersion "3.0.0") ]]; then
    VER="3.4.2"
    if [[ ! -f ${HPCTOYS_ROOT}/opt/other/lib/libffi.a ]]; then
      echoerr "\n * Installing 'libffi for mc and python' ${VER} ... *\n"
      cd ${MYTMP}
      DURL="https://github.com/libffi/libffi/releases/download/v${VER}/libffi-${VER}.tar.gz"
      echo -e "\n *** Installing ${DURL} ...\n"
      curl -OkL ${DURL}
      if [[ -f libffi-${VER}.tar.gz ]]; then
	tar xf libffi-${VER}.tar.gz
	cd libffi-${VER}
	./configure --prefix ${HPCTOYS_ROOT}/opt/other
	#static & dynamic: make && make check && make install-all
	#make static
	#make install-static
	make -j ${RUNCPUS}
	make install
	[[ "$?" -ne 0 ]] && ERRLIST+=" libffi"
	export LIBFFI_LIBS="-L${HPCTOYS_ROOT}/opt/other/lib -lffi"
	export LIBFFI_CFLAGS="-I${HPCTOYS_ROOT}/opt/other/include"
      fi
    fi
  fi


  # optionally install readline >= 3.0.0
  CURRVER=$(pkg-config --silence-errors --modversion readline)
  if [[ $(intVersion ${CURRVER}) -lt $(intVersion "3.0.0") ]]; then
    VER="8.1"
    if [[ ! -f ${HPCTOYS_ROOT}/opt/other/lib/libreadline.a ]]; then
      echoerr "\n * Installing 'readline for python' ${VER} ... *\n"
      cd ${MYTMP}
      DURL="https://ftp.gnu.org/gnu/readline/readline-${VER}.tar.gz"
      echo -e "\n *** Installing ${DURL} ...\n"
      curl -OkL ${DURL}
      if [[ -f readline-${VER}.tar.gz ]]; then
	tar xf readline-${VER}.tar.gz
	cd readline-${VER}
	./configure --prefix ${HPCTOYS_ROOT}/opt/other
	#static & dynamic: make && make check && make install-all
	#make static
	#make install-static
	make -j ${RUNCPUS}
	make install
	[[ "$?" -ne 0 ]] && ERRLIST+=" readline"
	export READLINE_LIBS="-L${HPCTOYS_ROOT}/opt/other/lib -lreadline"
	export READLINE_CFLAGS="-I${HPCTOYS_ROOT}/opt/other/include"
      fi
    fi
  fi
}


# installing dialog util for ncurses GUI
idialog() {
if ! inpath 'dialog'; then
  echoerr "\n * Installing 'dialog' ... *\n"
  cd ${MYTMP}
  DURL="https://invisible-island.net/datafiles/release/dialog.tar.gz"
  curl -OkL ${DURL}
  if [[ -f dialog.tar.gz ]]; then
    tar xf dialog.tar.gz
    cd dialog-*
    ./configure --prefix ${HPCTOYS_ROOT}/opt/dialog ${NCURSESOPT}
    make -j ${RUNCPUS}
    make install
    if [[ -f ${HPCTOYS_ROOT}/opt/dialog/bin/dialog ]]; then
      ln -sfr ${HPCTOYS_ROOT}/opt/dialog/bin/dialog ${HPCTOYS_ROOT}/bin/dialog
    else
      ERRLIST+=" Dialog"
    fi
  else
    echo "unable to download ${DURL}, exiting !"
    ERRLIST+=" Dialog"
  fi
  cd ${CURRDIR}
fi
}

# installing jq, the json processor 
ijq() {
if ! inpath 'jq'; then
  VER="1.6"
  echoerr "\n * Installing 'jq' ${VER} ... *\n"
  DURL="https://github.com/stedolan/jq/releases/download/jq-${VER}/jq-linux64"
  curl -kL ${DURL} -o ${HPCTOYS_ROOT}/opt/other/bin/jq
  chmod +x ${HPCTOYS_ROOT}/opt/other/bin/jq
  ln -sfr ${HPCTOYS_ROOT}/opt/other/bin/jq ${HPCTOYS_ROOT}/bin/jq
fi
}

# installing yq, the yaml processor
iyq() {
if ! inpath 'yq'; then
  VER=4.25.3
  echoerr "\n * Installing 'yq' ${VER} ... *\n"
  DURL="https://github.com/mikefarah/yq/releases/download/v${VER}/yq_linux_amd64"
  curl -kL ${DURL} -o ${HPCTOYS_ROOT}/opt/other/bin/yq
  chmod +x ${HPCTOYS_ROOT}/opt/other/bin/yq
  ln -sfr ${HPCTOYS_ROOT}/opt/other/bin/yq ${HPCTOYS_ROOT}/bin/yq
fi
}

# Keychain
ikeychain() {
if ! inpath 'keychain'; then
  VER="2.8.5"
  echoerr "\n * Installing 'keychain' ${VER} ... *\n"
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

# Github CLI
igithub() {
if ! inpath 'gh'; then
  VER="2.13.0"
  echoerr "\n * Installing 'github cli' ${VER} ... *\n"
  cd ${MYTMP}
  DURL="https://github.com/cli/cli/releases/download/v${VER}/gh_${VER}_linux_amd64.tar.gz"
  curl -OkL ${DURL}
  if [[ -f gh_${VER}_linux_amd64.tar.gz ]]; then
    tar xf gh_${VER}_linux_amd64.tar.gz
    cd gh_${VER}_linux_amd64
    #echo $MYTMP
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


# Midnight Commander 
imc() {
if ! [[ -f "${HPCTOYS_ROOT}/opt/mc/bin/mc" ]]; then
#if ! inpath 'mc'; then
  #export LD_LIBRARY_PATH=${HPCTOYS_ROOT}/opt/mc/lib:${LD_LIBRARY_PATH}
  export GLIB_LIBS="-L${HPCTOYS_ROOT}/opt/mc/lib -lglib-2.0" 
  export GLIB_CFLAGS="-I${HPCTOYS_ROOT}/opt/mc/include/glib-2.0"
         GLIB_CFLAGS+=" -I${HPCTOYS_ROOT}/opt/mc/lib/glib-2.0/include"
  #export PCRE_LIBS="-L${HPCTOYS_ROOT}/opt/mc/lib -lpcre"
  #export PCRE_CFLAGS="-IL${HPCTOYS_ROOT}/opt/mc/include"

  # currently disabled --- optionally install libpcre >= 8.13
  CURRVER="8.45"  #$(pkg-config --silence-errors --modversion libpcre)
  if [[ $(intVersion ${CURRVER}) -lt $(intVersion "8.13") ]]; then
    VER="8.45"
    echoerr "\n * Installing 'pcre for mc' ${VER} ... *\n"
    cd ${MYTMP}
    DURL="https://sourceforge.net/projects/pcre/files/pcre/${VER}/pcre-${VER}.tar.bz2"
    echo -e "\n *** Installing ${DURL} ...\n"
    curl -OkL ${DURL}
    if [[ -f pcre-${VER}.tar.bz2 ]]; then
      tar xf pcre-${VER}.tar.bz2
      cd pcre-${VER}
      ./configure --prefix ${HPCTOYS_ROOT}/opt/mc \
                  --enable-unicode-properties
      #static & dynamic: make && make check && make install-all
      #make static
      #make install-static
      make -j ${RUNCPUS}
      make install
      [[ "$?" -ne 0 ]] && ERRLIST+=" pcre"
    fi
  fi

  # optionally install glib-2 >= 2.30
  CURRVER=$(pkg-config --silence-errors --modversion glib-2.0)
  if [[ $(intVersion ${CURRVER}) -lt $(intVersion "2.30") ]]; then
    VER="2.56"
    echoerr "\n * Installing 'glib-2.0 for mc' ${VER} ... *\n"
    sleep 1
    cd ${MYTMP}
    DURL="https://download.gnome.org/sources/glib/${VER}/glib-${VER}.0.tar.xz"
    echo -e "\n *** Installing ${DURL} ...\n"
    curl -OkL ${DURL} 
    if [[ -f glib-${VER}.0.tar.xz ]]; then
      tar xf glib-${VER}.0.tar.xz
      cd glib-${VER}.0
      ./configure --prefix ${HPCTOYS_ROOT}/opt/mc \
             --disable-libmount --disable-selinux  --with-pcre=internal
      #static & dynamic: make && make check && make install-all
      #make static
      #make install-static
      make -j ${RUNCPUS}
      make install
      # shown an error even though it installs correctly 
      #[[ "$?" -ne 0 ]] && ERRLIST+=" glib-2.0"
    fi
  fi

  # install s-lang dependency
  VER="2.3.2"
  echoerr "\n * Installing 'slang for mc' ${VER} ... *\n"
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
    [[ "$?" -ne 0 ]] && ERRLIST+=" s-lang"
  fi
  # then install MC
  VER="4.8.26" # .27 and .28 fail with s-lang compile errors
  echoerr "\n * Installing 'mc' ${VER} ... *\n"
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
    make -j ${RUNCPUS}
    make install
    if [[ "$?" -ne 0 ]]; then 
      ERRLIST+=" Midnight-Commander"
    else
      ln -sfr ${HPCTOYS_ROOT}/opt/mc/bin/mc ${HPCTOYS_ROOT}/bin/mc
    fi
  else 
    echo "unable to download ${DURL}, exiting !"
    ERRLIST+=" Midnight-Commander"
  fi
  cd ${CURRDIR}
fi
}

# Rclone 
irclone() {
if ! [[ -d "${HPCTOYS_ROOT}/opt/rclone" ]]; then
  echoerr "\n * Installing 'rclone' ... *\n"
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
iminiconda() {
if ! [[ -d "${HPCTOYS_ROOT}/opt/miniconda" ]]; then
  echoerr "\n * Installing 'miniconda' ... *\n"
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

# OpenSSL needed for lpython
iopenssl() {
SSLVER=$(pkg-config --silence-errors --modversion openssl)
if [[ $(intVersion ${SSLVER}) -lt $(intVersion "1.1.1") ]]; then
#if ! [[ -d "${HPCTOYS_ROOT}/opt/openssl" ]]; then
  VER="1_1_1p"
  echoerr "\n * Installing 'openssl' ${VER} ... *\n"
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
  export OPENSSL_ROOT=${HPCTOYS_ROOT}/opt/openssl
  cd ${CURRDIR}
fi
}


# a special Python for a user group that is optimzed and locally cached. 
ilpython() {
VER="3.10.5"
VER_B="" # beta ver such as b1, b2 or b3
cd ${MYTMP}
if ! [[ -f "${HPCTOYS_ROOT}/opt/lpython-${VER}.tar.xz" ]]; then
  echoerr "\n * Installing 'lpython' ${VER}${VER_B} ... *\n"
  #loadLmod gcc
  #libffi sqlite ncurses readline libreadline
  GCCVER=$(gcc -dumpfullversion)
  #echo -e "\n Using GCC ${GCCVER} ...\n"
  if [[ $(intVersion ${GCCVER}) -ge $(intVersion "8.1.0") ]]; then
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
      addLineToFile '_socket socketmodule.c' Modules/Setup
      addLineToFile 'OPENSSL=${HPCTOYS_ROOT}/opt/openssl' Modules/Setup
      #if [[ -z ${EXTRA_TUNING_OPTIONS} ]]; then
        # this builds statically linked
        addLineToFile '_ssl _ssl.c -I$(OPENSSL)/include -L$(OPENSSL)/lib -l:libssl.a -Wl,--exclude-libs,libssl.a -l:libcrypto.a -Wl,--exclude-libs,libcrypto.a' Modules/Setup
        addLineToFile '_hashlib _hashopenssl.c -I$(OPENSSL)/include -L$(OPENSSL)/lib -l:libcrypto.a -Wl,--exclude-libs,libcrypto.a' Modules/Setup
      #else
        #addLineToFile '_ssl _ssl.c $(OPENSSL_INCLUDES) $(OPENSSL_LDFLAGS) $(OPENSSL_LIBS)' Modules/Setup
        #addLineToFile '_hashlib _hashopenssl.c $(OPENSSL_INCLUDES) $(OPENSSL_LDFLAGS) -lcrypto' Modules/Setup
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
    #echoerr "LIBS: ${LIBS}, LDFLAGS: ${LDFLAGS}, CPPFLAGS: ${CPPFLAGS}"
    sleep 5
    ./configure --prefix="/tmp/hpctoys/lpython" \
         --libdir="${HPCTOYS_ROOT}/opt/other/lib" \
	 --includedir="${HPCTOYS_ROOT}/opt/other/include" \
         ${OPENSSL_OPTIONS} ${EXTRA_TUNING_OPTIONS} 2>&1 | tee configure.output
    # move PYTHONUSERBASE from ~/.local to a shared location under HPCTOYS_ROOT
    SEA='    return joinuser("~", ".local")'
    REP='    return os.path.join(os.environ.get("HPCTOYS_ROOT", ""), "opt/python")'
    replaceCommentLineInFile "${SEA}" "${REP}" Lib/site.py
    replaceCommentLineInFile "${SEA}" "${REP}" Lib/sysconfig.py  
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
addLineToFile ". ${HPCTOYS_ROOT}/etc/profile.d/zzz-users.sh" ${MYRC}

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

}


########### settings requiring user input ##################################  

_filesPlain() {
MSG="${FUNCNAME[0]} <folder> <file-or-wildcard>"
[[ -z $1 ]] && echo ${MSG} && return 1
if [[ -z $2 ]]; then
  ls -1 $1
else
  CD=$(pwd)
  cd $1
  ls -1 $2
  cd ${CD}
fi
}

_isItemInList() {
MSG="${FUNCNAME[0]} <item> <list of items>"
[[ -z $2 ]] && echo ${MSG} && return 1
for X in $2; do
  [[ "$1" == "$X" ]] && return 0
done
return 1
}

_inputbox() {
#read -n 1 -r -s -p $"\n $1 $2 $3 Press enter to continue...\n"
MSG="${FUNCNAME[0]} <message> <default-value>"
[[ -z $2 ]] && echo ${MSG} && return 1
RES="" 
while [[ "$RES" == "" ]]; do 
  RES=$(dialog --inputbox "$1" 0 0 "$2" 2>&1 1>/dev/tty)
  RET=$?
  #echo $RET:$RES && sleep 3
  if [[ $RET -ne 0 ]]; then
    clear
    echoerr "\n Setup canceled, exiting ...\n"
    exit
  fi
done
clear

}

_checklist() {
# read -n 1 -r -s -p $"\n  $1 $2 $3 Press enter to continue...\n"
MSG="${FUNCNAME[0]} <message> <list-of-options> <selected-options>"
[[ -z $2 ]] && echo ${MSG} && return 1
OPT=""
RES=""
i=0
for E in $2; do 
  let i++
  if [[ " $3 " =~ .*\ ${E}\ .* ]]; then
    OPT+="$E $i on "
  else 
    OPT+="$E $i off "
  fi  
done
while [[ "$RES" == "" ]]; do
  RES=$(dialog --checklist "$1" 0 0 0 ${OPT} 2>&1 1>/dev/tty) 
  RET=$?
  #echo $RET:$RES && sleep 3
  if [[ $RET -ne 0 ]]; then
    clear
    echoerr "\n Setup canceled, exiting ...\n"
    exit
  fi
done
clear
}

iquestions_user() {

#Examples:
#https://www.geeksforgeeks.org/creating-dialog-boxes-with-the-dialog-tool-in-linux/

# QST should not be more than 50 chars wide

# verify Github Metadata
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
KEYS=$(_filesPlain ~/.ssh "*.pub")
SELKEYS=""
if [[ -z ${KEYS} ]]; then
  dialog --msgbox  "${QST}" 0 0
  ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519
  addLineToFile 'eval $(keychain --eval id_ed25519)' ${PROF}
  KEYS="id_ed25519.pub"
fi 

if [[ $(wc -w <<< ${KEYS}) -gt 1 ]]; then
  if _isItemInList "id_ed25519.pub" "${KEYS}"; then
    SELKEYS="id_ed25519.pub"
  elif _isItemInList "id_rsa.pub" "${KEYS}"; then
    SELKEYS="id_rsa.pub"
  fi
fi

# ask which keys should be loaded in keychain/ssh-agent
QST=$(cat << EOF
Which of your ssh public keys should be
loaded into your keychain and ssh-agent
when you login? By default only the marked
key is loaded. Please confirm.
EOF
)
if [[ $(wc -w <<< ${KEYS}) -gt 1 ]]; then
  _checklist "${QST}" "${KEYS}" "${SELKEYS}"
elif [[ $(wc -w <<< ${KEYS}) -eq 1 ]]; then
  RES=$KEYS
else
  dialog --msgbox  "No *.pub keys found in ~/.ssh folder. " 0 0
fi
echo ${RES} > ~/.config/hpctoys/load_sshkeys

# clean up existing profile from ssh-agent and keychain
sed -i '/^eval `ssh-agent*/d' ${PROF} 
sed -i '/^eval $(ssh-agent*/d' ${PROF}
sed -i '/^eval $(keychain*/d' ${PROF}
echo "eval \$(keychain --eval ${RES//.pub/})" >> ${PROF}

# add each selected key to authorized_keys if not already added
touch ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
for K in ${RES}; do
  PK=$(cat .ssh/$K)
  if ! grep -q "${PK}" ~/.ssh/authorized_keys; then
    echo "${PK}" >> ~/.ssh/authorized_keys
  fi
done

# git user.name
QST=$(cat << EOF
Now we need to setup git which is an essential 
tool for every person who writes code. Please 
enter your first and last name or confirm the 
default setting. 
EOF
)
_inputbox "${QST}" "$(git config --global user.name)"
git config --global user.name "${RES}"


# git user.email
QST=$(cat << EOF
Please enter or confirm the email address that git 
uses for tracking when storing a new version of 
your code. 
This will be your work email address in most 
cases. 
EOF
)
_inputbox "${QST}" "$(git config --global user.email)"
git config --global user.email "${RES}"


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
_inputbox "${QST}" "$(readConfigOrDefault github_login)"
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

If any of this information is missing please go 
back to https://github.com/settings/profile 
[Ctrl+Click] and update your profile. 
[last updated: ${GHUPD}]
EOF
)
if [[ "${GHID}" == "null" ]]; then
  QST="Github user ${GHL} does not exist."
fi
dialog --msgbox  "${QST}" 0 0

# check key that should be uploaded to github
QST=$(cat << EOF
Which ssh public key would you like
to use to authenticate with Github? 
Please select one public key. Likely 
you will just need to confirm if one 
is already pre-selected for you.
EOF
)
if [[ $(wc -w <<< ${KEYS}) -gt 1 ]]; then
  _checklist "${QST}" "${KEYS}" "${SELKEYS}"
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
echo "------------SNIP-------------------------"
cat ~/.ssh/${RES}
echo "------------SNIP-------------------------"
read -n 1 -r -s -p $'\n Press enter to continue...\n'

}

cd ${CURRDIR}
if [[ -z ${SUBCMD} ]]; then
  # Run all installations or comment out
  iother
  ijq
  iyq
  ikeychain
  idialog
  idefaults_group
  idefaults_user
  if [[ -z ${ERRLIST} ]]; then
    iquestions_user
  fi
  igithub
  iawscli2
  iopenssl
  imc
  irclone
  ilpython
  iminiconda
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
  rm -rf ${MYTMP}
  echoerr " HPC Toys installed ! "
  echoerr " Please logout/login or run this command:"
  echoerr " source ${PROF}"
else
  echoerr "Errors in these installations: ${ERRLIST}"
  echoerr "Check ${MYTMP} for troubleshooting"
fi
cd ${CURRDIR}

