# scripts/R/functions.R

load_and_prepare_data <- function(connectivity_file, behavioral_file) {
  # Load connectivity data and perform initial mutations
  connectivity_df <- read_csv(connectivity_file) %>%
    mutate(
      subject = factor(subject_idx),
      base_subject_id = str_extract(subject_filename, "^(\\d{6}_\\d[mf]_\\d{2}y|Pilot\\d+_[A-Za-z]+|Pilot_\\d+_[A-Za-z]+)"),
      noise = factor(noise, levels = c("Quiet", "Noisy")),
      cloze = factor(cloze, levels = c("Low", "High"))
    )

  # Load behavioral data
  behavioral_df <- read_excel(behavioral_file, sheet = 1) %>%
    rename(base_subject_id = SubjectID) %>%
    mutate(base_subject_id = as.character(base_subject_id))

  # Join the two datasets
  full_data <- inner_join(connectivity_df, behavioral_df, by = "base_subject_id")

  return(full_data)
}

run_lmm_analysis <- function(data) {
  analysis_plan <- data %>%
    distinct(source_roi, target_roi, source_bin, target_bin)

  all_model_results <- list()
  all_fitted_models <- list()

  pb <- progress::progress_bar$new(
    format = "Running models [:bar] :percent in :elapsed",
    total = nrow(analysis_plan), clear = FALSE, width = 60
  )

  for (i in 1:nrow(analysis_plan)) {
    pb$tick()
    current_params <- analysis_plan[i, ]
    model_data <- data %>%
      filter(source_roi == current_params$source_roi,
             target_roi == current_params$target_roi,
             source_bin == current_params$source_bin,
             target_bin == current_params$target_bin)

    model_fit <- lmer(connectivity_r2 ~ noise * cloze + (1 | subject), data = model_data)

    model_name <- paste(current_params$source_roi, current_params$target_roi,
                        current_params$source_bin, current_params$target_bin, sep = "_")
    all_fitted_models[[model_name]] <- model_fit

    anova_res <- anova(model_fit)

    all_model_results[[i]] <- tibble(
      source_roi = current_params$source_roi,
      target_roi = current_params$target_roi,
      source_bin = current_params$source_bin,
      target_bin = current_params$target_bin,
      F_noise = anova_res["noise", "F value"],
      p_noise = anova_res["noise", "Pr(>F)"],
      F_cloze = anova_res["cloze", "F value"],
      p_cloze = anova_res["cloze", "Pr(>F)"],
      F_interaction = anova_res["noise:cloze", "F value"],
      p_interaction = anova_res["noise:cloze", "Pr(>F)"]
    )
  }

  results_summary_df <- bind_rows(all_model_results)
  return(list(summary = results_summary_df, models = all_fitted_models))
}

run_behavioral_correlation <- function(significant_connections, connectivity_data, behavioral_data) {
  behavioral_measures <- behavioral_data %>%
    select(where(is.numeric), -any_of(c("base_subject_id", "subject_idx"))) %>%
    names()

  correlation_results <- list()

  for (i in 1:nrow(significant_connections)) {
    conn_row <- significant_connections[i, ]

    avg_connectivity_per_subject <- connectivity_data %>%
      filter(source_roi == conn_row$source_roi,
             target_roi == conn_row$target_roi,
             source_bin == conn_row$source_bin,
             target_bin == conn_row$target_bin) %>%
      group_by(base_subject_id, noise, cloze) %>%
      summarise(avg_connectivity_r2 = mean(connectivity_r2, na.rm = TRUE), .groups = 'drop')

    merged_data <- inner_join(avg_connectivity_per_subject, behavioral_data, by = "base_subject_id")

    for (b_measure in behavioral_measures) {
      for (n_level in levels(merged_data$noise)) {
        for (c_level in levels(merged_data$cloze)) {
          condition_data <- merged_data %>%
            filter(noise == n_level, cloze == c_level)

          if (nrow(condition_data) > 2) {
            cor_test_res <- cor.test(condition_data$avg_connectivity_r2, condition_data[[b_measure]])
            correlation_results[[length(correlation_results) + 1]] <- tibble(
              source_roi = conn_row$source_roi, target_roi = conn_row$target_roi,
              source_bin = conn_row$source_bin, target_bin = conn_row$target_bin,
              behavioral_measure = b_measure,
              noise_condition = n_level, cloze_condition = c_level,
              correlation_r = cor_test_res$estimate,
              correlation_p = cor_test_res$p.value
            )
          }
        }
      }
    }
  }

  final_correlation_df <- bind_rows(correlation_results)
  return(final_correlation_df)
}
