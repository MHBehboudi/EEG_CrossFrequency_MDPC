# scripts/python/1_run_extraction.py

import os
import re
from collections import defaultdict
from itertools import product
import pandas as pd
from tqdm import tqdm
from scipy.io import loadmat
import numpy as np
import mne

# Import our custom modules
import config
from eeg_processing import compute_tfr, apply_baseline, average_power_by_band
from connectivity import extract_roi_data, reduce_roi_with_pca, calculate_binned_connectivity

def main():
    """Main function to run the entire extraction and connectivity pipeline."""
    print("--- Starting Data Extraction and MDPC Analysis ---")

    # Find and group subject files
    files = [f for f in os.listdir(config.INPUT_DATA_DIR) if config.DESIRED_FILE_EXTENSION in f]

    subject_files = defaultdict(list)
    subject_pattern = re.compile(r"(\d{6}_\d[mf]_\d{2}y)")
    for file in files:
        subject_match = subject_pattern.search(file)
        if subject_match:
            identifier = subject_match.group(1)
            subject_files[identifier].append(file)

    paired_subjects = {s: flist for s, flist in subject_files.items() if len(flist) == 2}
    print(f"Found {len(paired_subjects)} subjects with paired files.")

    # --- Data Storage ---
    tfr_data = defaultdict(list)
    subject_identifiers = []

    # --- Process Each Subject ---
    for subject, file_pair in tqdm(paired_subjects.items(), desc="Processing Subjects"):
        subject_identifiers.append(subject)
        quiet_file = next((f for f in file_pair if "Q" in f), None)

        baselines = {} # Store baselines from quiet condition

        for file in sorted(file_pair, key=lambda f: "Q" in f, reverse=True): # Process Quiet file first
            file_path = os.path.join(config.INPUT_DATA_DIR, file)
            mat_data = loadmat(file_path, squeeze_me=True, struct_as_record=False)
            EEG = mat_data['EEG']

            # Extract basic info
            times_ms = EEG.times
            sfreq = EEG.srate

            # Setup MNE info object (only once)
            if 'info' not in locals():
                chanlocs = EEG.chanlocs
                chan_names = [ch.labels for ch in chanlocs]
                info = mne.create_info(ch_names=chan_names, sfreq=sfreq, ch_types='eeg')
                montage = mne.channels.make_standard_montage('biosemi64')
                info.set_montage(montage)
                ch_map = {name.lower(): i for i, name in enumerate(info.ch_names)}

            # Create MNE EpochsArray
            epochs_data = np.transpose(EEG.data, (2, 0, 1))
            events = np.array([[i * EEG.pnts, 0, int(EEG.event[i*2].type)] for i in range(EEG.trials)])
            event_id = {"High_P": 11, "Low_P": 12}
            epochs = mne.EpochsArray(epochs_data, info, events=events, tmin=times_ms[0]/1000.0, event_id=event_id)

            for cloze_label, cloze_id in event_id.items():
                condition_key = f"{cloze_label}_{'Q' if file == quiet_file else 'N'}"

                if file == quiet_file:
                    tfr_db, baseline = compute_tfr(epochs[cloze_label], sfreq, config.FREQUENCIES, config.N_CYCLES, config.BASELINE_WINDOW, times_ms)
                    baselines[cloze_label] = baseline
                else:
                    # For noisy condition, apply the baseline from the quiet condition
                    tfr_power, _ = mne.time_frequency.tfr_array_morlet(epochs[cloze_label].get_data(), sfreq=sfreq, freqs=config.FREQUENCIES, n_cycles=config.N_CYCLES, output='power', decim=5, n_jobs=-1)
                    tfr_db = apply_baseline(tfr_power, baselines[cloze_label])

                time_idx = (times_ms >= config.TIME_RANGE_INTEREST[0]) & (times_ms <= config.TIME_RANGE_INTEREST[1])
                tfr_data[condition_key].append(tfr_db[:, :, time_idx])

    # --- Average by Frequency Bands ---
    alpha_indices = np.where((config.FREQUENCIES >= config.ALPHA_BAND[0]) & (config.FREQUENCIES <= config.ALPHA_BAND[1]))[0]
    theta_indices = np.where((config.FREQUENCIES >= config.THETA_BAND[0]) & (config.FREQUENCIES <= config.THETA_BAND[1]))[0]

    alpha_data = {key: average_power_by_band(val, alpha_indices) for key, val in tfr_data.items()}
    theta_data = {key: average_power_by_band(val, theta_indices) for key, val in tfr_data.items()}

    # --- Run MDPC Calculation ---
    print("\n--- Calculating Time-Lagged MDPC for each Condition ---")
    all_results = []
    roi_names = list(config.ROI_DEFINITIONS.keys())
    time_EEG = times_ms[time_idx]

    for subj_i, subj_id in enumerate(tqdm(subject_identifiers, desc="MDPC Calculation")):
        for condition_key in tfr_data.keys():
            source_subj_data = alpha_data[condition_key][subj_i]
            target_subj_data = theta_data[condition_key][subj_i]

            pca_source = {roi: reduce_roi_with_pca(extract_roi_data(source_subj_data, roi, ch_map, config.ROI_DEFINITIONS)) for roi in roi_names}
            pca_target = {roi: reduce_roi_with_pca(extract_roi_data(target_subj_data, roi, ch_map, config.ROI_DEFINITIONS)) for roi in roi_names}

            for r1, r2 in product(roi_names, repeat=2):
                for i, source_bin in enumerate(config.TIME_BIN_LABELS):
                    for j, target_bin in enumerate(config.TIME_BIN_LABELS):
                        source_t_start, source_t_end = config.TIME_BIN_EDGES[i], config.TIME_BIN_EDGES[i+1]
                        target_t_start, target_t_end = config.TIME_BIN_EDGES[j], config.TIME_BIN_EDGES[j+1]

                        source_t_idx = np.where((time_EEG >= source_t_start) & (time_EEG < source_t_end))[0]
                        target_t_idx = np.where((time_EEG >= target_t_start) & (time_EEG < target_t_end))[0]

                        conn_val = calculate_binned_connectivity(pca_source[r1], pca_target[r2], source_t_idx, target_t_idx)

                        all_results.append({
                            'subject_idx': subj_i,
                            'subject_filename': subj_id,
                            'noise': 'Noisy' if '_N' in condition_key else 'Quiet',
                            'cloze': 'High' if 'High_P' in condition_key else 'Low',
                            'source_roi': r1, 'target_roi': r2,
                            'source_bin': source_bin, 'target_bin': target_bin,
                            'connectivity_r2': conn_val
                        })

    # --- Save to CSV ---
    df_connectivity = pd.DataFrame(all_results)
    os.makedirs(os.path.dirname(config.OUTPUT_CSV_PATH), exist_ok=True)
    df_connectivity.to_csv(config.OUTPUT_CSV_PATH, index=False)
    print(f"\nAnalysis complete. Data saved to:\n{config.OUTPUT_CSV_PATH}")

if __name__ == "__main__":
    main()
