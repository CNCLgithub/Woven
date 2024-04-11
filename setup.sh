#!/bin/bash -e
############################################################################
# @ Filename      : setup.sh
# @ Description   : 
# @ Arguments     : 
# @ Notes         : run with "bash -e setup.sh"
# @ Date          : 
############################################################################

. load_config.sh

## -------------------------Funcs-------------------------------- ##
echo_red () { echo -e "\033[0;31m $@ \033[0m"; }
echo_blue () { echo -e "\033[0;36m $@ \033[0m"; }
echo_green_check() { echo -e "\033[0;32m \u2714 \033[0m"; }
echo_red_cross() { echo -e "\033[0;31m x \033[0m"; }
cmd(){ echo `basename $0`; }
remove_dir(){ if [ -d $1 ]; then rm -rf $1; fi }
make_dir(){ if [ ! -d $1 ]; then mkdir -p $1; fi }

## -------------------------Preset-------------------------------- ##
make_dir out
if [ ! -d "library" ]; then
    echo_red "[Error] `cmd`: No data folder ./library ";
    exit 1
fi

cp "./scripts/particle_filter.jl" "./.julia/packages/Gen/HF44W/src/inference/"


## ==========================================================================
## ------------------------- Usage & Funcs-------------------------------- ##
## ==========================================================================
usage="Syntax: $(basename "$0") [-h|--help] [COMPONENTS...] -- will set up the project environment,
where:
    -h | --help     Print this help
    COMPONENTS...   Specify component to set up

Valid COMPONENTS:
    all              : set up all components (container will be pulled, not built)
    cont_[pull|build]: pull the singularity container or build it
    data             : pull data
    python           : create python virtual env
    julia            : setup julia
    flex             : build flex executables
    "
if [[ $# -eq 0 ]] || [[ "$@" =~ "--help" ]] || [[ "$@" =~ "-h" ]];then
    echo "$usage"
    exit 0
fi

## ==========================================================================
## ------------------------- container setup ----------------------------- ##
## ==========================================================================
if [[ "$@" =~ "cont_pull" ]];then
    echo_blue "Pulling singularity container..."
    wget "https://yale.box.com/shared/static/y97k5if408khmfke6skz0u2vsj827h0b.simg" -O "${ENV[cont]}"
    # wget "https://yale.box.com/shared/static/yi0x4dmu2znn2fubw4i0zs0w909oytz7.simg" -O "kimImage.simg"
    # mv kimImage.simg flex_julia/
elif [[ "$@" =~ "cont_build" ]] || [[ "$@" =~ "all" ]];then
    echo_blue "Building singularity container..."
    ## ==> Why -E flag? -- make env var visible to "sudo" sub-shell. Details see "docs/notes_on_env_var.txt"
    SINGULARITY_TMPDIR=/var/tmp sudo -E singularity build "${ENV[cont]}" Singularity
else
    echo_blue "Not touching container"
fi


## ==========================================================================
## ------------------------- python virtual env setup -------------------- ##
## ==========================================================================
# "python3.6 -m" install for a particular python version
if [[ "${@}" =~ "python" ]] || [[ "$@" =~ "all" ]];then
    echo_blue "Createing python virtual env..."

    # [TODO]: Need modify these
    singularity exec ${ENV[cont]} bash -c "/usr/bin/python3.6 -m venv ${ENV[env]}"
    ./run.sh "python -m pip install --upgrade pip"
    ## Otherwise potry will not install from lock file + no error message
    ## If failed, try "poetry lock -vvv&& poetry install -vvv && poetry show"
    ## poetry env info
    ## poetry env use $(which python)
    ## poetry env list --full-path
    remove_dir $HOME/.cache/pypoetry
    ./run.sh "python -m pip install --no-cache-dir poetry"
    ./run.sh "poetry config virtualenvs.create false"
    ./run.sh "poetry install -vvv"
    ## Install open3d for headless rendering on ubuntu16; [TODO] Use sha
    ## singularity exec ${ENV[cont]} bash -c "cp /opt/Open3D/build/lib/python_package/pip_package/*.whl $PWD"
    o3d_name="open3d-0.13.0-cp36-cp36m-manylinux_2_23_x86_64.whl"
    wget https://yale.box.com/shared/static/ngaro1gdv0o5ghe9890gtir8hzh403f2.whl -O $o3d_name
    ./run.sh "python -m pip install $o3d_name"
    rm $o3d_name
    ./run.sh "python -m pip install torch==1.9.1"
    ./run.sh "python -m pip install scikit-image==0.17.2"
fi


## ==========================================================================
## ------------------------- julia setup --------------------------------- ##
## ==========================================================================
# julia setup
if [[ "${@}" =~ "julia" ]] || [[ "$@" =~ "all" ]];then
    # In case the current folder is copied from somewhere else.
    echo_blue "Setup Julia..."
    remove_dir .julia
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


## ==========================================================================
## ------------------------- data ---------------------------------------- ##
## ==========================================================================
# download stimulus set
if [[ "$@" =~ "data" ]] || [[ "$@" =~ "all" ]];then
    echo_blue "Pulling data..."
    # DATADOWNLOAD=""
    # wget "$DATADOWNLOAD" -O "data.zip"
    # unzip "data.zip" -d "library"
else
    echo_blue "Not pulling any data"
fi


## ==========================================================================
## ------------------------- flex ---------------------------------------- ##
## ==========================================================================
if [[ "${@}" =~ "flex" ]] || [[ "$@" =~ "all" ]];then
    cd flex_julia
    singularity exec --nv ../${ENV[cont]} ./buildFleX.sh --build=true
    cd ..
fi


## ==========================================================================
## ------------------------- Others -------------------------------------- ##
## ==========================================================================

# if [ ! -d "flex_julia/depth_map/out/" ]; then
#     mkdir flex_julia/depth_map/out
# fi


# scene=wind

# cd flex_julia/depth_map/depth_map_o3d/out/observation

# for file_name in *obj_img_depth_${scene}.png
# do
#     new_file_name=${file_name%*.obj_img_depth_${scene}*}.png
#     mv "$file_name" "$new_file_name";
# done


# ffmpeg -framerate 224 -i ${scene}_cloth_%d.png -c:v libx264 -r 30 -pix_fmt yuv420p out.mp4
