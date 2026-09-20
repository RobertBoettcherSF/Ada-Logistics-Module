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
| **Physical** | `Mass_Kilograms`, `GVW_Kilograms`, `Footprint_Length_m`, `Footprint_Width_m` — see [Physical_Data.md](Physical_Data.md) |
| **Cargo_Class** | Silo / Tank / Lowboy / Reefer / Flatbed / Container |
| **Dispatch_Mode** | `Road`, `Rail`, `Sea`, `Air`, `Space` |
| **City** | `Has_Rail` always true; optional airport, port, **spaceport** |
| **Hazard_Class** | ADR-inspired lean 1–9 + `None` (clean-room labels) |
| **Placard_Code** | 8-char data field (orange-plate style; no graphics) |

### Cargo ↔ mode (`Compatible`)

| Cargo | Road body | Also |
|-------|-----------|------|
| Silo | Silo | Rail, Sea |
| Tank | Tank | Rail, Sea |
| Lowboy | Lowboy | Rail, Sea |
| Reefer | Reefer | **Road only** |
| Flatbed | Flatbed (+ van) | Rail, Air |
| Container | Container (+ van partial) | Rail, Air, Sea, **Space** |

### Space ≅ Air

`Space` uses the same facility pattern as `Air` (`Has_Spaceport` at both ends).
Step-1 cargo: **Container only**. `Space_Cost_Factor` / `Space_Time_Factor`
are higher than an air baseline (stubs for later costing).

### Dangerous goods (Step-1)

- Order carries `Hazard_Class` + optional `Placard_Code`.
- **Road** hazardous: `Vehicle_ADR_Approved`, active **Driver** with
  `Driver_Has_ADR_Cert`, and **Tank** body when `Requires_Tank_Body`
  (`Gases`, `Flammable_Liquids`).
- **Air / Space** allow-list: **deny** `Explosives` and `Radioactive` by default
  (`Mode_Allows_Hazard`).

Also: staff roles, cash + reputation, offers / `Accept_Offer`, maintain,
rail schedule-slot stub.

### EU classes (v0)

Kind map: `Light_Van`→`N1`, `Rigid`→`N2`/`N3` by GVW, `Artic_Tractor`→`N3`,
trailers→`O2`/`O4` stubs. Contracts: `GVW >= Curb_Mass`; goods capacity checks
use class GVW limits (`N3` check cap 40_000 kg documented in Physical_Data).

## Build

```bash
make test
```

Flags: `-gnatwa -gnat2022 -gnata`. No `main.adb` — `tests.adb` is the entry point.

## License

MIT — see [LICENSE](LICENSE).
