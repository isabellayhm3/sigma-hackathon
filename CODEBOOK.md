# Codebook - Solar Panel Reliability & Quality Control Shiny App 

This codebook describes all major R scripts and functions included in the repository.  
It also lists each function’s purpose, inputs, outputs, and dependencies to ensure full reproducibility and clarity for users.

## Overview of Scripts

| Script | Purpose | Key Output |
|--------|----------|-------------|
| `calculate_stats.R` | Computes hourly statistics for voltage, current, and power across all panels. | `hourly_stats_results.csv` |
| `classify_panels.R` | Detects **shading** and **degradation** patterns using z-scores and neighborhood variance. | `panel_classification_with_severity.csv` |
| `plot_panel_map.R` | Creates a color-coded grid visualization of shading and degradation severity. | `panel_map_hourX.png` |
| `plot_xbarbar.R` | Plots the average hourly mean power (\(\bar{X}\)\_bar) across all panels for visual QC. | Interactive or static line plot |
| `app.R` | Shiny dashboard that allows users to upload data, compute statistics, classify panels, and visualize results interactively. | Browser-based interface |

## 1) `calculate_performance()`  *(defined in `code/calculate_performance.R`)*

**Description** 
fix this 

**Function Call:**
```r
hourly_stats_array(file)

```
### Inputs

| **Parameter** | **Type** | **Description** |
|----------------|-----------|-----------------|
| `data_file` | string (filepath) |  Path to a CSV containing columns `panel_id`, `hour`, `voltage`, `current`. |

### Outputs

| **File** | **Description** |
| ------------------------------------ | ------------------- |
| `panel_hourly_performance_sigma.csv` | Hour-by-hour normalized performance (0–1 scale) for each panel. |
| `panel_daily_average_sigma.csv`| Average normalized power per panel (daily mean).|

### Key Columns in Output Files 

| **Column**                      | **Description** |
| ------------------------------- | ---------- |
| `panel_id`                      | Unique panel identifier |
| `hour`                          | Hour of the day (6–18) |
| `voltage`, `current`, `power`   | Raw readings and computed power  |
| `mean_power`, `sd_power`        | Hourly group mean and SD of power                           |
| `norm_power`                    | Six Sigma normalized performance (0–1, where 1 = excellent) |
| `avg_power` *(daily file only)* | Daily average normalized power per panel                    |

---

## 5) `plot_panel_map()`  *(defined in `code/plot_panel_map.R`)*

**Description**  
Renders a grid heatmap of the solar array where each tile is a panel (`P001`…`P100`).  
Color encodes a chosen performance metric (default `avg_power`) on a **0–1** scale  
(low = red, mid = yellow, high = green).

--- 

**Function Call**
```r
plot_panel_map(panel_data,
               nrows = 10,
               total_panels = 100,
               value_col = "avg_power",
               title = "Solar Panel Performance")

```

| **Parameter**  | **Type**   | **Required**               | **Description**                                                                    |
| -------------- | ---------- | -------------------------- | ---------------------------------------------------------------------------------- |
| `panel_data`   | data frame | Yes                        | Must include `panel_id` (`P001`…`P###`) and a numeric column named by `value_col`. |
| `nrows`        | integer    | No (default 10)            | Number of rows in the farm grid.                                                   |
| `total_panels` | integer    | No (default 100)           | Total number of panels (used to compute columns).                                  |
| `value_col`    | string     | No (default `"avg_power"`) | Name of the column to visualize (0–1 recommended).                                 |
| `title`        | string     | No                         | Plot title shown above the map.                                                    |


