[![License](https://img.shields.io/badge/license-MIT-green.svg)](https://opensource.org/licenses/MIT)
[![Woven](https://img.shields.io/badge/language-Julia-red.svg)]()

> since 2024-07-13

# Woven
This folder contains the scripts for implementing Woven: A simulation-based probabilistic model of soft object perception.

## Setup
The script downloads the Singularity environment and the necessary data.

```
bash setup.sh all
```

## Run the inference

To run the demo of the joint-inference step, use the following commands:
```
 ./run.sh julia src/exp_basic.jl 1/wind_0.5_2.0
 ./run.sh julia src/exp_basic.jl 2/drape_0.5_0.0078125
 ./run.sh julia src/exp_basic.jl 3/ball_0.5_0.0078125
 ./run.sh julia src/exp_basic.jl 4/rotate_0.5_2.0
```
To run the demo of the marginalization step, use the following command:
```
bash demo_marg.sh
```
## Citation
