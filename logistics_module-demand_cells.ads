--  Conway-like supply / demand cells (lean SI). Dry English names only.
--  Child of Logistics_Module. Life birth/death hooks are stubs for later.

pragma Ada_2022;

package Logistics_Module.Demand_Cells is

   ------------------------------------------------------------------
   -- Barge / cruise constants (ops-owned SI)
   ------------------------------------------------------------------
   Barge_Gross_Mass_kg : constant Float := 1_900_000.0;
   -- 0.55 of gross
   Barge_Cargo_Mass_kg : constant Float := 1_045_000.0;

   -- Cruise_Speed_m_s per mode (Space_Haul = 3000 for MVP)
   function Cruise_Speed_m_s (Mode : Haul_Mode) return Float
     renames Speed_Of;

   ------------------------------------------------------------------
   -- Per-cell demand / stock / fleet
   ------------------------------------------------------------------
   type Demand_Cell is record
      Demand_Rate_kg_s : Float := 0.0;
      Stock_kg         : Float := 0.0;
      Horizon_s        : Float := 0.0;
      Distance_m       : Float := 0.0;
      Fleet_In_Flight  : Natural := 0;
      Mode             : Haul_Mode := Space_Haul;
   end record;

   -- Deficit_kg = max(0, Demand_Rate_kg_s * Horizon_s - Stock_kg)
   function Deficit_kg (Cell : Demand_Cell) return Float
   with
     Post => Deficit_kg'Result >= 0.0;

   -- Shipments_Needed = ceil(Deficit_kg / Barge_Cargo_Mass_kg)
   function Shipments_Needed (Cell : Demand_Cell) return Natural;

   -- Transit_Duration_s = Distance_m / Cruise_Speed_m_s
   function Transit_Duration_s (Cell : Demand_Cell) return Float
   with
     Pre => Cell.Distance_m >= 0.0;

   -- Throughput_kg_s = Fleet_In_Flight * Barge_Cargo_Mass_kg
   --                   / (2 * Transit_Duration_s)
   function Throughput_kg_s (Cell : Demand_Cell) return Float;

   -- ETA for one outbound leg
   function ETA_s (Cell : Demand_Cell) return Float
   with
     Pre  => Cell.Distance_m >= 0.0,
     Post => ETA_s'Result = Transit_Duration_s (Cell);

   -- Tick: consume stock by demand rate; add arrivals from throughput
   procedure Tick_Cell
     (Cell    : in out Demand_Cell;
      Delta_s : Float)
   with
     Pre => Delta_s >= 0.0;

   -- Inject arrival mass (tests / explicit landings)
   procedure Apply_Arrival
     (Cell       : in out Demand_Cell;
      Arrived_kg : Float)
   with
     Pre => Arrived_kg >= 0.0;

   ------------------------------------------------------------------
   -- Life birth / death of demand — stub hooks for later Conway layer
   ------------------------------------------------------------------
   procedure On_Demand_Birth (Cell : in out Demand_Cell);
   procedure On_Demand_Death (Cell : in out Demand_Cell);

end Logistics_Module.Demand_Cells;
