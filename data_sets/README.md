# Dataset Documentation

We provide three synthetic datasets for testing and demonstration.

## File Overview 

| File Name | Description | Expected Classification Behavior |
|------------|--------------|----------------------------------|
| `solar_data_normal.csv` | Baseline “healthy” solar farm data. Panels perform consistently throughout the day with minor random noise. | All panels should be classified as **functional** for nearly all hours. |
| `solar_data_shading.csv` | Simulates a **shading event** where a 3×4 block of panels (P011–P014, P021–P024, P031–P034) experiences reduced power output from 08:00–10:00. | Panels in the shaded block should be labeled as **shading** during affected hours, then return to **functional**. |
| `solar_data_degraded.csv` | Simulates a **degradation issue** where a single panel (P078) gradually loses efficiency throughout the day, reducing power by 25% by 16:00. | Panel P078 should be labeled as **degrading** for multiple hours; other panels remain **functional**. |

---

## Common Structure

All datasets share the same schema:

| Column | Type | Units | Description |
|---------|------|--------|-------------|
| `panel_id` | string | — | Unique panel identifier (`P001`–`P100`) arranged in a 10×10 grid. |
| `hour` | string | hours:minutes | Local farm time in hourly increments (`0:00`, `1:00`, …, `23:00`). |
| `voltage` | double | volts (V) | Voltage output of each panel at the given hour. |
| `current` | double | amperes (A) | Current output of each panel at the given hour. |

Additional derived columns (computed by the tool):
- `power = voltage * current`

---


