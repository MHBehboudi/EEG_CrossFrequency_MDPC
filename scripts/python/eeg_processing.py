# scripts/python/eeg_processing.py

import numpy as np
import mne
from mne.preprocessing import compute_current_source_density

def compute_tfr(epochs, sfreq, freqs, n_cycles, baseline_window_ms, times_ms):
    """Computes TFR for given epochs and applies baseline correction."""
    csd = compute_current_source_density(epochs, lambda2=1e-5, stiffness=4, n_legendre_terms=50)

    # This gets the data for the specific event type (e.g., 'High_P')
    epochs_data = csd.get_data() # (n_epochs, n_channels, n_times)

    tfr_power = mne.time_frequency.tfr_array_morlet(
        epochs_data, sfreq=sfreq, freqs=freqs, n_cycles=n_cycles,
        output='power', decim=5, n_jobs=-1, use_fft=True, zero_mean=True
    )

    # Apply baseline correction in dB
    baseline_idx = np.where((times_ms >= baseline_window_ms[0]) & (times_ms <= baseline_window_ms[1]))[0]

    # Important: Calculate a single baseline across all trials for the 'Quiet' condition
    # This baseline will be passed in for the 'Noisy' condition later.
    baseline_power = np.mean(tfr_power[:, :, :, baseline_idx], axis=(0, 3), keepdims=True)
    tfr_power_db = 10 * np.log10(tfr_power / baseline_power)

    return tfr_power_db, baseline_power # Return baseline for reuse

def apply_baseline(tfr_power, baseline_power):
    """Applies an existing baseline to TFR data."""
    tfr_power_db = 10 * np.log10(tfr_power / baseline_power)
    return tfr_power_db

def average_power_by_band(tfr_data_list, band_indices):
    """Averages TFR power across a specified frequency band for a list of subjects."""
    band_averaged_list = []
    for subject_data in tfr_data_list:
        # Mean across the frequency dimension (axis=1) for the selected band
        mean_band_power = np.mean(subject_data[:, band_indices, :, :], axis=1)
        band_averaged_list.append(mean_band_power)
    return band_averaged_list
