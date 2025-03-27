#!/bin/bash -e
####################################################################
# @ Filename      : setup.sh
# @ Description   : 
# @ Arguments     : 
# @ Notes         : run with "bash -e setup.sh all"
# @ Date          : 
####################################################################

. load_config.sh

## -------------------------------------------------------------- ##
echo_red () { echo -e "\033[0;31m $@ \033[0m"; }
echo_blue () { echo -e "\033[0;36m $@ \033[0m"; }
echo_green_check() { echo -e "\033[0;32m \u2714 \033[0m"; }
echo_red_cross() { echo -e "\033[0;31m x \033[0m"; }
cmd(){ echo `basename $0`; }
remove_dir(){ if [ -d $1 ]; then rm -rf $1; fi }
make_dir(){ if [ ! -d $1 ]; then mkdir -p $1; fi }
## -------------------------------------------------------------- ##

make_dir out


## =================================================================
## ------------------------- Usage & Funcs----------------------- ##
## =================================================================

usage="Syntax: $(basename "$0") [-h|--help] [COMPONENTS...] -- will set up the project environment,
where:
    -h | --help     Print this help
    COMPONENTS...   Specify component to set up

Valid COMPONENTS:
    all              : set up all components (container will be pulled, not built)
    cont_pull        : pull the singularity container
    data             : pull data
    python           : create python virtual env
    julia            : setup julia
    flex             : build flex executables
    "
if [[ $# -eq 0 ]] || [[ "$@" =~ "--help" ]] || [[ "$@" =~ "-h" ]];then
    echo "$usage"
    exit 0
fi

## =================================================================
## -------------------------- Container setup ------------------- ##
## =================================================================

if [[ "$@" =~ "cont_pull" ]] || [[ "$@" =~ "all" ]]; then
    if [[ ! -f "${ENV[cont]}" ]]; then
        echo_blue "Pulling singularity container..."
        wget "https://osf.io/download/jqvef" -O "${ENV[cont]}"
    else
        echo_blue "Container already exists. Skipping download."
    fi
else
    echo_blue "Not touching container."
fi


## =================================================================
## -------------------------- python virtual env setup ---------- ##
## =================================================================

if [[ "${@}" =~ "python" ]] || [[ "$@" =~ "all" ]];then
    echo_blue "Setup python virtual env..."

    singularity exec ${ENV[cont]} bash -c "/usr/bin/python3.6 -m venv ${ENV[env]}"
    ./run.sh "python -m pip install --upgrade pip"
    remove_dir $HOME/.cache/pypoetry
    ./run.sh "python -m pip install --no-cache-dir poetry"
    ./run.sh "poetry config virtualenvs.create false"
    ./run.sh "poetry install -vvv"
    rm $o3d_name
fi


## =================================================================
## -------------------------- julia setup ----------------------- ##
## =================================================================

if [[ "${@}" =~ "julia" ]] || [[ "$@" =~ "all" ]];then
    echo_blue "Setup Julia..."
    ./run.sh julia -e '"using Pkg; Pkg.instantiate()"'
    ./run.sh julia -e '"using Pkg; Pkg.add(\"FileIO\")"'
    ./run.sh julia -e '"using Pkg; Pkg.add(\"GeometryBasics\")"'
    ./run.sh julia -e '"using Pkg; Pkg.add(\"BenchmarkTools\")"'
    ./run.sh julia -e '"using Pkg; Pkg.add(\"MeshIO\")"'
    ./run.sh julia -e '"using Pkg; Pkg.add(\"PyCall\")"'
    ./run.sh julia -e '"using Pkg; Pkg.build(\"PyCall\")"'
    ./run.sh julia -e '"using Pkg; Pkg.add(\"Reexport\")"'
    ./run.sh julia -e '"using Pkg; Pkg.add(\"Formatting\")"'
    ./run.sh julia -e '"using Pkg; Pkg.add(\"Distances\")"'
    ./run.sh julia -e '"using Pkg; Pkg.add(\"JSON\")"'
fi


## =================================================================
## -------------------------- data ------------------------------ ##
## =================================================================

if [[ "$@" =~ "data" ]] || [[ "$@" =~ "all" ]];then
    echo_blue "Pulling data..."
    wget "https://osf.io/download/5k2qs" -O "library.tar.gz"
    tar -xzf library.tar.gz library && rm library.tar.gz
else
    echo_blue "Not pulling any data"
fi


## =================================================================
## -------------------------- flex ------------------------------ ##
## =================================================================

if [[ "${@}" =~ "flex" ]] || [[ "$@" =~ "all" ]];then
    cd flex_julia
    singularity exec --nv ../${ENV[cont]} ./buildFleX.sh --build=true
    cd ..
fi
