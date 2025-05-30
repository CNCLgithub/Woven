[![License](https://img.shields.io/badge/license-MIT-green.svg)](https://opensource.org/licenses/MIT)
[![Woven](https://img.shields.io/badge/language-Julia-red.svg)]()

> since 2024-07-13

# Woven
Implementation of Woven model in "Computational models reveal that intuitive physics underlies visual processing of soft objects"

```bib
@article{Bi_Shah_Wong_Scholl_Yildirim,
title={Computational models reveal that intuitive physics underlies visual processing of soft objects},
author={Bi, Wenyan and Shah, Aalap D. and Wong, Kimberly and Scholl, Brian J. and Yildirim, Ilker},
journal={Nature Communications},
year={2025}
} 
```
## System Requirements
This project is tested and supported on:
- **Operating System**:
  - Linux (tested on version linux 18.04 and linux 20.04)
- **GPU Support**:
  - NVIDIA GPU with CUDA capability (tested on NVIDIA Driver Version: 555.42.06, CUDA Version: 12.5)
- **Container Runtime**:
  - Singularity (tested on version apptainer version 1.3.6-1.el8).

## Setup and running
1. Clone repository `git clone https://github.com/CNCLgithub/Woven.git` and `cd Woven`.
2. Run `bash setup.sh all` to download the Singularity container and all required data.
3. Run the demo of the inference process (i.e., Eq. 1 in the paper), use the following command:
    ```
     ./run.sh julia src/exp_basic.jl 1/wind_0.5_2.0
     ./run.sh julia src/exp_basic.jl 2/drape_0.5_0.0078125
     ./run.sh julia src/exp_basic.jl 3/ball_0.5_0.0078125
     ./run.sh julia src/exp_basic.jl 4/rotate_0.5_2.0
    ```
4. Run the demo of the marginalization process (i.e., Eq. 2 in the paper), use the following command:
    ```
    bash demo_marg.sh
    ```
