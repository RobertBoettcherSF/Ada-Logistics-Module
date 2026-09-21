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

## Cold-chain temperature (educational SI)

| Kind | Controlled band (°C) | Sensor start |
|------|----------------------|--------------|
| `Food_Cold` | 0..4 | midpoint 2 °C |
| `Pharma_Cold` | 2..8 | midpoint 5 °C |

`Order_Record.Hold_Temp_C` stores the latest sensor reading. `Sample_Hold_Temp`
updates it, and each `Tick` checks the inclusive band after time advances.
Out-of-band readings set `Cold_Chain_Breached` and status `Cold_Chain_Failed`;
the vehicle is released. The default reading is stable (no automatic drift).
This is an educational simulation, not GDP/pharmacy validation.

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

## Warehouse + Stock (educational SI)

`Logistics_Module.Warehouses` models a hub inventory separately from
`Demand_Cell.Stock_kg`. `Mass_kg` and `Capacity_kg` are kilograms (SI). A
registry is bounded to 16 warehouses; each warehouse has up to 16 cargo-class
slots. `Create_Warehouse`, `Deposit`, `Withdraw`, and `Stock_Of` reject invalid
IDs, non-positive moves, over-capacity deposits, and full slot sets.

| Field | Meaning |
|-------|---------|
| `Mass_kg` | stored cargo mass in kilograms |
| `Capacity_kg` | warehouse aggregate mass limit in kilograms |
| `Warehouse_Location` | `World_Body` plus `City_Id` / `Spaceport_Id` tags |
| `Hold_Temp_C` | optional educational last temperature for a stock slot (°C) |

## Demand_Cells (evolutionary fleet, DS SI)

| Constant | Value |
|----------|-------|
| c_m_s | 299_792_458 |
| AU_m | ≈1.495978707×10¹¹ |
| Max_Beta | 0.01 (relativistic stub) |

### Barge market and generational wealth

`Barge_Pool_Max = 100` and `Barge_Pool_Min = 12` bound the shared pool;
`Barge_Unit_Price = 50,000` and `Initial_Barge_Budget = 1,000,000` are
educational demo coins, not SI money or `Company` cash. `Bid_For_Barge` is the
only `Life_Tick` path that adds a `Barge_Inner`: it rejects bids below the ask,
when poor, or when the pool is exhausted, then moves one barge from available
to owned and charges `Wealth`. `Clamp_Barge_Pool` enforces the 0..100 owned
bound. `End_Generation` increments `Generation` and passes remaining wealth
through `Inherited` to the next generation; owned barges remain family assets.


| Species | Cruise m/s | Cargo kg | Gross kg |
|---------|------------|----------|----------|
| Barge_Inner | 3000 | 1_045_000 | 1_900_000 |
| Fast_Courier | 30_000 | 50_000 | 100_000 |
| Relativistic_Stub | β·c (β≤0.01) | 1000 | 5000 |

`Ship_Class` is the educational alias for the existing `Fleet_Species` type.
World lookup functions retain profile cargo as effective capacity in this thin
stub; they expose the future derating seam without changing tournament math.

| Ship_Class | Terra_0 | Moon_Polar | Mars | Titan | Venus_Cloud_Port |
|------------|---------|------------|------|-------|-------------------|
| Barge_Inner cargo (kg) | 1,045,000 | 1,045,000 | 1,045,000 | 1,045,000 | 1,045,000 |
| Fast_Courier cargo (kg) | 50,000 | 50,000 | 50,000 | 50,000 | 50,000 |
| Relativistic_Stub cargo (kg) | 1,000 | 1,000 | 1,000 | 1,000 | 1,000 |
| Barge_Inner cost factor | 1.0 | 1.0 | 1.5 | 2.0 | 1.3 |
| Fast_Courier cost factor | 0.8 | 1.0 | 1.8 | 2.5 | 1.4 |
| Relativistic_Stub cost factor | 2.0 | 3.0 | 5.0 | 6.0 | 4.0 |

`Cargo_Capacity_kg (S, World)` is the effective payload and
`Cost_Factor (S, World)` is a positive money/effort multiplier. The lookup is
parallel to `Score_kg_s` / `Reward_Coin`; those legacy formulas remain stable.

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

## Cargo compatibility (IRL-inspired, educational)

`Compatible (Cargo_Class, Body_Kind, Dispatch_Mode[, Hazard])` — thin educational
DG wiring, not legal/ADR/IATA text. The hazard-aware overload always applies
`Mode_Allows_Hazard`; Tank cargo may use Air/Space_Haul only with `Hazard = None`.

**Road / Tunnel:** dedicated road body required (`Equip` must match).  
**Rail / Sea / Air / Space_Haul:** `True` means the *mode* can carry that class
with specialized stock; road `Equip` is ignored.  
**Space_Haul:** Container only (game intermodal stub).

| Cargo_Class | Road body | Tunnel | Rail | Sea | Air | Space_Haul | IRL note |
|-------------|-----------|--------|------|-----|-----|------------|----------|
| Silo | Silo | = Road | Yes (hopper) | Yes (bulk) | No | No | Dry bulk |
| Tank | Tank | = Road | Yes (tank car) | Yes (tanker) | Yes* | Yes* | Air/space only with Hazard=None; educational DG stub |
| Lowboy | Lowboy | = Road | Yes (heavy flat) | Yes (RoRo / HL) | No | No | Oversize / plant |
| Reefer | Reefer | = Road | Yes | Yes (reefer box) | Yes (cool cargo) | No | Cold chain |
| Flatbed | Flatbed | = Road | Yes (flatcar) | Yes (breakbulk) | Yes (pallet/ULD) | No | Open deck |
| Container | Container | = Road | Yes | Yes | Yes (ULD) | **Yes** | Intermodal |
| Dry_Box | Dry_Box | = Road | Yes (boxcar) | Yes | Yes | No | Enclosed dry van |

`*` Air/Space tank acceptance is restricted to `Hazard = None`; other hazards
must pass `Mode_Allows_Hazard`, and this model is not ADR/IATA compliance.

Product kinds (`Cargo_Kind`) still use `Allows_Body` then this matrix via
`To_Cargo_Class` (`Food_Cold`/`Pharma_Cold` → Reefer, etc.).

