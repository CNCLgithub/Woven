[![License](https://img.shields.io/badge/license-MIT-green.svg)](https://opensource.org/licenses/MIT)
[![Woven](https://img.shields.io/badge/language-Julia-red.svg)]()

# Woven
This folder contains the scripts for implementing Woven: A simulation-based probabilistic model of soft object perception.

## Setup
The script downloads the Singularity environment and the necessary data.

```
bash setup.sh all
```

## Run the inference

To run the demo inferences, use the following command:
```
 ./run.sh julia src/exp_basic.jl 1/wind_0.5_2.0
 ./run.sh julia src/exp_basic.jl 2/drape_0.5_0.0078125
 ./run.sh julia src/exp_basic.jl 3/ball_0.5_0.0078125
 ./run.sh julia src/exp_basic.jl 4/rotate_0.5_2.0
```


## Citation
