#!/bin/bash
#SBATCH --job-name=untar_onedir
#SBATCH --partition=psych_day
#SBATCH --gres=gpu:0
#SBATCH --cpus-per-task=1
#SBATCH --mem=1G
#SBATCH --time=00-12:00:00
pwd; hostname; date


#mainDir="$(dirname $(realpath $0))"
tar -xzf $1.tar.gz $1 #&& rm -rf $1 # add -v to verbose
