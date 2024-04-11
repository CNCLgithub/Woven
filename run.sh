#!/bin/bash

############################################################################
# @ Filename      : run.sh
# @ Description   : 
# @ Arguments     : 
# @ Notes         : ./run.sh julia src/exp_basic.jl 1/wind_0.5_0.0078125
# @ Date          : 
############################################################################


# ">> /dev/null" redirects standard output (stdout) to /dev/null, which discards it.
# 2>&1 redirects standard error (2) to standard output (1), which then discards it as well 
# since standard output has already been redirected.
cd "$( cd "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"

. load_config.sh

# Define the path to the container and conda env
CONT="${ENV['cont']}"

# Parse the incoming command
COMMAND="$@"

# Enter the container and run the command
SING="${ENV['exec']} exec --nv"
mounts=(${ENV['mounts']})
BS=""
for i in "${mounts[@]}";do
    if [[ $i ]]; then
        BS="${BS} -B $i:$i"
    fi
done

# add the repo path to "/project"
# BS="${BS} -B ${PWD}:/project"
BS=""

printf "=%.0s"  $(seq 1 79)
printf "\nExecuting: %s\n" "${COMMAND}"
printf "=%.0s"  $(seq 1 79)
printf "\n"


if [ ! -d "out" ]; then
    mkdir out
fi

${SING} ${BS} ${CONT} bash -c "source ${ENV['env']}/bin/activate \
                                && exec $COMMAND \
                                && deactivate"




# if [ ! -d "flex_julia/depth_map/out" ]; then
#     mkdir flex_julia/depth_map/out
# fi

# if [ ! -d "flex_julia/depth_map/out/observation" ]; then
#     mkdir flex_julia/depth_map/out/observation
# fi