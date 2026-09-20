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
