average_chart <- function(file) {
  library(tidyverse)
  library(ggplot2)
  library(readxl)
  
  
  # load data 
  data <- readr::read_csv(file, show_col_types = FALSE)
  
  # format columns 
  noon_df <- data %>%
    mutate(hour_num = hour(hour)) %>%  
    filter(hour_num == 12) %>%
    select(hour, voltage) %>%
    mutate(voltage = as.numeric(voltage)) %>%
    drop_na(voltage) %>% 
    mutate(subgroup = row_number())
  

  # calculate subgroup stats
  sub_stats <- noon_df %>%
    group_by(subgroup) %>%
    summarise(
      n = sum(!is.na(voltage)),
      xbar = mean(voltage, na.rm = TRUE),
      R = max(voltage, na.rm = TRUE) - min(voltage, na.rm = TRUE),
      s = sd(voltage, na.rm = TRUE),
      SE = s/sqrt(n),
      .groups = "drop"
    )
  
  # control limits 
  n_eff <- stats::median(sub_stats$n, na.rm = TRUE)
  n_eff_rounded <- pmin(pmax(round(n_eff),2),10)
  
  
  d2_table <- tibble(
    n  = 2:10,
    d2 = c(1.128, 1.693, 2.059, 2.326, 2.534, 2.704, 2.847, 2.970, 3.078)
  )
  d2 <- d2_table$d2[match(n_eff_rounded, d2_table$n)]
  
  Rbar <- mean(sub_stats$R, na.rm = TRUE)
  xbarbar <- mean(sub_stats$xbar, na.rm = TRUE)
  sigmahat <- Rbar / d2
  SE_overall <- sigmahat / sqrt(n_eff) 
  
  UCL <- xbarbar + 3 * sigmahat / sqrt(n_eff)
  LCL <- xbarbar - 3 * sigmahat / sqrt(n_eff)
  sd1 <- xbarbar - 2 * sigmahat / sqrt(n_eff)
  sd2 <- xbarbar - 1 * sigmahat / sqrt(n_eff)
  sd3 <- xbarbar + 2 * sigmahat / sqrt(n_eff)
  sd4 <- xbarbar + 1 * sigmahat / sqrt(n_eff)
  
  
  
  # plot 
  p <- ggplot(sub_stats, aes(x = as.factor(subgroup), y = xbar, group = 1)) +
    geom_line() +
    geom_point(size = 2) +
    geom_errorbar(aes(ymin = xbar - SE, ymax = xbar + SE), width = 0.25, alpha = 0.7, color = "orange") +
    geom_hline(yintercept = xbarbar, linetype = "dashed", color = "blue")
    
    labs(
      title = "X Control Chart at 12:00 PM",
      x = "Observation Index",
      y = "Mean Voltage" 
    ) +
    theme_minimal()
  
  print(p)
}

avg_chart <- average_chart("code/solar_data_normal.csv")

