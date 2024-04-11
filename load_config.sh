#!/bin/bash -e

# Loads config

# [Note] Why use "$var" instead of $var?
#  ==> If there's [space] in $var, you'll need use "$var";
#      otherwise it will be expanded into multiple variables.

CFGFILE="default.conf" # change to "default.conf"


. "$CFGFILE"

# export the required path variables
for i in "${!PATHS[@]}"
do
    # printf "%s \u2190 %s\n" "${i}" "${PATHS[$i]}"
    printf "export %s=\"%s\"\n" "${i}" "${PATHS[$i]}"    # ====> run with "eval $(./load_config.sh)"
    # Need to set env var to use inside singularity "son" shell. More details find "docs/notes_on_env_var.txt"
    export "${i}=${PATHS[$i]}"
done