library(dplyr)
library(stringr)
library(tidyr)
library(purrr)

# -------------------------------------------------------------
# classify_panels():
#   data_file ........ raw data CSV (panel_id, time, voltage, current)
#   baseline_file .... optional hourly baseline CSV from hourly_stats_array()
#   w ................ neighborhood radius in grid cells (1 => 3x3 window)
#   k_base ........... how far below hourly baseline to consider "low" (in SD)
#   z_deg ............ how far below local mean to consider panel degraded (in SD)
#   cv_low ........... max local CV for shading (low-variance neighborhood)
#   cv_high .......... min local CV for degradation (high-variance neighborhood)
# Returns: CSV with per-panel shading and degradation values (0–1)
# -------------------------------------------------------------

classify_panels <- function(data_file,
                            baseline_file = NULL,
                            w       = 1,
                            k_base  = 1.5,
                            z_deg   = 2.0,
                            cv_low  = 0.08,
                            cv_high = 0.15) {
  
  # ---- 1️⃣ Load & prepare data ----
  df <- read.csv(data_file, check.names = FALSE)
  df <- df %>%
    mutate(
      hour   = as.numeric(str_extract(time, "^\\d+")),
      power  = voltage * current
    )
  
  # ---- 2️⃣ Hourly baseline ----
  if (!is.null(baseline_file)) {
    base <- read.csv(baseline_file) %>%
      select(hour, power_mean, power_sd)
  } else {
    base <- df %>%
      group_by(hour) %>%
      summarise(power_mean = mean(power, na.rm = TRUE),
                power_sd   = sd(power, na.rm = TRUE),
                .groups = "drop")
  }
  df <- df %>% left_join(base, by = "hour")
  
  # ---- 3️⃣ Assign 10x10 grid positions ----
  n_rows <- 10; n_cols <- 10
  grid <- expand.grid(row = 1:n_rows, col = 1:n_cols) %>%
    mutate(panel_id = paste0("P", sprintf("%03d", 1:(n_rows * n_cols))))
  df <- df %>% left_join(grid, by = "panel_id")
  
  # ---- 4️⃣ Build neighborhood pairs (Chebyshev radius w) ----
  pos <- df %>% distinct(panel_id, row, col)
  neigh_pairs <- pos %>%
    rename(row0 = row, col0 = col, panel_id0 = panel_id) %>%
    crossing(pos) %>%
    filter(abs(row - row0) <= w, abs(col - col0) <= w) %>%
    select(panel_id0, neighbor_id = panel_id)
  
  df_nb <- df %>%
    select(panel_id, hour, power, row, col, power_mean, power_sd) %>%
    inner_join(neigh_pairs, by = c("panel_id" = "panel_id0")) %>%
    inner_join(df %>% select(panel_id, hour, power) %>%
                 rename(neighbor_id = panel_id, hour_nb = hour, power_nb = power),
               by = c("neighbor_id", "hour" = "hour_nb"))
  
  # ---- 5️⃣ Local neighborhood statistics ----
  local_stats <- df_nb %>%
    group_by(panel_id, hour) %>%
    summarise(
      local_mean = mean(power_nb, na.rm = TRUE),
      local_sd   = sd(power_nb, na.rm = TRUE),
      .groups = "drop"
    ) %>%
    mutate(local_cv = ifelse(local_mean > 0, local_sd / local_mean, NA_real_))
  
  df2 <- df %>%
    left_join(local_stats, by = c("panel_id", "hour")) %>%
    mutate(
      farm_z   = (power - power_mean) / pmax(power_sd, 1e-6),
      local_z  = (power - local_mean) / pmax(local_sd, 1e-6),
      farm_low = power_mean - k_base * power_sd,
      is_block_low = local_mean < farm_low,
      is_low_var  = local_cv <= cv_low | is.na(local_cv),
      is_high_var = local_cv >= cv_high
    )
  
  # ---- 6️⃣ Classify each observation ----
  df2 <- df2 %>%
    mutate(
      condition = case_when(
        is_block_low & is_low_var          ~ "shading",
        is_high_var & (local_z <= -z_deg)  ~ "degrading",
        TRUE                               ~ "functional"
      )
    )
  
  # ---- 7️⃣ Compute severity values ----
  clamp01 <- function(x) pmin(pmax(x, 0), 1)
  df2 <- df2 %>%
    mutate(
      shade_sev = clamp01((power_mean - local_mean) / pmax(k_base * power_sd, 1e-6)),
      degrd_sev = clamp01((local_mean - power)     / pmax(z_deg  * local_sd,  1e-6))
    )
  
  # ---- 8️⃣ Summarize per panel ----
  summary_df <- df2 %>%
    group_by(panel_id) %>%
    summarise(
      Shading     = mean(ifelse(condition == "shading", shade_sev, 0), na.rm = TRUE),
      Degradation = mean(ifelse(condition == "degrading", degrd_sev, 0), na.rm = TRUE),
      .groups = "drop"
    )
  
  # ---- 9️⃣ Export clean summary CSV ----
  output_csv <- "panel_condition_summary.csv"
  write.csv(summary_df, output_csv, row.names = FALSE)
  message(sprintf("✅ Wrote %s", output_csv))
  
  return(summary_df)
}
