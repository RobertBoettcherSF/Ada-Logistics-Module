# Ada Logistics Module

Clean-room **Ada 2022** logistics / forwarding library (Step 1).
Inspired by the public logistics-sim genre only.

**No proprietary assets, names, formulas, manual text, or legal regulatory copy.**

## Domain model

| Concept | Our encoding |
|---------|----------------|
| **Freight_Units (FE)** | `Natural` — not mixed SI |
| **Vehicle_Kind** | `Light_Van`, `Rigid`, `Artic_Tractor` (alone = **0 FE**) |
| **Body_Kind** | `Silo`, `Tank`, `Reefer`, `Flatbed`, `Container`, `Lowboy` |
| **EU_Vehicle_Class** | `M1`–`M3`, `N1`–`N3`, `O1`–`O4` — inspired by EU vehicle categories VO 2018/858 |
| **EU_Class_M1** | `Car_Small`, `Car_Medium`, `Car_Large` (passenger size tags) |
| **Physical** | `Mass_Kilograms`, `GVW_Kilograms`, `Footprint_Length_m`, `Footprint_Width_m` — see [Physical_Data.md](Physical_Data.md), [SI_Units.md](SI_Units.md) |
| **Cargo_Class** | Silo / Tank / Lowboy / Reefer / Flatbed / Container / Dry_Box |
| **Cargo_Kind** | `Food_Dry`, `Food_Cold`, `Cosmetics`, `Pharma_Cold` (density / T / hazard lean) |
| **Position_m** | Hub SI `(X,Y,Z)`; origin `Terra_0` |
| **Dispatch_Mode** | `Road`, `Rail`, `Sea`, `Air`, `Space_Haul`, `Tunnel` |
| **Haul_Mode** | `Road`, `Tunnel`, `Space_Haul` — ambient + insurance |
| **City** | `Has_Rail`; optional airport, port, **spaceport**, **tunnel** |
| **Hazard_Class** | ADR-inspired lean 1–9 + `None` (clean-room labels) |
| **Hazard_Premium_Band** | `None`/`Low`/`Mid`/`High`/`Extreme` + `Premium_Factor` |
| **Cover_Kind** | `Cargo_Loss`, `Hull_Loss`, `Crew_Loss`, `Crew_Sick`, `Emergency_Leave` |
| **Placard_Code** | 8-char data field (orange-plate style; no graphics) |

### Cargo ↔ mode (`Compatible`)

Full matrix (IRL-inspired): [Physical_Data.md](Physical_Data.md) § Cargo compatibility.

| Cargo | Road Equip | Rail | Sea | Air | Space |
|-------|------------|------|-----|-----|-------|
| Silo | Silo | ✓ | ✓ | ✗ | ✗ |
| Tank | Tank | ✓ | ✓ | ✗ | ✗ |
| Lowboy | Lowboy | ✓ | ✓ | ✗ | ✗ |
| Reefer | Reefer | ✓ | ✓ | ✓ | ✗ |
| Flatbed | Flatbed | ✓ | ✓ | ✓ | ✗ |
| Container | Container | ✓ | ✓ | ✓ | ✓ |
| Dry_Box | Dry_Box | ✓ | ✓ | ✓ | ✗ |

Tunnel uses the same Equip rule as Road. On non-road modes, Equip is ignored
(mode owns specialized stock).

### Space_Haul ≅ Air

`Space_Haul` uses the same facility pattern as `Air` (`Has_Spaceport` at both
ends). Step-1 cargo: **Container only**. `Space_Cost_Factor` /
`Space_Time_Factor` are higher than an air baseline (stubs for later costing).

### Tunnel

`Tunnel` requires `Has_Tunnel` at both ends. Cargo uses the same EU road fleet
rules as `Road` (body / FE / ADR). Cities may set lean `Tunnel_Fire_Vent_Risk`.

### Dangerous goods (Step-1)

- Order carries `Hazard_Class` + optional `Placard_Code`.
- **Road / Tunnel** hazardous: `Vehicle_ADR_Approved`, active **Driver** with
  `Driver_Has_ADR_Cert`, and **Tank** body when `Requires_Tank_Body`
  (`Gases`, `Flammable_Liquids`).
- **Air / Space_Haul** allow-list: **deny** `Explosives` and `Radioactive` by
  default (`Mode_Allows_Hazard`).

### Hazard insurance premiums

`Band_Of` maps `Hazard_Class` → `Hazard_Premium_Band`. Fixed-point type `Premium_Multiplier` (delta 0.001). Table factors
(`Base_Band_Factor`): None **1.0**, Low **1.2**, Mid **2.0**, High **4.0**,
Extreme **10.0**. On **Extreme** only, mode extras compose:
`Space_Haul` ×1.5, `Tunnel` ×1.2, `Road` ×1.0
(`Premium_Factor (Hazard, Mode)`).

Cover legs (`Cover_Kind`) add-on factors: Cargo_Loss **1.0**, Hull_Loss **0.6**,
Crew_Loss **0.8**, Crew_Sick **0.25**, Emergency_Leave **0.10**.

**Composition (documented):**
`Total_Premium_Factor = Selected_Cover_Sum(legs) × Premium_Factor(Hazard, Mode)`
— sum selected legs first, then multiply by hazard×mode.

Optional `Claim_Event` stubs: `Claim_Cargo_Lost`, `Claim_Hull_Lost`,
`Claim_Crew_Lost`, `Claim_Crew_Sick`, `Claim_Emergency_Leave`.

Also: staff roles, cash + reputation, offers / `Accept_Offer`, maintain,
rail schedule-slot stub.

### EU classes (v0)

Kind map: `Light_Van`→`N1`, `Rigid`→`N2`/`N3` by GVW, `Artic_Tractor`→`N3`,
trailers→`O2`/`O4` stubs. Contracts: `GVW >= Curb_Mass`; goods capacity checks
use class GVW limits (`N3` check cap 40_000 kg documented in Physical_Data).

### Spaceports / Pad_Reconcrete

`World_Body` profiles (Venus_Cloud_Port, Moon_Polar, Mars, Titan) feed a spaceport
catalog. Overweight landing (`Pad_Reconcrete`) cracks a pad and blocks `Space_Haul`
until repair hours elapse under `Tick`.

### Demand_Cells (child package)

Evolutionary fleet (DS SI): `c_m_s`, `AU_m`; species `Barge_Inner` /
`Fast_Courier` / `Relativistic_Stub` (β≤0.01); cruise &lt; c; Fitness =
Throughput/(ships×gross); `Life_Tick` spawn/prefer/cull by Fitness; appends `sim_run.csv` (cell×species SI rows).

### ATC (child package) — separate from Fitness

Lean air/space traffic control SI (not mixed with evolutionary Fitness):

| Field | Meaning |
|-------|---------|
| `Lane_Id` / corridor | Between cities or spaceports |
| `Lane_Capacity` | Positive — max ships in flight on that lane |
| `Separation_m` | Lean minimum separation |
| `Fleet_In_Flight` | Current occupied slots |
| `Assign_Rejected` | Count of capacity rejects |

**LOCK defaults:** Space_Haul `Separation_m` ≥ **50_000**, `Lane_Capacity` hard cap **8** (or `floor(Distance/Separation)` capped at 8). Road `Separation_m` **100**, Tunnel **50**; capacity from corridor length. Optional `Min_Slot_Spacing_s = Separation_m / Cruise_Speed_m_s`.

On `Assign_On_Lane` / spawn: if `Fleet_In_Flight(lane) >= Lane_Capacity` → reject (`Rejected_ATC` or `ATC_Capacity_Exceeded`). `sim_run.csv` columns: `Fleet_In_Flight`, `Lane_Capacity`, `Assign_Rejected`.

## Build

The repository follows the Ada-ADAMS layout: Ada library units are in `src/`,
and the test main is in `tests/`. The Makefile is the primary build entry point.

```bash
make test   # compile and run the test suite
make play   # Text_IO MVP: jobs / assign / tick
make clean  # remove generated obj/ and bin/ directories
```

The test and play builds use `-gnatwa -gnat2022 -gnata`.

### MVP play loop

1. List / seed jobs  2. Assign vehicle → `En_Route`, `ETA_s = Distance_m / Speed`
3. Tick: wall Δt × `Time_Rate` → `Elapsed_s`; deliver when `Elapsed_s >= ETA_s`
4. Menu: `[j]obs [a]ssign [t]/Enter tick [r]ate [s]paceports [e]vo [u]ourney [q]uit`


## License

MIT — see [LICENSE](LICENSE).
