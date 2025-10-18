library(dplyr)
library(readr)
library(tidyr)
library(purrr)

classify_panels <- function(data_file,
                            baseline_file = NULL,
                            w       = 1,
                            k_base  = 1.5,
                            z_deg   = 2.0,
                            cv_low  = 0.08,
                            cv_high = 0.15) {
  
  # ---- 1) Load raw panel data ----
  df <- read.csv(data_file, check.names = FALSE) %>%
    mutate(
      hour = as.numeric(sub(":.*", "", hour)),
      power = voltage * current
    )
  
  # ---- 2) Hourly baseline ----
  if (!is.null(baseline_file)) {
    base <- read.csv(baseline_file, check.names = FALSE) %>%
      mutate(hour = as.numeric(hour)) %>%
      dplyr::select(hour, power_mean, power_sd)
  } else {
    base <- df %>%
      group_by(hour) %>%
      summarise(
        power_mean = mean(power, na.rm = TRUE),
        power_sd   = sd(power, na.rm = TRUE),
        .groups = "drop"
      )
  }
  
  df <- df %>% left_join(base, by = "hour")
  
  # ---- 3) Map panels to 10x10 grid ----
  n_rows <- 10; n_cols <- 10
  grid <- expand.grid(row = 1:n_rows, col = 1:n_cols) %>%
    mutate(panel_id = paste0("P", sprintf("%03d", 1:(n_rows*n_cols))))
  df <- df %>% left_join(grid, by = "panel_id")
  
  # ---- 4) Build neighborhood ----
  pos <- df %>% distinct(panel_id, row, col)
  neigh_pairs <- pos %>%
    rename(row0 = row, col0 = col, panel_id0 = panel_id) %>%
    crossing(pos) %>%
    filter(abs(row - row0) <= w, abs(col - col0) <= w) %>%
    dplyr::select(panel_id0, neighbor_id = panel_id)
  
  df_nb <- df %>%
    dplyr::select(panel_id, hour, power, row, col, power_mean, power_sd) %>%
    inner_join(neigh_pairs, by = c("panel_id" = "panel_id0"), relationship = "many-to-many") %>%
    inner_join(
      df %>% dplyr::select(panel_id, hour, power) %>%
        rename(neighbor_id = panel_id, hour_nb = hour, power_nb = power),
      by = c("neighbor_id", "hour" = "hour_nb")
    )
  
  # ---- 5) Local stats ----
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
      farm_z       = (power - power_mean) / pmax(power_sd, 1e-6),
      local_z      = (power - local_mean) / pmax(local_sd, 1e-6),
      farm_low     = power_mean - k_base * power_sd,
      is_block_low = local_mean < farm_low,
      is_low_var   = local_cv <= cv_low | is.na(local_cv),
      is_high_var  = local_cv >= cv_high
    )
  
  # ---- 6) Classification ----
  df2 <- df2 %>%
    mutate(
      condition = case_when(
        is_block_low & is_low_var          ~ "shading",
        is_high_var & (local_z <= -z_deg) ~ "degrading",
        TRUE                               ~ "functional"
      )
    )
  
  # ---- 7) Compute decimal severity ----
  df2 <- df2 %>%
    mutate(
      shade_sev = (power_mean - local_mean) / (k_base * power_sd + 1e-6),
      degrd_sev = (local_mean - power) / (z_deg * local_sd + 1e-6),
      # clip to 0–1
      shade_sev = pmin(pmax(shade_sev, 0), 1),
      degrd_sev = pmin(pmax(degrd_sev, 0), 1)
    )
  
  # ---- 8) Aggregate per panel keeping decimals ----
  panel_sev <- df2 %>%
    group_by(panel_id) %>%
    summarise(
      degradation = max(ifelse(condition == "degrading", degrd_sev, 0), na.rm = TRUE),
      shading     = max(ifelse(condition == "shading", shade_sev, 0), na.rm = TRUE),
      .groups = "drop"
    ) %>%
    arrange(panel_id)
  
  # ---- 9) Write CSV ----
  write.csv(panel_sev, "panel_classification_simple.csv", row.names = FALSE)
  message("✅ Wrote panel_classification_simple.csv")
  
  return(panel_sev)
}
