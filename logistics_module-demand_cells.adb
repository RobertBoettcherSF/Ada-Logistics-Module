--  Demand_Cells body: deficit, shipments, ETA, tick stock from arrivals.

pragma Ada_2022;

package body Logistics_Module.Demand_Cells is

   function Deficit_kg (Cell : Demand_Cell) return Float is
      Need : constant Float := Cell.Demand_Rate_kg_s * Cell.Horizon_s;
   begin
      if Need > Cell.Stock_kg then
         return Need - Cell.Stock_kg;
      else
         return 0.0;
      end if;
   end Deficit_kg;

   function Shipments_Needed (Cell : Demand_Cell) return Natural is
      D : constant Float := Deficit_kg (Cell);
   begin
      if D <= 0.0 then
         return 0;
      end if;
      return Natural (Float'Ceiling (D / Barge_Cargo_Mass_kg));
   end Shipments_Needed;

   function Transit_Duration_s (Cell : Demand_Cell) return Float is
   begin
      return Cell.Distance_m / Cruise_Speed_m_s (Cell.Mode);
   end Transit_Duration_s;

   function Throughput_kg_s (Cell : Demand_Cell) return Float is
      T : constant Float := Transit_Duration_s (Cell);
   begin
      if Cell.Fleet_In_Flight = 0 or else T <= 0.0 then
         return 0.0;
      end if;
      return Float (Cell.Fleet_In_Flight) * Barge_Cargo_Mass_kg / (2.0 * T);
   end Throughput_kg_s;

   function ETA_s (Cell : Demand_Cell) return Float is
   begin
      return Transit_Duration_s (Cell);
   end ETA_s;

   procedure Tick_Cell
     (Cell    : in out Demand_Cell;
      Delta_s : Float)
   is
      Consumed : Float;
      Arrived  : Float;
   begin
      if Delta_s <= 0.0 then
         return;
      end if;
      Consumed := Cell.Demand_Rate_kg_s * Delta_s;
      if Cell.Stock_kg > Consumed then
         Cell.Stock_kg := Cell.Stock_kg - Consumed;
      else
         Cell.Stock_kg := 0.0;
      end if;
      Arrived := Throughput_kg_s (Cell) * Delta_s;
      Cell.Stock_kg := Cell.Stock_kg + Arrived;
   end Tick_Cell;

   procedure Apply_Arrival
     (Cell       : in out Demand_Cell;
      Arrived_kg : Float)
   is
   begin
      Cell.Stock_kg := Cell.Stock_kg + Arrived_kg;
   end Apply_Arrival;

   procedure On_Demand_Birth (Cell : in out Demand_Cell) is
      pragma Unreferenced (Cell);
   begin
      null;  -- stub: Conway birth later
   end On_Demand_Birth;

   procedure On_Demand_Death (Cell : in out Demand_Cell) is
      pragma Unreferenced (Cell);
   begin
      null;  -- stub: Conway death later
   end On_Demand_Death;

end Logistics_Module.Demand_Cells;
