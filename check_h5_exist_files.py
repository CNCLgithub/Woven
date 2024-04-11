#!/usr/bin/env python
# coding: utf-8

import warnings
import os, copy
import sys, math, fnmatch
from os.path import exists
import pandas as pd
from scipy import stats
import matplotlib.pyplot as plt
import random
import glob
import copy
import numpy as np
import json, h5py
pd.options.mode.chained_assignment = None  # default='warn'
from scipy import special
from os.path import exists
import argparse


parser = argparse.ArgumentParser(description='')
parser.add_argument('--h5_path',  type=str, default="cond_file/mass/mass_wind_0.5_0.5.csv")
args = parser.parse_args()
h5_path = args.h5_path

cond_out_file_name = h5_path.split('/')[-1].split('.csv')[0]+'_checked_h5.csv'
cond_out_file_name = os.path.join('/'.join(h5_path.split('/')[:-1]), cond_out_file_name)


with open(h5_path, 'r') as f:
    cond_in_file = pd.read_csv(f)
# [wb]: Create dummy variables    
cond_in_file['target'] = cond_in_file['target']
cond_in_file['prior'] = cond_in_file['prior']
cond_in_file['prior_model_idx'] = cond_in_file['prior_model_idx']
cond_in_file['target_model_idx'] = cond_in_file['target_model_idx']
cond_in_file['prior_mass'] = cond_in_file['prior_mass']
cond_in_file['target_mass'] = cond_in_file['target_mass']
cond_in_file['prior_stiff'] = cond_in_file['prior_stiff']
cond_in_file['target_stiff'] = cond_in_file['target_stiff']
cond_in_file['prior_weights'] = cond_in_file['prior_weights']
cond_in_file['target_weights'] = cond_in_file['target_weights']
cond_out_file_col_names = list(cond_in_file.columns.values)
cond_out_file = pd.DataFrame(columns = cond_out_file_col_names)
cond_out_file = cond_out_file.drop_duplicates(subset=['target', 'prior', 'prior_mass', 'prior_stiff'], keep='last')


for index, row in cond_in_file.iterrows():
    tmp_h5 = "out/result_{}_*_{}_{}.h5*".format(row['target'], row['prior'], row['prior_model_idx'])
    find_tmp_h5 = glob.glob(tmp_h5)
    if len(find_tmp_h5) == 0:
        cond_out_file = cond_out_file.append(cond_in_file.loc[index])
        cond_out_file = cond_out_file.reset_index(drop=True)
        
with open (cond_out_file_name, 'w') as f:
    cond_out_file.to_csv(f, index=False)

