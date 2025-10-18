library(dplyr)
library(stringr)
library(tidyr)
library(purrr)

# -------------------------------------------------------------
# classify_panels():
#   data_file ........ raw data CSV (panel_id, time, voltage, current)
#   baseline_file .... optional hourly baseline CSV produced by your
#                      hourly_stats_array() with columns:
#                      hour, power_mean, power_sd
#   w ................ neighborhood radius in grid cells (1 => 3x3 window)
#   k_base ........... how far below hourly baseline to consider "low" (in SD)
#   z_deg ............ how far below local mean to consider panel degraded (in SD)
#   cv_low ........... max local CV for shading (low-variance neighborhood)
#   cv_high .......... min local CV for degradation (high-variance neighborhood)
# returns: data.frame with per-panel-hour classification + severity in [0,1]
# -------------------------------------------------------------
classify_panels <- function(data_file,
                            baseline_file = NULL,
                            w       = 1,
                            k_base  = 1.5,
                            z_deg   = 2.0,
                            cv_low  = 0.08,
                            cv_high = 0.15) {
  
  # ---- 1) Load & prep data ----
  df <- read.csv(data_file, check.names = FALSE)
  df <- df %>%
    mutate(
      hour   = as.numeric(str_extract(time, "^\\d+")),
      power  = voltage * current
    )
  
  # ---- 2) Hourly baseline (farm-level mean/sd) ----
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
  
  # ---- 3) Map panels to a 10x10 grid (row-wise P001..P100) ----
  n_rows <- 10; n_cols <- 10
  grid <- expand.grid(row = 1:n_rows, col = 1:n_cols) %>%
    mutate(panel_id = paste0("P", sprintf("%03d", 1:(n_rows*n_cols))))
  df <- df %>% left_join(grid, by = "panel_id")
  
  # ---- 4) Build neighborhood for each panel (Chebyshev radius w) ----
  # Create a lookup of positions, then self-join by hour with |dr|<=w & |dc|<=w
  pos <- df %>% distinct(panel_id, row, col)
  neigh_pairs <- pos %>%
    rename(row0 = row, col0 = col, panel_id0 = panel_id) %>%
    crossing(pos) %>%
    filter(abs(row - row0) <= w, abs(col - col0) <= w) %>%
    select(panel_id0, neighbor_id = panel_id)
  
  # Join neighborhoods by hour so stats are per-time
  df_nb <- df %>%
    select(panel_id, hour, power, row, col, power_mean, power_sd) %>%
    inner_join(neigh_pairs, by = c("panel_id" = "panel_id0")) %>%
    # pull neighbor power at same hour
    inner_join(df %>% select(panel_id, hour, power) %>%
                 rename(neighbor_id = panel_id, hour_nb = hour, power_nb = power),
               by = c("neighbor_id", "hour" = "hour_nb"))
  
  # ---- 5) Compute local (neighborhood) stats per panel-hour ----
  local_stats <- df_nb %>%
    group_by(panel_id, hour) %>%
    summarise(
      local_mean = mean(power_nb, na.rm = TRUE),
      local_sd   = sd(power_nb, na.rm = TRUE),
      .groups = "drop"
    ) %>%
    mutate(local_cv = ifelse(local_mean > 0, local_sd / local_mean, NA_real_))
  
  df2 <- df %>%
    left_join(local_stats, by = c("panel_id","hour")) %>%
    mutate(
      # deviations relative to farm baseline and local neighborhood
      farm_z   = (power - power_mean) / pmax(power_sd, 1e-6),
      local_z  = (power - local_mean) / pmax(local_sd,  1e-6),
      # "low neighborhood mean" test for shading
      farm_low = power_mean - k_base * power_sd,          # hourly low threshold
      is_block_low = local_mean < farm_low,               # neighborhood depressed
      # variance tests
      is_low_var  = local_cv <= cv_low | is.na(local_cv), # tightly clustered
      is_high_var = local_cv >= cv_high                   # spread out
    )
  
  # ---- 6) Classification logic ----
  df2 <- df2 %>%
    mutate(
      condition = case_when(
        # SHADING: neighborhood mean low vs hourly baseline AND neighbors similar (low CV)
        is_block_low & is_low_var                    ~ "shading",
        # DEGRADING: neighborhood variance high AND this panel is far below its neighbors
        is_high_var & (local_z <= -z_deg)            ~ "degrading",
        TRUE                                         ~ "functional"
      )
    )
  
  # ---- 7) Severity score in [0,1], where 1 = worst ----
  # Shading severity = how far the local mean is below hourly baseline (scaled by k_base SD)
  # Degradation severity = how far this panel is below its local mean (scaled by z_deg SD)
  # Functional severity = small residual based on farm_z drop, otherwise 0
  clamp01 <- function(x) pmin(pmax(x, 0), 1)
  
  df2 <- df2 %>%
    mutate(
      shade_sev = clamp01((power_mean - local_mean) / pmax(k_base * power_sd, 1e-6)),
      degrd_sev = clamp01((local_mean - power)     / pmax(z_deg  * local_sd,  1e-6)),
      func_sev  = clamp01((power_mean - power)     / pmax(0.5 * power_sd,     1e-6)) * 0.2,
      severity  = case_when(
        condition == "shading"    ~ shade_sev,
        condition == "degrading"  ~ degrd_sev,
        TRUE                      ~ func_sev
      )
    )
  
  # Tidy output
  out <- df2 %>%
    select(panel_id, time, hour, row, col,
           voltage, current, power,
           power_mean, power_sd, local_mean, local_sd, local_cv,
           farm_z, local_z,
           condition, severity) %>%
    arrange(hour, panel_id)
  
  # Save for downstream (dashboard)
  write.csv(out, "panel_classification_with_severity.csv", row.names = FALSE)
  message("✅ Wrote panel_classification_with_severity.csv")
  
  out
}

# ---- Example call ----
# out <- classify_panels("solar_data.csv",
#                        baseline_file = "hourly_stats_results.csv",
#                        w = 1, k_base = 1.5, z_deg = 2.0,
#                        cv_low = 0.08, cv_high = 0.15)
