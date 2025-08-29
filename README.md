# EEG Preprocessing and Cross-Frequency MDPC Analysis Pipeline

This project contains a full MATLAB, Python, and R pipeline to preprocess raw EEG data, analyze cross-frequency coupling using Multidimensional Pattern Connectivity (MDPC), and perform robust statistical analysis.

---

## Workflow Overview

The analysis pipeline proceeds in three distinct stages, moving from raw data to final statistical results. Each stage is handled by a different language and must be run in the specified order.

```
[Raw .dat files] --> MATLAB (Preprocessing) --> [Cleaned .set files] --> Python (MDPC Analysis) --> [Connectivity .csv file] --> R (Statistical Analysis) --> [Plots & Tables]
```

---

## Project Structure

```
.
├── scripts/
│   ├── matlab/
│   │   ├── 0_Information_Extraction.m
│   │   └── 1_Cleaning_Pipeline.m
│   ├── python/
│   │   ├── config.py
│   │   ├── connectivity.py
│   │   ├── eeg_processing.py
│   │   └── 2_run_extraction.py
│   └── R/
│       ├── functions.R
│       └── 3_run_analysis.R
├── data/
│   ├── behavioral/
│   │   └── SPIN_Data_Summary2.xlsx
│   └── raw_mat_files/
│       └── ├── results/
│   ├── csv/
│   │   └── │   └── plots/
│       └── ├── .gitignore
└── README.md
```

---

## Setup and Installation

### 1. MATLAB
* **MathWorks MATLAB** (tested on version R20XXx)
* **EEGLAB Toolbox**: Ensure EEGLAB is installed and added to your MATLAB path. This pipeline relies on EEGLAB functions for preprocessing.

### 2. Python
It is recommended to use a virtual environment.

```bash
# Create and activate a virtual environment
python -m venv venv
source venv/bin/activate  # On Windows use `venv\Scripts\activate`

# Install required packages
# NOTE: A requirements.txt file should be generated and added to the repo.
pip install numpy pandas mne scikit-learn tqdm scipy
```

### 3. R
Open R or RStudio and run the following command in the console to install the necessary packages:

```R
install.packages(c("tidyverse", "lme4", "lmerTest", "emmeans", "readxl", "progress", "broom", "gt"))
```

---

## How to Run the Pipeline

1.  **Prepare Data**: Place your raw `.dat` files and the participant information spreadsheet (e.g., `Participant_Spreadsheet_Adult_SPIN_Modified.xlsx`) inside your local `data/raw_mat_files/` folder. Place the behavioral summary (e.g., `SPIN_Data_Summary2.xlsx`) in the `data/behavioral/` folder.

2.  **Run MATLAB Preprocessing**:
    * Open MATLAB and navigate to the `scripts/matlab/` directory.
    * Run `0_Information_Extraction.m`.
    * Run `1_Cleaning_Pipeline.m`. This will generate cleaned `.set` files in your specified output folder.

3.  **Run Python MDPC Analysis**:
    * Make sure the preprocessed EEG files (in `.mat` format) are accessible.
    * Navigate to the `scripts/python/` directory.
    * Run the main script: `python 2_run_extraction.py`. This will generate the primary `binned_connectivity_data_full_Theta.csv` file in the `results/csv/` folder.

4.  **Run R Statistical Analysis**:
    * Open RStudio and set the working directory to the root of the project folder.
    * Run the main script: `source('scripts/R/3_run_analysis.R')`. This will read the CSV from the `results/csv/` folder and save statistical outputs to the `results/` directory.

---

## Outputs

* **MATLAB**: Preprocessed EEG data in EEGLAB's `.set` format.
* **Python**: A single `.csv` file (`binned_connectivity_data_full_Theta.csv`) containing the calculated connectivity values for every subject, condition, ROI pair, and time bin.
* **R**: Statistical tables and plots summarizing the results of the LMM and correlation analyses.
