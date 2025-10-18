library(dplyr)
library(readr)

hourly_stats_array <- function(file) {
  
  # ---- 1) Load raw data ----
  data <- read_csv(file, show_col_types = FALSE)
  
  # ---- 2) Create numeric hour and power columns ----
  data <- data %>%
    mutate(hour = as.numeric(sub(":.*", "", hour)),
           power = voltage * current)
  
  # ---- 3) Compute hourly summary stats ----
  hour_stats <- data %>%
    group_by(hour) %>%
    summarise(
      voltage_mean = mean(voltage, na.rm = TRUE),
      voltage_sd   = sd(voltage, na.rm = TRUE),
      current_mean = mean(current, na.rm = TRUE),
      current_sd   = sd(current, na.rm = TRUE),
      power_mean   = mean(power, na.rm = TRUE),
      power_sd     = sd(power, na.rm = TRUE),
      .groups = "drop"
    ) %>%
    arrange(hour)
  
  # ---- 4) Export baseline CSV ----
  output_csv <- paste0("stats_data.csv")
  readr::write_csv(hour_stats, output_csv)
  
  message(sprintf("✅ Wrote %s in: %s", output_csv, getwd()))
  
  return(hour_stats)
}
