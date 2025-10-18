# Dataset Documentation

We provide three small, synthetic datasets for testing and demonstration.

## Files

1. **`solar_small.csv`** – Clean reference day with minor noise.
   - 100 panels × 24 hours = 2400 rows.
   - Expect almost all `functional`.

2. **`solar_shaded_block.csv`** – Block shading scenario.
   - Panels: P011–P014, P021–P024, P031–P034 shaded **08:00–10:00** by −35% power.
   - Expect `shading` for those panels during 08–10, otherwise `functional`.

3. **`solar_degraded_panel.csv`** – Single degrading panel.
   - Panel: `P078` linearly degrades from 0% at 06:00 to −25% at 16:00.
   - Expect `degrading` many hours for `P078`.
  
### Columns
All share the schema in **CODEBOOK.md**: `panel_id,time,voltage,current`.


