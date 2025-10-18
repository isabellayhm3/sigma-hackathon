#Install packages
library(dplyr)
library(readr)

##### Function that takes in the data and analyzes #######
calculate_performance <- function(data_file) {
  df <- read_csv(data_file, show_col_types = FALSE) %>%
    mutate(
      hour = as.numeric(hour),
      power = voltage * current
    ) %>%
    filter(hour >= 6 & hour <= 18)
  
  #Calculate stats for the data by hour 
  df <- df %>%
    group_by(hour) %>%
    mutate(
      mean_power = mean(power, na.rm = TRUE),
      sd_power   = sd(power, na.rm = TRUE),
      #z-score relative to mean
      norm_power = 1 - ((mean_power - power) / (3 * sd_power)),
      norm_power = pmin(pmax(norm_power, 0), 1)  # clamp to [0,1]
    ) %>%
    ungroup()
  
  #Average for each panel across the whole day
  daily_avg <- df %>%
    group_by(panel_id) %>%
    summarise(avg_power = mean(norm_power, na.rm = TRUE), .groups = "drop")
  
  #Save results into new csv file
  write_csv(df, "panel_hourly_performance_sigma.csv")
  write_csv(daily_avg, "panel_daily_average_sigma.csv")
  
  #Sanity check
  list(hourly = df, daily = daily_avg)
}
