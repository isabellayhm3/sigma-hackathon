# Calculate MTTF
library(dplyr)

calculate_ttf <- function(data_file, failure_threshold = 0.7) {
  df <- read.csv(data_file, check.names = FALSE)
  
  if (!"hour" %in% names(df)) stop("Dataset must include a numeric 'hour' column.")
  
  df <- df %>%
    mutate(
      hour = as.numeric(hour),
      power = voltage * current
    ) %>%
    filter(!is.na(hour), !is.na(power))
  
  # --- 1. Baseline per panel ---
  baseline <- df %>%
    group_by(panel_id) %>%
    summarise(
      base_hour = min(hour, na.rm = TRUE),
      base_power = mean(power[hour == base_hour], na.rm = TRUE),
      .groups = "drop"
    )
  
  # --- 2. Fit linear model for each panel safely ---
  ttf_results <- df %>%
    group_by(panel_id) %>%
    summarise(
      slope = {
        m <- tryCatch(lm(power ~ hour, data = cur_data()), error = function(e) NULL)
        if (is.null(m) || is.na(coef(m)[2])) 0 else coef(m)[2]
      },
      intercept = {
        m <- tryCatch(lm(power ~ hour, data = cur_data()), error = function(e) NULL)
        if (is.null(m) || is.na(coef(m)[1])) mean(cur_data()$power, na.rm = TRUE) else coef(m)[1]
      },
      current_hour = max(hour, na.rm = TRUE),
      current_power = mean(power, na.rm = TRUE),
      .groups = "drop"
    ) %>%
    left_join(baseline, by = "panel_id") %>%
    mutate(
      failure_power = base_power * failure_threshold,
      time_to_failure = case_when(
        slope < 0 ~ (failure_power - intercept) / slope - current_hour,
        TRUE ~ Inf
      ),
      time_to_failure = ifelse(is.na(time_to_failure) | time_to_failure < 0, 0, time_to_failure),
      time_to_failure = pmin(time_to_failure, 500) # cap at 500 hours
    )
  
  # --- 3. Mean TTF across all panels ---
  mean_ttf <- mean(ttf_results$time_to_failure[is.finite(ttf_results$time_to_failure)], na.rm = TRUE)
  
  list(ttf_results = ttf_results, mean_ttf = mean_ttf)
}
