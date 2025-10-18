# Solar Panel Reliability & Quality Control Dashboard

Our R-based tool analyzes utility-scale solar farm performance to flag **shading** vs **degradation** and assign a **0–1 severity score** per panel per hour. 

---
## Demonstration Video


## Features
- Computes **hourly** mean/SD for voltage, current, and power.
- **Classifies** each panel-hour as `functional`, `shading`, or `degrading`.
- Produces a tidy **CSV** for dashboards and QA.
- Produces a **grid plot** that blends degradation (green-yellow-red) and shading. 

## Datasets
This dashboard comes with 3 generated datasets, spanning 24 hours with 100 panels in 10 rows. The voltage and current follow the expected trend of solar radiation available at the time of day.

| Variable | Type    | Description                        |
|------------|---------|------------------------------------|
| panel_id   | string  | ID of the solar panel (e.g., P001) |
| hour       | string  | Hour of the day (0:00–23:00)       |
| voltage    | numeric | Voltage measured (V)               |
| current    | numeric | Current measured (A)               |

1. solar_data_norm: Dataset of a fully operational farm within normal performance expectations.
2. solar_data_degradation: Dataset of a few panels that show less than expected performance
3. solar_data_shading: Dataset showing lessened performance due to an object blocking out light. 

## Installation
1. Clone this repository
2. Open in RStudio or Posit Cloud
3. Run `app.R`


Requires R

```r
install.packages(c(
  "dplyr","tidyr","tidyverse","readr","lubridate","rlang",
  "stringr","purrr","ggplot2","shiny"
))

## Project Structure
See `/code` for analysis scripts and `/data_sets` for example datasets.

---



