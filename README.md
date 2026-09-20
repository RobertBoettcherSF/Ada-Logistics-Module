# Ada Logistics Module

Clean-room **Ada 2022** library for a small logistics / forwarding company
simulation (Step 1). Inspired by the public logistics-sim genre only.

**No proprietary assets, names, formulas, data, or manual text are included.**

## Domain model (our types)

| Concept | Encoding |
|---------|----------|
| **Freight_Units (FE)** | `Natural` subtype — abstract cargo measure (not mixed SI) |
| **Vehicle_Kind** | `Light_Van`, `Rigid`, `Artic_Tractor` (tractor alone = **0 FE**) |
| **Body_Kind** | `Silo`, `Tank`, `Reefer`, `Flatbed`, `Container`, `Lowboy` |
| **Cargo_Class** | Silo / Tank / Lowboy / Reefer / Flatbed / Container cargo |
| **Dispatch_Mode** | `Road`, `Rail`, `Sea`, `Air`, `Space` |
| **City** | `Has_Rail` always `True`; optional `Has_Airport`, `Has_Port`, `Has_Spaceport` |

### `Compatible (Cargo, Body, Mode)`

| Cargo | Road body | Also |
|-------|-----------|------|
| Silo | Silo | Rail, Sea |
| Tank | Tank | Rail, Sea |
| Lowboy | Lowboy | Rail, Sea |
| Reefer | Reefer | **Road only** |
| Flatbed | Flatbed (+ light van) | Rail, Air |
| Container | Container (+ light van partial) | Rail, Air, Sea, **Space** |

Step-1 rule: **only `Container_Cargo` is compatible with `Space`.**

### Dispatch constraints

- **Road** — anytime (vehicle body / van / FE capacity apply)
- **Rail** — reserved schedule-slot stub for origin→destination
- **Air** — both cities `Has_Airport`
- **Sea** — both cities `Has_Port`
- **Space** — both cities `Has_Spaceport`

Also: staff roles, cash + reputation, offer → `Accept_Offer`, vehicle maintain / attach-detach semi.

## Build & test

```bash
make test
```

Flags: `-gnatwa -gnat2022 -gnata`. No `main.adb` — entry point is `tests.adb`.

## Layout

```
logistics_module.ads / .adb / .gpr
Makefile
tests.adb
LICENSE   (MIT)
README.md
```

## License

MIT — see [LICENSE](LICENSE).
