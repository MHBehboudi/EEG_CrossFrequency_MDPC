# scripts/python/connectivity.py

import numpy as np
from sklearn.preprocessing import StandardScaler
from sklearn.decomposition import PCA
from sklearn.linear_model import RidgeCV

def extract_roi_data(tf_data, roi_name, ch_map, roi_definitions):
    """Extracts channel data for a specific ROI."""
    ch_list = roi_definitions.get(roi_name, [])
    ch_indices = [ch_map[ch_name.lower()] for ch_name in ch_list if ch_name.lower() in ch_map]
    if not ch_indices: return None
    return tf_data[ch_indices, :, :]

def reduce_roi_with_pca(roi_data, variance_to_keep=0.90):
    """Reduces ROI data dimensionality using PCA."""
    if roi_data is None or roi_data.shape[0] <= 1 or roi_data.shape[1] < 2: return None
    n_channels, n_trials, n_timepoints = roi_data.shape
    # Flatten channels and trials to fit PCA on the spatial pattern
    representative_data = np.mean(roi_data, axis=2).T # Shape: (n_trials, n_channels)

    scaler = StandardScaler().fit(representative_data)
    scaled_data = scaler.transform(representative_data)

    pca = PCA(n_components=variance_to_keep).fit(scaled_data)

    # Transform the data at each time point
    transformed_data = np.zeros((pca.n_components_, n_trials, n_timepoints))
    for t in range(n_timepoints):
        time_slice = roi_data[:, :, t].T # (n_trials, n_channels)
        scaled_time_slice = scaler.transform(time_slice)
        transformed_data[:, :, t] = pca.transform(scaled_time_slice).T

    return transformed_data

def calculate_binned_connectivity(source_data, target_data, source_t_idx, target_t_idx, n_folds=5):
    """Calculates time-lagged MDPC using RidgeCV."""
    if source_data is None or target_data is None or len(source_t_idx) == 0 or len(target_t_idx) == 0:
        return 0.0

    n_trials = min(source_data.shape[1], target_data.shape[1])
    X = np.mean(source_data[:, :n_trials, source_t_idx], axis=2).T
    Y = np.mean(target_data[:, :n_trials, target_t_idx], axis=2).T

    if X.shape[0] < n_folds: return 0.0

    try:
        ridge = RidgeCV(alphas=np.logspace(-3, 3, 10), cv=n_folds).fit(X, Y)
        # Use the score method, which calculates R^2, a measure of explained variance
        r2_score = ridge.score(X, Y)
        return max(r2_score, 0) # Return R^2, ensuring it's not negative
    except Exception:
        return 0.0
