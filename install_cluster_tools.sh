#!/bin/bash

# This script
# - installs and sets up miniconda (unless `conda` is in the PATH)
# - clones and pip-installs latest master of stormdb-python (incl. submit_to_cluster)
# - optionally also installs the latest stable mne-python using their (master) environment.yml

# back up bashrc!
bakdate=`date +"%y%m%d%H%M%S"`
touch ~/.bashrc && cp ~/.bashrc ~/.bashrc_bak${bakdate}

# if personal (mini)conda NOT already present:
TMPDIR=`mktemp -d` || exit 1
echo ${TMPDIR}

cd ${TMPDIR}
# type conda >/dev/null 2>&1 || { echo >&2 "conda not in path, installing now..."; }
if type conda &>/dev/null ; then
    conda_exe=`which conda`
    echo "Seems like conda is already installed in your path, great!";
    echo "Using: ${conda_exe}";
else 
    wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh
    sh Miniconda3-latest-Linux-x86_64.sh -b

    # these set up the required path etc for rest of script to function!
    __conda_setup=$(~/miniconda3/bin/conda shell.bash hook)
    if [[ -z ${__conda_setup// } ]]; then
        echo 'Something went wrong with miniconda installation, contact administrators!'
        echo 'Give them the following information: bash hook failed (__conda_setup)'
        exit 1;
    fi
    eval "$__conda_setup"
    # modifies .bashrc
    conda init
fi

# install python version relevant to mne-python (just in case it's also wanted)
curl -O https://raw.githubusercontent.com/mne-tools/mne-python/master/environment.yml
pyversion=$(grep "\- python*" environment.yml | head -1 | sed 's/-\s*//')
conda create -y -n cluster $pyversion pip six requests
if [ $? -ne 0 ] ; then
    echo "Creating conda environment failed, please contact administrator!"
    exit 1;
fi
conda activate cluster || exit 1

# make permanent: most users will be happy, power users can modify
echo -e 'conda activate cluster' >> ~/.bashrc

# get the latest master of cluster API
git clone https://github.com/meeg-cfin/stormdb-python.git
pip install ./stormdb-python && echo "Utility function submit_to_cluster successfully installed!"

# ask whether mne-python (pip version) should also be installed
read -p 'Install current stable version of mne-python? [y/N] ' INS_MNE
case "${INS_MNE}" in
    y|Y) conda env update -n cluster -f environment.yml;;
    *) echo "Skipping mne-python installation";;
esac
cd - && rm -rf ${TMPDIR}

echo ""
echo "Installation complete."
echo "Please close this terminal window and start a new one before proceeding!"
