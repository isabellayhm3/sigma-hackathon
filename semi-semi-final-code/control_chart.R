average_chart <- function(file) {
  library(tidyverse)
  library(ggplot2)
  library(readxl)
  
  
  # load data 
  df <- readr::read_csv(file, show_col_types = FALSE) %>% 
    mutate(voltage = as.numeric(voltage)) %>%
    drop_na(voltage)
  
  # calculate subgroup stats
  sub_stats <- df %>%
    group_by(panel_id) %>%
    summarise(
      n = n(),
      xbar = mean(voltage, na.rm = TRUE),
      R = max(voltage, na.rm = TRUE) - min(voltage, na.rm = TRUE),
      s = ifelse(n() > 1, sd(voltage, na.rm = TRUE), 0),
      SE = ifelse(n() > 1, s / sqrt(n), 0),
      .groups = "drop"
    ) %>% 
    mutate(subgroup = as.integer(factor(panel_id)))
  
  # center and spread estimates for xbar 
  xbarbar <- mean(sub_stats$xbar, na.rm = TRUE)
  Rbar <- mean(sub_stats$R, na.rm = TRUE)
  
  # subgroup size (median readings per panel) 
  n_eff <- stats::median(sub_stats$n, na.rm = TRUE)
  n_eff_rounded <- pmin(pmax(round(n_eff),2),25)
  
  # d2 constants
  d2_table <- tibble(
    n  = 2:25,
    d2 = c(1.128,1.693,2.059,2.326,2.534,2.704,2.847,2.970,3.078,3.173,
           3.258,3.336,3.407,3.472,3.532,3.588,3.640,3.689,3.735,3.778,
           3.819,3.858,3.895,3.931)
  )
  d2 <- d2_table$d2[match(n_eff_rounded, d2_table$n)]
  
  sigmahat   <- Rbar / d2
  SE_overall <- sigmahat / sqrt(n_eff) 
  
  UCL <- xbarbar + 3 * sigmahat / sqrt(n_eff)
  LCL <- xbarbar - 3 * sigmahat / sqrt(n_eff)
  sd1 <- xbarbar - 2 * sigmahat / sqrt(n_eff)
  sd2 <- xbarbar - 1 * sigmahat / sqrt(n_eff)
  sd3 <- xbarbar + 2 * sigmahat / sqrt(n_eff)
  sd4 <- xbarbar + 1 * sigmahat / sqrt(n_eff)
  
  
  # plot 
  p <- ggplot(sub_stats %>% arrange(subgroup),
              aes(x = reorder(as.character(panel_id), subgroup), y = xbar, group = 1)) +
    geom_line() +
    geom_point(size = 1) +
    geom_hline(yintercept = xbarbar, linetype = "dashed", color = "blue") +
    geom_hline(yintercept = UCL, linetype = "dotted") +
    geom_hline(yintercept = LCL, linetype = "dotted") +
    geom_hline(yintercept = sd1, linetype = "dotdash") +
    geom_hline(yintercept = sd2, linetype = "dotdash") +
    geom_hline(yintercept = sd3, linetype = "dotdash") +
    geom_hline(yintercept = sd4, linetype = "dotdash") +
    labs(
      title = "X̄ Control Chart by Panel (whole day)",
      x = "Panel",
      y = "Daily Mean Voltage (x̄)"
    ) +
    theme_minimal()
  
  print(p)
}

avg_chart <- average_chart("code/solar_data_normal.csv")

