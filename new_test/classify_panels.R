library(dplyr)
library(readr)
library(tidyr)
library(purrr)

# -------------------------------------------------------------
# classify_panels():
#   data_file ........ raw data CSV (panel_id, hour, voltage, current)
#   baseline_file .... hourly baseline CSV (hour, power_mean, power_sd)
#   w ................ neighborhood radius (1 = 3x3)
# returns ............ data.frame with Shading and Degradation per panel
# -------------------------------------------------------------

classify_panels <- function(data_file,
                            baseline_file = "stats_data.csv",
                            w = 1,
                            k_base = 1.5,
                            z_deg  = 2.0,
                            cv_low = 0.08,
                            cv_high = 0.15) {
  
  # ---- 1) Load data ----
  df <- read.csv(data_file, check.names = FALSE)
  df <- df %>%
    mutate(
      hour = as.numeric(sub(":.*", "", as.character(hour))),
      power = voltage * current
    )
  
  # ---- 2) Load or compute hourly baseline ----
  base <- read.csv(baseline_file, check.names = FALSE) %>%
    select(hour, power_mean, power_sd)
  df <- left_join(df, base, by = "hour")
  
  # ---- 3) Map panels to 10x10 grid ----
  n_rows <- 10; n_cols <- 10
  grid <- expand.grid(row = 1:n_rows, col = 1:n_cols) %>%
    mutate(panel_id = paste0("P", sprintf("%03d", 1:(n_rows*n_cols))))
  df <- left_join(df, grid, by = "panel_id")
  
  # ---- 4) Build neighborhood lookup ----
  pos <- df %>% distinct(panel_id, row, col)
  neigh_pairs <- pos %>%
    rename(row0 = row, col0 = col, panel_id0 = panel_id) %>%
    crossing(pos) %>%
    filter(abs(row - row0) <= w, abs(col - col0) <= w) %>%
    select(panel_id0, neighbor_id = panel_id)
  
  # ---- 5) Compute local neighborhood stats ----
  df_nb <- df %>%
    select(panel_id, hour, power, power_mean, power_sd) %>%
    inner_join(neigh_pairs, by = c("panel_id" = "panel_id0")) %>%
    inner_join(
      df %>% select(panel_id, hour, power) %>%
        rename(neighbor_id = panel_id, hour_nb = hour, power_nb = power),
      by = c("neighbor_id", "hour" = "hour_nb")
    )
  
  local_stats <- df_nb %>%
    group_by(panel_id, hour) %>%
    summarise(
      local_mean = mean(power_nb, na.rm = TRUE),
      local_sd   = sd(power_nb, na.rm = TRUE),
      local_cv   = ifelse(local_mean > 0, local_sd / local_mean, NA_real_),
      .groups = "drop"
    )
  
  # ---- 6) Merge and classify ----
  df2 <- df %>%
    left_join(local_stats, by = c("panel_id", "hour")) %>%
    mutate(
      farm_z   = (power - power_mean) / pmax(power_sd, 1e-6),
      local_z  = (power - local_mean) / pmax(local_sd, 1e-6),
      farm_low = power_mean - k_base * power_sd,
      is_block_low = local_mean < farm_low,
      is_low_var   = local_cv <= cv_low | is.na(local_cv),
      is_high_var  = local_cv >= cv_high,
      condition = case_when(
        is_block_low & is_low_var ~ "shading",
        is_high_var & local_z <= -z_deg ~ "degrading",
        TRUE ~ "functional"
      )
    )
  
  # ---- 7) Continuous severity (0–1 range) ----
  smooth_scale <- function(x) 1 / (1 + exp(-2 * (x - 0.5)))
  
  df2 <- df2 %>%
    mutate(
      raw_shade = (power_mean - local_mean) / (k_base * power_sd + 1e-6),
      raw_degrd = (local_mean - power) / (z_deg * local_sd + 1e-6),
      shade_sev = round(smooth_scale(raw_shade), 3),
      degrd_sev = round(smooth_scale(raw_degrd), 3)
    )
  
  # ---- 8) Aggregate to per-panel summary ----
  panel_summary <- df2 %>%
    group_by(panel_id) %>%
    summarise(
      Shading = mean(ifelse(condition == "shading", shade_sev, 0), na.rm = TRUE),
      Degradation = mean(ifelse(condition == "degrading", degrd_sev, 0), na.rm = TRUE),
      .groups = "drop"
    ) %>%
    arrange(panel_id)
  
  # ---- 9) Export ----
  write.csv(panel_summary, "panel_classification_simple.csv", row.names = FALSE)
  message("✅ Wrote panel_classification_simple.csv")
  
  return(panel_summary)
}
