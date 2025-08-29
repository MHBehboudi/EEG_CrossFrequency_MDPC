# scripts/R/2_run_analysis.R

# --- 1. SETUP ---
# Clear environment if needed
rm(list = ls())

# Load all necessary libraries
library(tidyverse)
library(lme4)
library(lmerTest)
library(emmeans)
library(readxl)
library(progress)
library(broom)
library(gt)

# Source the file containing our custom functions
source("scripts/R/functions.R")

# --- 2. USER SETTINGS & FILE PATHS ---
USE_FDR_CORRECTION <- FALSE
CONNECTIVITY_FILE <- "results/csv/binned_connectivity_data_full_Theta.csv"
BEHAVIORAL_FILE <- "data/behavioral/SPIN_Data_Summary2.xlsx"
RESULTS_DIR <- "results/"

# --- 3. ANALYSIS WORKFLOW ---

# Step 1: Load and prepare the data
cat("--- Loading and preparing data ---\n")
full_data <- load_and_prepare_data(CONNECTIVITY_FILE, BEHAVIORAL_FILE)
cat("Data loaded successfully.\n\n")

# Step 2: Run the Linear Mixed-Effects Models
cat("--- Running LMM analysis on all connections ---\n")
lmm_results <- run_lmm_analysis(full_data)
cat("LMM analysis complete.\n\n")

# Step 3: Filter for significant results
cat("--- Filtering for significant connections ---\n")
if (USE_FDR_CORRECTION) {
  lmm_summary <- lmm_results$summary %>%
    mutate(p_noise_fdr = p.adjust(p_noise, method = "fdr"),
           p_cloze_fdr = p.adjust(p_cloze, method = "fdr"),
           p_interaction_fdr = p.adjust(p_interaction, method = "fdr"))
  significant_connections <- lmm_summary %>%
    filter(p_noise_fdr < 0.05 | p_cloze_fdr < 0.05 | p_interaction_fdr < 0.05)
  cat("Applied FDR correction.\n")
} else {
  significant_connections <- lmm_results$summary %>%
    filter(p_noise < 0.05 | p_cloze < 0.05 | p_interaction < 0.05)
  cat("Using uncorrected p-values.\n")
}
cat(paste("Found", nrow(significant_connections), "significant connections.\n\n"))

# Step 4: Run correlations with behavioral data (if any significant connections were found)
if (nrow(significant_connections) > 0) {
  cat("--- Running correlations with behavioral measures ---\n")
  behavioral_correlations <- run_behavioral_correlation(
    significant_connections,
    full_data,
    full_data %>% distinct(base_subject_id, .keep_all = TRUE) # Pass unique behavioral data
  )

  # Save correlation results
  write_csv(behavioral_correlations, file.path(RESULTS_DIR, "behavioral_correlations.csv"))
  cat("Correlation analysis complete. Results saved.\n\n")
} else {
  cat("--- No significant connections found, skipping correlation analysis. ---\n")
}

cat("--- Analysis pipeline finished successfully! ---\n")
