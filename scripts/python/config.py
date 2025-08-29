# scripts/python/config.py
import os
import numpy as np

# --- File & Path Settings ---
DESIRED_FILE_EXTENSION = 'PreEpoch.mat'
BASE_DIR = os.path.join(os.getcwd(), '..', '..') # Assumes scripts/python is the current dir
INPUT_DATA_DIR = os.path.join(BASE_DIR, 'data', 'raw_mat_files')
OUTPUT_CSV_PATH = os.path.join(BASE_DIR, 'results', 'csv', 'binned_connectivity_data_full_Theta.csv')
PLOTS_DIR = os.path.join(BASE_DIR, 'results', 'plots')


# --- TFR Parameters ---
BASELINE_WINDOW = np.array([-400, -150]) # ms
MIN_FREQ, MAX_FREQ, NUM_FREQ = 3, 31, 40
FREQUENCIES = np.linspace(MIN_FREQ, MAX_FREQ, NUM_FREQ)
RANGE_CYCLES = np.array([3, 10])
N_CYCLES = np.logspace(np.log10(RANGE_CYCLES[0]), np.log10(RANGE_CYCLES[1]), NUM_FREQ)
TIME_RANGE_INTEREST = [5900, 7500] # ms

# --- Frequency Band Definitions ---
ALPHA_BAND = (9, 12)  # Hz
THETA_BAND = (4, 8)    # Hz

# --- ROI Definitions ---
ROI_DEFINITIONS = {
    'Anterior-Left': ['fp1', 'af3', 'f7', 'f5', 'f3', 'f1'],
    'Central-Left':  ['ft7', 'fc5', 'fc3', 't7', 'c5', 'c3', 'tp7', 'cp5', 'cp3'],
    'Posterior-Left':['p7', 'p5', 'p3', 'po7', 'po5', 'o1'],
    'Anterior-Right':['fp2', 'af4', 'f8', 'f6', 'f4', 'f2'],
    'Central-Right': ['ft8', 'fc6', 'fc4', 't8', 'c6', 'c4', 'tp8', 'cp6', 'cp4'],
    'Posterior-Right':['p8', 'p6', 'p4', 'po8', 'po6', 'o2'],
    'Anterior-Midline': ['fz', 'fc1', 'fcz', 'fc2', 'c1', 'cz', 'c2', 'cp1', 'cpz', 'cp2'],
    'Posterior-Midline':['p1', 'pz', 'p2', 'po3', 'poz', 'po4', 'oz']
}

# --- Time Binning Parameters ---
TIME_BIN_EDGES = np.arange(5900, 7501, 800)
TIME_BIN_LABELS = [f"[{start},{end}]" for start, end in zip(TIME_BIN_EDGES[:-1], TIME_BIN_EDGES[1:])]
