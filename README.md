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
| **Cold-chain** | Controlled `Food_Cold` / `Pharma_Cold` bands sampled in °C each `Tick` |

### Cargo ↔ mode (`Compatible`)

Full matrix (IRL-inspired): [Physical_Data.md](Physical_Data.md) § Cargo compatibility.

| Cargo | Road Equip | Rail | Sea | Air | Space |
|-------|------------|------|-----|-----|-------|
| Silo | Silo | ✓ | ✓ | ✗ | ✗ |
| Tank | Tank | ✓ | ✓ | ✓* | ✓* |
| Lowboy | Lowboy | ✓ | ✓ | ✗ | ✗ |
| Reefer | Reefer | ✓ | ✓ | ✓ | ✗ |
| Flatbed | Flatbed | ✓ | ✓ | ✓ | ✗ |
| Container | Container | ✓ | ✓ | ✓ | ✓ |
| Dry_Box | Dry_Box | ✓ | ✓ | ✓ | ✗ |

`*` Tank on Air/Space_Haul is allowed only with `Hazard => None`; hazardous
liquids/gases do not fly in this educational stub. Rail/Sea tank stock accepts
all hazards permitted by `Mode_Allows_Hazard`. Tunnel uses the same Equip rule
as Road. On non-road modes, Equip is ignored (mode owns specialized stock).

### Space_Haul ≅ Air

`Space_Haul` uses the same facility pattern as `Air` (`Has_Spaceport` at both
ends). Step-1 cargo: **Container only**. `Space_Cost_Factor` /
`Space_Time_Factor` are higher than an air baseline (stubs for later costing).

### Tunnel

`Tunnel` requires `Has_Tunnel` at both ends. Cargo uses the same EU road fleet
rules as `Road` (body / FE / ADR). Cities may set lean `Tunnel_Fire_Vent_Risk`.

### Cold-chain monitoring (educational SI)

`Food_Cold` and `Pharma_Cold` are controlled temperature kinds. Assigning a
cold order enables its sensor and starts `Hold_Temp_C` at the band midpoint in
°C. `Sample_Hold_Temp` injects the latest reading; `Tick` checks the inclusive
`[Lo_C, Hi_C]` band after elapsed time advances. An out-of-band reading marks
the order `Cold_Chain_Failed`, records a breach, and frees its bound vehicle.
Temperatures remain at the last sample by default; optional demo drift is set
with `Set_Hold_Temp_Drift`. This is educational SI behavior, not GDP/pharmacy
validation.

### Dangerous goods (Step-1)

- Order carries `Hazard_Class` + optional `Placard_Code`.
- **Road / Tunnel** hazardous: `Vehicle_ADR_Approved`, active **Driver** with
  `Driver_Has_ADR_Cert`, and **Tank** body when `Requires_Tank_Body`
  (`Gases`, `Flammable_Liquids`).
- **Air / Space_Haul** allow-list: **deny** `Explosives` and `Radioactive` by
  default (`Mode_Allows_Hazard`); Tank cargo is additionally non-DG only.
- This is thin, educational dangerous-goods wiring—not ADR or IATA compliance.

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

Barges use a shared `Barge_Market` (educational demo coins, separate from
`Company` money): the pool is capped at 1000 with a policy floor of 12,
`Initial_Barge_Budget` is 1,000,000 coins, and each barge must clear the
current `Ask_Price`. `Bid_For_Barge` is the whole-vessel path: it transfers wealth into ownership
and the fleet; a cull returns the barge to the available pool. Owned hulls also
expose `Hold_Capacity_kg`, `Hold_Booked_kg`, and `Remaining_Hold_kg`.
`Bid_Hold_Slot` books a partial cargo hold in kg and charges `Bid_Amount` as
total coin for that slot; the bid must be at least `Ask_Per_Kg * Mass_kg` and
within remaining capacity and wealth. Fitness/throughput remains hull based,
while booked kg is the separately paid hold metric. `Life_Tick` fills a local
owned hull's remaining hold before buying another barge when the market permits.
`End_Generation` increments `Generation` and passes all remaining `Wealth`
through `Inherited`.
Call `Seed_Cell_With_Barge_Market` for a fresh global market; `play` seeds the
initial evolution fleet toward the 12-barge floor when its budget permits.

### Warehouse + Stock (child package)

`Logistics_Module.Warehouses` is a bounded educational hub inventory. A
`Warehouse_Registry` holds at most `Max_Warehouses = 16` warehouses, each with
up to 16 simple cargo-class slots and an SI `Capacity_kg`. `Warehouse_Location`
records a `World_Body`, `City_Id`, and optional `Spaceport_Id`.

Typical flow:

```ada
Create_Warehouse (Registry, Terra_0, Capacity => 1_000.0, Id => W, Success => Ok);
Deposit (Registry, W, Dry_Box_Cargo, 600.0, Ok);
Withdraw (Registry, W, Dry_Box_Cargo, 100.0, Ok);
Remaining := Remaining_Capacity_kg (Registry, W);
```

`Stock_Of` reports a SKU or total stock; deposits that exceed capacity, use an
unknown warehouse, or exhaust the 16 slots are rejected. A small default
registry also exposes the same operations without a company object for demos.

### Ship_Class per-world capacity/cost

Demand_Cells keeps `Fleet_Species` as the compatible legacy name and exposes
`Ship_Class` as an alias. `Cargo_Capacity_kg` / `Effective_Cargo_Mass_kg` and
`Cost_Factor` provide a parallel, non-breaking world lookup. Existing
`Score_kg_s` and `Reward_Coin` formulas are unchanged. See
[Physical_Data.md](Physical_Data.md) for the lean table.

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
make play   # or: make run   # Text_IO MVP: jobs / assign / tick
make size   # 6000-tick crewed-station fleet sizing demo
make clean  # remove generated obj/ and bin/ directories
```

The test and play builds use `-gnatwa -gnat2022 -gnata`.


### Station fleet sizing

`Logistics_Module.Station_Sizing` sizes a human-only 150-person station
against a lean Earth--Mars demand cell. It combines life-support consumables
(2.5 kg/person/day) with small spare-parts, power-logistics, and
thermal/fluids/cabling cargo stubs (2.7 kg/person/day total); these are
educational rates, not NASA programme numbers. The demo uses 15 days per
tick (`Delta_s = 1_296_000.0`) for 6000 ticks (~246 years), a roughly
centuries-scale fictional horizon, and a barge market with hold-slot bids.

```bash
make size
```

The fixed-mix sweep runs the tournament tick loop without evolutionary
mutation while measuring each candidate. It reports the first sustained
`(Barge_Inner, Fast_Courier, Relativistic_Stub)` mix in lexicographic order;
the market's 12-barge policy floor and pool cap are respected.

### Five-agent barge supply scenarios

`Logistics_Module.Supply_Agents` adds five explicit, competing agents in the
same `Demand_Cell` and shared barge market. Each `Agent_Genes` record carries
bounded educational strategy fields: `Bid_Aggressiveness`,
`Prefer_Hold_Slots`, `Target_Oversupply_Ratio` (1.0..1.80),
`Max_Barges_Willingness`, and `Wealth_Reserve_Fraction` (0.0..0.90).
Agents 1--2 are undersupply/cap styles, 3--4 target controlled oversupply,
and 5 is a mixed explorer. Whole-hull bids are the only way to add throughput;
hold-slot bids fill available cargo capacity first for hold-preferring agents.

* `Run_Limited_Barge_Agent` clamps ownership at `Barge_Cap` (default 100) and
  reports mean `Undersupply_kg` plus the fraction of `Under_Served` ticks.
* `Size_Min_Barges_Oversupply` sweeps operational N and accepts only a
  sustained `Over_Served` cell with `Over_Supply_Ratio = Throughput /
  Demand_Rate` in `[1.0, 1.80]`. `Sweep_Min_Barges` defaults to `Barge_Pool_Min` as requested. The `make size`
  demo explicitly passes 1 as an operational-hull lens because twelve active
  barges at Crew=150 exceed the +80% ratio; pass 12 when the policy floor
  itself is the constraint.

`End_Generation` preserves the top two agents and gives the other three
crossover/mutation offspring; `Agent_Death` respawns from the current best
strategy. This carries genes across generations while the existing
`Demand_Cells.End_Generation` carries market wealth. `make size` prints both
scenarios at Crew=150 and 6000 ticks. The 6000-tick demo is quick; tests use
short windows.

### MVP play loop

1. List / seed jobs  2. Assign vehicle → `En_Route`, `ETA_s = Distance_m / Speed`
3. Tick: wall Δt × `Time_Rate` → `Elapsed_s`; deliver when `Elapsed_s >= ETA_s`
4. Menu: `[j]obs [a]ssign [t]/Enter tick [r]ate [s]paceports [e]vo [u]ourney [q]uit`


## License

MIT — see [LICENSE](LICENSE).

## MIT-safe ephemeris support

`Logistics_Module.Ephemeris` provides a small, in-tree circular heliocentric
Kepler stub. It has no Swiss Ephemeris dependency and vendors no ephemeris
code or data. `Position_Of (World, T_s)` and `Distance_m (A, B, T_s)` use the
loaded exchange table when a body is present, otherwise they use the stub.
The original `Position_Of (World)` and `Distance_m (A, B)` calls remain the
t=0 compatibility forms. `Compute_ETA_s (A, B, Mode, T_s)` and
`Demand_Cells.Transit_Duration_s (A, B, Ship_Class, T_s)` resolve distance at
departure; existing distance-based APIs are unchanged.

### Exchange table v1

Tables are UTF-8/plain CSV (the loader ignores `#` comments):

```text
# Ada Logistics Ephemeris Table v1
# columns: body,t_s,x_m,y_m,z_m
# body: Terra_0|Moon_Polar|Venus_Cloud_Port|Mars|Titan
Terra_0,0,0,0,0
Titan,0,0,0,0
```

`t_s` is seconds from the table epoch and coordinates are metres, relative to
`Terra_0`. Samples for each body are linearly interpolated and clamped at the
ends. A body absent from a loaded table falls back to the in-tree Kepler
stub. `Load_Ephemeris_Table` replaces the previous table only after a complete
successful parse.

`make eph` builds a small Ada generator, writes
`eph/batch_terra_mars_titan.csv`, reloads it, checks the t=0 Terra--Titan
distance is about 9.5 AU, checks a 3000 m/s transit is about 15 years, and
checks that the Mars angle moves. The batch file is intentionally a portable
interchange example, not a precision ephemeris.

### Later SwissEph/JPL/swetest conversion

Do not copy Swiss Ephemeris (or its AGPL data/code) into this MIT repository.
A later import can be done as an external/manual conversion: run the chosen
external tool under its own licence, map its body name to the five allowed
`body` tokens, convert its epoch/time to seconds `t_s`, convert AU or km to
metres, and emit `body,t_s,x_m,y_m,z_m` rows. Review the external licence and
redistribution terms separately; only the resulting neutral CSV belongs in an
application deployment.
