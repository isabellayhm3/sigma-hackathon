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

## 1. `hourly_stats_array()`

**Description** 
This function computes the hourly summary statistics for voltage, current, and power. 

**Function Call:**
```r
hourly_stats_array(file)

``` 

## I
## Inputs

| **Parameter** | **Type** | **Description** |
|----------------|-----------|-----------------|
| `file` | string | Path to a CSV with `time`, `voltage`, and `current` columns. |

---

### Outputs

