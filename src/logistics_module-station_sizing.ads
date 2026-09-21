--  Educational crewed-station fleet sizing over an Earth--Mars demand cell.
pragma Ada_2022;

package Logistics_Module.Station_Sizing is

   --  Lean cargo bands, in kg per person per day.  These are educational
   --  stubs for a station deployment/resupply exercise, not NASA programme
   --  numbers.
   type Station_Cargo_Band is
     (Consumables, Spare_Parts, Power_Logistics, Thermal_Fluids_Cabling);

   Crew_N : constant Positive := 150;

   Consumables_kg_person_day             : constant Float := 2.50;
   Spare_Parts_kg_person_day             : constant Float := 0.10;
   Power_Logistics_kg_person_day         : constant Float := 0.05;
   Thermal_Fluids_Cabling_kg_person_day  : constant Float := 0.05;
   Total_Station_kg_person_day           : constant Float := 2.70;

   function Kg_Per_Person_Day
     (Band : Station_Cargo_Band) return Float;

   function Total_Demand_Rate_kg_s
     (Crew : Natural := Crew_N) return Float
   with
     Post => Total_Demand_Rate_kg_s'Result >= 0.0;

   --  Twelve barges is the educational market's policy floor.  Search bounds
   --  keep the sizing sweep deterministic and quick for both demos and tests.
   Search_Max_Barges   : constant Natural := 40;
   Search_Max_Couriers : constant Natural := 10;
   Search_Max_Rel_Stubs : constant Natural := 2;
   Sustained_Window_Ticks : constant Positive := 100;

   --  The sweep keeps a fixed candidate mix and uses the Demand_Cells
   --  tournament tick loop with evolution disabled.  This makes "minimum"
   --  reproducible: the first sustained (barges, couriers, stubs) tuple is
   --  selected in lexicographic order, starting at the barge-market floor.
   procedure Size_Station_Fleet
     (Crew           : Positive := Crew_N;
      N_Ticks        : Positive := 6000;
      Delta_s        : Float := 1_296_000.0;
      Distance_m     : Float := Logistics_Module.Mars_Offset_m;
      Min_Barges     : out Natural;
      Min_Couriers   : out Natural;
      Min_Rel_Stubs  : out Natural;
      Final_Deficit_kg : out Float;
      Sustained      : out Boolean);

end Logistics_Module.Station_Sizing;
