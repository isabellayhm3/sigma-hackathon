# control_chart.R
library(tidyverse)
library(ggplot2)

average_chart <- function(file) {
  # Load data
  data <- readr::read_csv(file, show_col_types = FALSE)
  
  # Extract noon data (hour == 12)
  noon_df <- data %>%
    mutate(hour_num = as.numeric(hour)) %>%  
    filter(hour_num == 12) %>%
    select(hour, voltage) %>%
    mutate(voltage = as.numeric(voltage)) %>%
    drop_na(voltage) %>% 
    mutate(subgroup = row_number())
  
  # Subgroup statistics
  sub_stats <- noon_df %>%
    group_by(subgroup) %>%
    summarise(
      n = sum(!is.na(voltage)),
      xbar = mean(voltage, na.rm = TRUE),
      R = max(voltage, na.rm = TRUE) - min(voltage, na.rm = TRUE),
      s = sd(voltage, na.rm = TRUE),
      SE = s / sqrt(n),
      .groups = "drop"
    )
  
  # Determine d2 constant based on subgroup size
  n_eff <- stats::median(sub_stats$n, na.rm = TRUE)
  n_eff_rounded <- pmin(pmax(round(n_eff), 2), 10)
  
  d2_table <- tibble(
    n  = 2:10,
    d2 = c(1.128, 1.693, 2.059, 2.326, 2.534, 2.704, 2.847, 2.970, 3.078)
  )
  d2 <- d2_table$d2[match(n_eff_rounded, d2_table$n)]
  
  # Control limits
  Rbar <- mean(sub_stats$R, na.rm = TRUE)
  xbarbar <- mean(sub_stats$xbar, na.rm = TRUE)
  sigmahat <- Rbar / d2
  UCL <- xbarbar + 3 * sigmahat / sqrt(n_eff)
  LCL <- xbarbar - 3 * sigmahat / sqrt(n_eff)
  
  # Plot
  ggplot(sub_stats, aes(x = subgroup, y = xbar)) +
    geom_line(color = "grey40") +
    geom_point(size = 2, color = "#0072B2") +
    geom_hline(yintercept = xbarbar, linetype = "dashed", color = "blue", linewidth = 1) +
    geom_hline(yintercept = UCL, linetype = "dotted", color = "red") +
    geom_hline(yintercept = LCL, linetype = "dotted", color = "red") +
    annotate("text", x = max(sub_stats$subgroup), y = UCL, label = "UCL", vjust = -1, hjust = 1, color = "red") +
    annotate("text", x = max(sub_stats$subgroup), y = LCL, label = "LCL", vjust = 1.5, hjust = 1, color = "red") +
    labs(
      title = "X̄ Control Chart (12:00 PM)",
      subtitle = "Mean voltage per panel subgroup with ±3σ limits",
      x = "Observation Index",
      y = "Mean Voltage"
    ) +
    theme_minimal(base_size = 14)
}
