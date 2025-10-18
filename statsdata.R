library(dplyr) 
library(tidyr)
library(readr)
library(lubridate)
library(rlang)

hourly_stats_array <- function(file) {
  
  
  # load data 
  data <- readr::read_csv(file, show_col_types = FALSE)
  
  # create hour and power columns 
  df <- data %>%
    mutate(
      hour = as.numeric(gsub(":.*", "", time)), # extract hour number from "0:00"
      power = voltage * current
    )
  
  
  # hourly stats 
  hour_stats <- df %>%
    group_by(hour) %>%
    summarise(
      n_obs = n(),
      voltage_mean = mean(voltage, na.rm = TRUE),
      voltage_sd = sd(voltage, na.rm = TRUE),
      current_mean = mean(current, na.rm = TRUE),
      current_sd = sd(current, na.rm = TRUE),
      power_mean = mean(power, na.rm = TRUE),
      power_sd = sd(power, na.rm = TRUE),
      .groups = "drop"
    ) %>%
    arrange(hour)
  
  
  # turn into matrix  
  arr <- hour_stats %>%
    dplyr::select(hour, voltage_mean, voltage_sd,
                  current_mean, current_sd,
                  power_mean, power_sd) %>%
    tibble::column_to_rownames("hour") %>%
    as.matrix()
  
  # export to csv 
  output_csv <- "hourly_stats_results.csv"
  
  df_out <- as.data.frame(arr)
  df_out$hour <- rownames(df_out)
  df_out <- df_out %>% relocate(hour)
  readr::write_csv(df_out, output_csv)
  
  message(sprintf("Wrote %s in: %s", output_csv, getwd()))
  return(arr)
}
res <- hourly_stats_array("code/solar_data - solar_data.csv")
panel_data <- read.csv("code/solar_data - solar_data.csv")
hourly_stats_array(panel_data)  



