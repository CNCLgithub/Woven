import os, sys, argparse, glob
import numpy as np
import ast, json, glob


def f_to_array(f1, reshape_hw=[539,242]):
    """
    reshape_hw = [height, width]
    """
    ext = f1.split(".")[-1]
    f1 = open(f1, "r")
    if ext == "txt":
        f1 = f1.read()
    elif ext == "json":
        f1 = json.load(f1)
    f1 = ast.literal_eval(f1)
    f1 = np.array(f1)
    if reshape_hw[0] != 0:
        f1 = f1.reshape(reshape_hw[0], reshape_hw[1]).astype(np.float64)
    return f1


def normal_dist(x , mean , sd):
    prob_density = (np.pi*sd) * np.exp(-0.5*((x-mean)/sd)**2)
    return prob_density


def log_sum(x_array, mean=0, sd=5):
    log_sum=0
    for i in x_array:
        pdf = normal_dist(i, mean, sd)
        log_sum += np.log(pdf)
    return log_sum