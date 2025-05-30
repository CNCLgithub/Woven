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
bash demo_marg.sh
```
