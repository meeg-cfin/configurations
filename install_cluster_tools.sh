#!/bin/bash

# check whether something like miniconda already in path?
# echo $PATH | grep conda | wc | awk
# alternatively: see if `conda --version` returns error!
# though beware that it's not coming from /usr/local?

# back up bashrc!
bakdate=`date +"%y%m%d%H%M%S"`
touch ~/.bashrc && cp ~/.bashrc ~/.bashrc_bak${bakdate}

# if personal (mini)conda NOT already present:
TMPDIR=`mktemp -d` || exit 1
echo ${TMPDIR}

cd ${TMPDIR}
# type conda >/dev/null 2>&1 || { echo >&2 "conda not in path, installing now..."; }
if type conda &>/dev/null ; then
    echo 'Seems like conda is already installed in your path, skipping...';
else 
    wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh
    sh Miniconda3-latest-Linux-x86_64.sh
fi

# install python version relevant to mne-python (just in case also wanted)
curl -O https://raw.githubusercontent.com/mne-tools/mne-python/master/environment.yml
pyversion=$(grep "\- python*" environment.yml | head -1 | sed 's/-\s*//')
conda env create -n cluster $pyversion pip six requests
if [ $? -ne 0 ] ; then
    echo 'Creating conda environment failed, please contact administrator!'
    exit 1;
fi
conda activate cluster || exit 1
echo -e 'conda activate cluster' >> ~/.bashrc

# get the latest master of cluster API
git clone https://github.com/meeg-cfin/stormdb-python.git
pip install ./stormdb-python && echo 'Utility function submit_to_cluster successfully installed!'

# ask whether mne-python (pip version) should also be installed
read -p 'Install current stable version of mne-python? [y/N] ' INS_MNE
case "${INS_MNE}" in
    y|Y) conda env update -f environment.yml;;
    *) echo "Skipping mne-python installation";;
esac
#cd - && rm -rf ${TMPDIR}