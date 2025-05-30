[![License](https://img.shields.io/badge/license-MIT-green.svg)](https://opensource.org/licenses/MIT)
[![Woven](https://img.shields.io/badge/language-Julia-red.svg)]()

# Woven

Implementation of the Woven model described in:

> **"Computational models reveal that intuitive physics underlies visual processing of soft objects"**  
> Wenyan Bi, Aalap D. Shah, Kimberly Wong, Brian J. Scholl, Ilker Yildirim  
> *Nature Communications*, 2025

## 📖 Citation

```bibtex
@article{Bi_Shah_Wong_Scholl_Yildirim,
  title={Computational models reveal that intuitive physics underlies visual processing of soft objects},
  author={Bi, Wenyan and Shah, Aalap D. and Wong, Kimberly and Scholl, Brian J. and Yildirim, Ilker},
  journal={Nature Communications},
  year={2025}
}
```

---

## 🖥️ System Requirements

This project has been tested and is supported on the following configurations:

- **Operating System**
  - Linux (tested on Ubuntu 18.04 and 20.04)

- **GPU Support**
  - NVIDIA GPU with CUDA capability  
    (tested with **NVIDIA Driver Version: 555.42.06**, **CUDA Version: 12.5**)

- **Container Runtime**
  - Singularity / Apptainer  
    (tested with **apptainer version 1.3.6-1.el8**)

---

## ⚙️ Setup and Running

### 1. Clone the Repository

```bash
git clone https://github.com/CNCLgithub/Woven.git
cd Woven
```

### 2. Download the Singularity Container and Required Data

```bash
bash setup.sh all
```

### 3. Run the Inference Process (Equation 1 in the Paper)

```bash
./run.sh julia src/exp_basic.jl <folder_index>/<scene_name>_<mass_value>_<stiffness_value>
```

#### Parameters

- `<folder_index>` corresponds to the scenario:
  - `1` → `wind`
  - `2` → `drape`
  - `3` → `ball`
  - `4` → `rotate`

- `<scene_name>` is one of: `wind`, `drape`, `ball`, `rotate`
- `<mass_value>` and `<stiffness_value>` specify the physical parameters

#### Example Commands

```bash
./run.sh julia src/exp_basic.jl 1/wind_0.5_2.0
./run.sh julia src/exp_basic.jl 2/drape_0.5_0.0078125
./run.sh julia src/exp_basic.jl 3/ball_0.5_0.0078125
./run.sh julia src/exp_basic.jl 4/rotate_0.5_2.0
```

### 4. Run the Marginalization Process (Equation 2 in the Paper)

```bash
./run.sh julia src/exp_basic_marg.jl <folder_index>/<target_scene>_<target_mass>_<target_stiffness> \
  <experiment_tag> \
  <random_seed>_<test_scene>_<test_mass>_<test_stiffness>_<random_suffix> \
  <inferred_test_mass> \
  <inferred_test_stiff> \
  <particle_weights_test>
```
#### Parameters

- `<folder_index>` corresponds to the scenario:
  - `1` → `wind`
  - `2` → `drape`
  - `3` → `ball`
  - `4` → `rotate`

- `<target_scene>` specify the scene of the target item, should be one of: `wind`, `drape`, `ball`, `rotate`.
- `<target_mass>` and `<target_stiffness>` specify the physical parameters of the target item.
- `<experiment_tag>` should be `stiffness` or `mass`.
- `<test_scene>` specify the scene of the test item.
- `<test_mass>` and `<test_stiffness>` specify the physical parameters of the test item.
- `<inferred_test_mass>`:  Underscore (`_`) separated list of inferred mass values of the test item from all particles in the final step of the particle filter. For example, if you use 20 particles, this will contain 20 mass values (one for each particle). Example: `0.25_0.5_0.5_0.75_0.6_...` (20 values total).
- `<inferred_test_stiff>`:  Underscore (`_`) separated list of inferred stiffness values of the test item from all particles in the final step of the particle filter. For example, if you use 20 particles, this will contain 20 stiffness values (one for each particle).
- `<particle_weights_test>`:  Underscore (`_`) separated list of weights for the particles used in the inference of the test item. Each weight corresponds to one particle's posterior probability from the final step of the particle filter. All weights should sum to 1. Example: `0.05_0.10_0.07_0.08_...` (20 values total).

#### Example Commands
```bash
bash demo_marg.sh
```



