# -------------------------------------------------------------
# calculate_ttf.R — Estimate Time to Failure (TTF) for panels
# -------------------------------------------------------------

library(dplyr)

calculate_ttf <- function(data_file, failure_threshold = 0.7) {
  # Load and preprocess
  df <- read.csv(data_file, check.names = FALSE)
  df <- df %>%
    mutate(
      hour = as.numeric(gsub(":.*", "", time)),  # ensure numeric time
      power = voltage * current
    )

  # Compute baseline (first hour mean power)
  baseline_power <- df %>%
    group_by(panel_id) %>%
    summarise(initial_power = mean(power[hour == min(hour, na.rm = TRUE)], na.rm = TRUE))

  # Compute average power per hour
  hourly_power <- df %>%
    group_by(panel_id, hour) %>%
    summarise(mean_power = mean(power, na.rm = TRUE), .groups = "drop")

  # Merge baseline
  hourly_power <- left_join(hourly_power, baseline_power, by = "panel_id")

  # Fit linear model for each panel and predict TTF
  ttf_results <- hourly_power %>%
    group_by(panel_id) %>%
    do({
      model <- lm(mean_power ~ hour, data = .)
      slope <- coef(model)[["hour"]]
      intercept <- coef(model)[["(Intercept)"]]
      current_power <- tail(.$mean_power, 1)
      current_hour <- tail(.$hour, 1)
      failure_power <- .$initial_power[1] * failure_threshold
      time_to_fail <- ifelse(slope < 0,
                             (failure_power - intercept) / slope - current_hour,
                             Inf)
      data.frame(
        current_power = current_power,
        slope = slope,
        failure_power = failure_power,
        time_to_failure = ifelse(time_to_fail < 0, 0, time_to_fail)
      )
    }) %>%
    ungroup()

  ttf_summary <- ttf_results %>%
    mutate(
      time_to_failure = round(time_to_failure, 2),
      current_health = round(current_power / failure_power, 2)
    )

  write.csv(ttf_summary, "panel_ttf_results.csv", row.names = FALSE)
  message("✅ Wrote panel_ttf_results.csv")
  return(ttf_summary)
}
