#! /bin/bash

if ! [[ -f etc/profile.d/zzz-users.sh ]]; then 
  echo "You need to switch to the root 
    of the Hpctoys Git repos before running this script."
  exit
fi
. etc/profile.d/zzz-users.sh
CURRDIR=$(pwd)

if [[ -f ~/.profile ]]; then
  PROF=~/.profile
elif [[ -f ~/.bash_profile ]]; then
  PROF=~/.bash_profile
else
  PROF=~/.profile_hpctoys_template
  echo "No profile exists, using ${PROF} for now !"
fi

# Midnight Commander defaults
if ! [[ -d ~/.config/mc ]]; then
  mkdir -p ~/.config/mc
  echo "[Midnight-Commander]" > ~/.config/mc/ini
  printf "skin=darkfar" >> ~/.config/mc/ini
fi

# Keychain defaults 
addLineToFile 'eval $(keychain --eval id_rsa)' ${PROF}

