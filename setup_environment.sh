#!/bin/bash

# This will allow us to call additional scripts relative to the present one
# (from the same dir)
current_dir="$(dirname "$BASH_SOURCE")"
meeg_cfin_dir=$(dirname ${current_dir})
PATH=${meeg_cfin_dir}/stormdb-python/bin:${PATH}

DEFAULT_PS1=${PS1}
DEFAULT_PATH=${PATH}
DEFAULT_LD_LIBRARY_PATH=${LD_LIBRARY_PATH}

export MINDLABPROJ='NA'
export MINDLABENV='not set'

alias ll='ls -l -color'
alias la='ls -la -color'

gotoproj ()
{
    if [ $# -ge 1 ]; then
        set_mindlabproj $1
    fi
    cd /projects/$MINDLABPROJ;
}

short_path ()
{ export PS1="\u@\h: \W> "; }

gitprompt ()
{
    source "$current_dir/bash-colors.sh"
    source "$current_dir/git-prompt.sh"

    export PS1="\[$Green\][\w]\[$Purple\]\$(__git_ps1)\n\[$BCyan\]\u@\[$BYellow\]\h\[\033[1;33m\] \[$White\]\$ \[$Color_Off\]";
}

# change this to provide a list of projects, based on group membership!
set_mindlabproj ()
{
    GRPLIST=(`groups`)
    PROJLIST=()
    for grp in "${GRPLIST[@]}"; do
        if [[ $grp == mindlab_??? ]]; then
            #echo $grp;
            fullpth=`find /projects -maxdepth 1 -group $grp`
            projname=`basename $fullpth`
            ii=$(($ii + 1))
            PROJLIST+=($projname)
        fi
    done
    if [ $# -ge 1 ]; then
        pnum=$1 # if you already know the number...
    else
        echo "------------------"
        echo "Available projects"
        echo "------------------"
        ii=0
        for projname in "${PROJLIST[@]}"; do
            let ii+=1
            echo $ii: $projname
        done
        echo -n "Select project [1-$ii]: "
        read pnum
    fi
    if [ $pnum -gt ${#PROJLIST[@]} ]; then
        echo "Project number too large, what are you trying to do?"
        return 1
    fi
    echo "Environment variable MINDLABPROJ set to ${PROJLIST[$((${pnum} - 1))]}"
    export MINDLABPROJ=${PROJLIST[$(($pnum - 1))]}

    # Try to be a bit smart about a subjects_dir existing, but don't force
    # response from the user if not found (just silently move on)
    SUBJECTS_DIR=$(find /projects/$MINDLABPROJ/scratch/ -maxdepth 1 -type d \
        -name '*subjects_dir*'| head -n1)
    if [[ -d $SUBJECTS_DIR ]]; then
        export SUBJECTS_DIR
        echo "SUBJECTS_DIR set to: $SUBJECTS_DIR"
    else
        unset SUBJECTS_DIR  # since this script is source'd
    fi

}

use ()
{
    if [ $# -lt 1 ]
    then
        echo "Usage: use <environment name>"
        echo "Possible environments are: anaconda(3), cuda, mne, mne-stable, freesurfer"
        return 0
    fi
    ENV_NAME=$1

    if [[ $ENV_NAME == 'anaconda' ]]
    then
        export PATH=/usr/local/common/anaconda/bin:$PATH

        # up to users to set their copy of the source
        # export MNE_PYTHON=/path/to/mne-python

        export ETS_TOOLKIT="qt4" # should make mne.gui.coregister() work

    elif [[ $ENV_NAME == 'anaconda3' ]]
    then
        export PATH=/usr/local/common/anaconda3/bin:$PATH

        # up to users to set their copy of the source
        # export MNE_PYTHON=/path/to/mne-python

        export ETS_TOOLKIT="qt4" # should make mne.gui.coregister() work

    elif [[ $ENV_NAME == cuda ]]
    then
        export PATH=/usr/local/cuda/bin:$PATH

    elif [[ "$ENV_NAME" == mne* ]]
    then

        # MNE Configuration
        export MNE_ROOT=/usr/local/${ENV_NAME}

        if [ ! -d $MNE_ROOT ]
        then
            echo "Unknown MNE installation ($ENV_NAME), please check environment name."
            return 1
        fi

        export MATLAB_ROOT=/usr/local/common/matlab
        . $MNE_ROOT/bin/mne_setup_sh

        # Default digital trigger line on Aarhus Triux system is:
        export MNE_TRIGGER_CH_NAME="STI101"
        if [ ! -d ~/.mne ]
        then
            echo "First time MNE-user, ~/.mne created and set up."
            mkdir -p ~/.mne
            cp ${current_dir}/mne_setup_files/* ~/.mne
        fi

        # Save the env name of mne-something while loading freesurfer
        TMP=$ENV_NAME
        # Freesurfer is setup by default on CFIN servers
        # use freesurfer

        # Assume mne-python will be used too!
        use anaconda
        # But don't get double-PS1!
        export PS1=${DEFAULT_PS1}
        # And tell mne-something is loaded
        export ENV_NAME=$TMP

        # Set the default SUBJECTS_DIR to the MNE sample data
        if [[ $MINDLABPROJ == 'NA' && $HOSTNAME == 'isis' ]]
        then
            export SUBJECTS_DIR=/volatile/sample_data/MNE-sample-data
        fi

    elif [[ $ENV_NAME == 'freesurfer' ]]
    then
        export FREESURFER_HOME=/usr/local/${ENV_NAME}

        if [[ $MINDLABPROJ == 'NA' ]]
        then
            export SUBJECTS_DIR=${FREESURFER_HOME}/subjects
        fi
        . $FREESURFER_HOME/SetUpFreeSurfer.sh

	elif [[ $ENV_NAME == 'simnibs' ]]
	then
	    if [[ $PATH == *conda* ]]
		then
			export PATH=`echo ${PATH} | awk -v RS=: -v ORS=: '/conda/ {next} {print}' | sed 's/:*$//'`
			echo "Warning: SimNiBS uses the system python installation!"
			echo "(Ana)conda is now removed from your path."
	    fi
        export SIMNIBSDIR=/usr/local/common/simnibs
        source $SIMNIBSDIR/simnibs_conf.sh

    else
        echo "Unknown environment/programme: $ENV_NAME"
        return 1
    fi

    # This gets to be too much if multiple environments are loaded...
    #export PS1="($ENV_NAME): ${PS1}"
    # Just leave a subtle hint we've changed something in the path...
    #export PS1="*${PS1}"
    if [[ ${PS1}==DEFAULT_PS1 ]]
    then
        export PS1="<$ENV_NAME>${PS1}"
    else
        echo "Multiple environments selected (use'd), only first shown..."
    fi
    export MINDLABENV=$ENV_NAME
    echo "Environment '${ENV_NAME}' selected, use command 'unuse' to reset to default."

}

unuse ()
{
    # Simply set path & prompt back to what it was before "use" was called
    export PATH=${DEFAULT_PATH}
    export PS1=${DEFAULT_PS1}
    export LD_LIBRARY_PATH=${DEFAULT_LD_LIBRARY_PATH}
    echo ""
    echo "All environments unselected (last selected: '${MINDLABENV}'), path reset to default."
    export MINDLABENV='not set'
}

export -f set_mindlabproj use unuse  # export functions for subshells/children!
