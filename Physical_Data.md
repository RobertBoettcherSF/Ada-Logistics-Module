# Physical Data (Logistics Module)

Ops-owned SI numbers for EU vehicle classes. Unit names match Ada:
`Mass_Kilograms`, `GVW_Kilograms`, `Footprint_Length_m`, `Footprint_Width_m`.

Inspired by EU vehicle categories VO 2018/858 (clean-room category structure only).

## GVW class limits (goods)

| Class | GVW limit (kg) | Notes |
|-------|----------------|-------|
| N1 | 3_500 | max |
| N2 | 12_000 | max |
| N3 | 40_000 | typical artic check cap (not a legal maximum) |
| O2 | 3_500 | trailer stub |
| O4 | 40_000 | trailer stub |

M1 has **no** N-style goods GVW band — passenger cars use size tags below.

## M1 size tags (`EU_Class_M1`)

| Tag | Curb (kg) | GVW (kg) | L×W (m) | Area ≈ m² |
|-----|-----------|----------|---------|-----------|
| Car_Small | 1_100 | 1_400 | 4.0×1.7 | ~6.8 |
| Car_Medium | 1_500 | 2_000 | 4.6×1.8 | ~8.3 |
| Car_Large | 2_200 | 3_000 | 5.0×2.0 | ~10 |

## Lorry profiles

| Profile | Class | Curb | GVW | L×W (m) | Area ≈ |
|---------|-------|------|-----|---------|--------|
| Lorry_Rigid | N2/N3 by GVW | 8_000 | 18_000 | 8.0×2.5 | ~20 |
| Lorry_Artic | N3 | 15_000 | 40_000 | 16.5×2.55 | — |
| Van_N1 | N1 | 2_000 | 3_500 | 5.5×2.0 | — |

## Kind → EU map (v0)

| `Vehicle_Kind` | `EU_Vehicle_Class` |
|----------------|--------------------|
| Light_Van | N1 |
| Rigid | N2 if GVW ≤ 12_000, else N3 |
| Artic_Tractor | N3 |
| Trailers (stub) | O2 if GVW ≤ 3_500, else O4 |

## Contracts

- `GVW >= Curb_Mass` (`Masses_Valid` / `Make_Physical` Pre).
- Capacity / add checks use `Within_GVW_Class_Limit` for N1/N2/N3/O2/O4.


## Haul ambient lean (`Haul_Mode`)

Ops-owned SI lean for transport environments (not legal / medical limits).

| Mode | Cabin kPa | Ext kPa | g | Rad µSv/h |
|------|-----------|---------|---|-----------|
| Road | 101 | 101 | 1 | ~0.1 |
| Tunnel (sealed) | 101 | 101 | 1 | ~0.05–0.2 |
| Space_Haul | 101 | 0 | 0 (or field) | coast ~50–100 |

See `Ambient_Road`, `Ambient_Tunnel`, `Ambient_Space_Haul` in Ada.

## Hazard premium table

| Band | Factor | Hazard_Class map (lean) |
|------|--------|-------------------------|
| None | 1.0 | `None` |
| Low | 1.2 | `Misc_Dangerous` |
| Mid | 2.0 | Flammable liquids/solids, Oxidizers |
| High | 4.0 | Gases, Toxic_Infectious, Corrosive |
| Extreme | 10.0 | Explosives, Radioactive |

Extreme mode extras (compose): Space_Haul ×1.5 → **15.0**; Tunnel ×1.2 → **12.0**.

## Cover leg factors

| Cover_Kind | Factor |
|------------|--------|
| Cargo_Loss | 1.0 |
| Hull_Loss | 0.6 |
| Crew_Loss | 0.8 |
| Crew_Sick | 0.25 |
| Emergency_Leave | 0.10 |

`Total_Premium_Factor` = sum(selected legs) × `Premium_Factor(Hazard, Mode)`.

## Haul speeds (MVP play)

| Haul_Mode | Speed (m/s) |
|-----------|-------------|
| Road | 22 |
| Tunnel | 30 |
| Space_Haul | 3000 |

`ETA_s = Distance_m / Speed_m_s`. Sim time: wall Δt × `Time_Rate` (default 1.0).


## World_Body / spaceport SI (lean)

| World_Body | Alt m | Ext P kPa | T °C | g | Atmos | Flags |
|------------|-------|-----------|------|---|-------|-------|
| Venus_Cloud_Port | 50_000 | ≈101 | 60–75 | ≈0.90 | CO2 | Has_Spaceport, Float_Pad |
| Moon_Polar | 0 | 0 | cold | ≈0.17 | Vacuum | high rad, Relay |
| Mars | 0 | ≈0.6 | surface | ≈0.38 | Thin_CO2 | many Spaceport_Ids |
| Titan | 0 | ≈146.7 | ≈−180 | ≈0.14 | N2_CH4 | many pads |

Pad_Reconcrete: landing Mass/GVW > Pad_Limit_kg → Cracked; Space_Haul blocked until Reconcrete_Hours (Tick advances repair).

## Demand_Cells (evolutionary fleet, DS SI)

| Constant | Value |
|----------|-------|
| c_m_s | 299_792_458 |
| AU_m | ≈1.495978707×10¹¹ |
| Max_Beta | 0.01 (relativistic stub) |

| Species | Cruise m/s | Cargo kg | Gross kg |
|---------|------------|----------|----------|
| Barge_Inner | 3000 | 1_045_000 | 1_900_000 |
| Fast_Courier | 30_000 | 50_000 | 100_000 |
| Relativistic_Stub | β·c (β≤0.01) | 1000 | 5000 |

Pre: `Cruise_Speed_m_s < c_m_s`.

`Throughput = Count × Cargo / (2 × Distance / Cruise)`;
`Fitness = Throughput / (Ship_Count × Gross_Mass_kg)`.
`Life_Tick`: under-served → spawn/prefer higher Fitness; over-served → cull lower.
Each tick appends `sim_run.csv`: comment `# run_id=…` then header
`t_s,cell_id,…,beta,c_m_s`; one row per cell×species.

## ATC corridors (lean SI, separate from Fitness)

| Haul_Mode | Separation_m | Lane_Capacity |
|-----------|--------------|---------------|
| Road | 100 | floor(Distance_m / Separation_m), ≥ 1 |
| Tunnel | 50 | floor(Distance_m / Separation_m), ≥ 1 |
| Space_Haul | ≥ 50_000 | min(8, floor(Distance_m / Separation_m)), ≥ 1 |

`Min_Slot_Spacing_s = Separation_m / Cruise_Speed_m_s` (docs/tests).

Assign gate: `Fleet_In_Flight >= Lane_Capacity` → `Rejected_ATC` / reject.
`sim_run.csv` logs `Fleet_In_Flight`, `Lane_Capacity`, `Assign_Rejected`.


## Hub positions (SI)

Origin `Terra_0` at `Position_m (0,0,0)`. `Distance_m` = Euclidean norm.
Lean stubs: `Moon_Polar` ≈ 3.84×10⁸ m; `Mars` ≈ 2.25×10¹¹ m; Venus/Titan AU-scale.

## Consumables

| Constant | Value |
|----------|-------|
| Consumables_kg_person_day | 2.5 |
| Crew_150 | 150 |
| Demand_Rate_kg_s | Crew × kg/day / 86400 |
| Min_Cruise_Speed_m_s | Demand × 2 × Distance / Cargo |

See also [SI_Units.md](SI_Units.md) (shared Ada naming pattern).

## Tournament score (fuel-adjusted)

| Symbol | Formula |
|--------|---------|
| Fuel_Mass_kg | Fuel_Coeff_kg × (Cruise_Speed_m_s / Speed_Ref_m_s)² |
| Payload_Net_kg | max(0, Cargo_Mass_kg − Fuel_Mass_kg) |
| Score_kg_s | Payload_Net_kg / Transit_Duration_s (one-way; optional RT ÷2) |
| Reward_Coin | 1.00 × (Score_kg_s / Score_Ref_kg_s) |
| Fuel_Coeff_kg | 50_000 (lean) |
| Speed_Ref_m_s | Barge_Inner cruise (3000) |

Score_Ref from Barge_Inner at ref distance. Cruise still < c. Extreme speed can lower Score vs mid due to fuel.

`Life_Tick` (evo) and `Run_Tournament_Ticks` both write `Fuel_Mass_kg`, `Payload_Net_kg`, `Score_kg_s`, `Reward_Coin` into `sim_run.csv` for SI-audit.
