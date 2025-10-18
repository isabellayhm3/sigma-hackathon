# Solar Panel Reliability & Quality Control Dashboard

Our R-based tool analyzes utility-scale solar farm performance to flag **shading** vs **degradation** and assign a **0–1 severity score** per panel per hour. 

---

## Features
- Computes **hourly** mean/SD for voltage, current, and power.
- **Classifies** each panel-hour as `functional`, `shading`, or `degrading`.
- Produces a tidy **CSV** for dashboards and QA.
- Produces a **grid plot** that blends degradation (green-yellow-red) and shading. 

## Installation
1. Clone this repository
2. Open in RStudio or Posit Cloud
3. Run `app.R`

Requires R ≥ 4.2.

```r
install.packages(c(
  "dplyr","tidyr","readr","lubridate","rlang",
  "stringr","purrr","ggplot2"
))

## Project Structure
See `/code` for analysis scripts and `/solar_data1` for example datasets.
