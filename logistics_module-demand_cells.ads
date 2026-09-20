--  Conway-like demand cells + evolutionary fleet (DS SI). Dry English names.

pragma Ada_2022;

package Logistics_Module.Demand_Cells is

   ------------------------------------------------------------------
   -- SI constants
   ------------------------------------------------------------------
   c_m_s : constant := 299_792_458;
   AU_m  : constant Float := 1.495_978_707e11;

   -- Relativistic stub: β ≤ 0.01
   Max_Beta : constant Float := 0.01;

   Sim_Log_Path : constant String := "sim_run.csv";

   ------------------------------------------------------------------
   -- Fleet species profiles (ops-owned SI)
   ------------------------------------------------------------------
   type Fleet_Species is (Barge_Inner, Fast_Courier, Relativistic_Stub);

   type Species_Profile is record
      Cruise_Speed_m_s : Float;
      Cargo_Mass_kg    : Float;
      Gross_Mass_kg    : Float;
   end record;

   Barge_Inner_Profile : constant Species_Profile :=
     (Cruise_Speed_m_s => 3_000.0,
      Cargo_Mass_kg    => 1_045_000.0,
      Gross_Mass_kg    => 1_900_000.0);

   Fast_Courier_Profile : constant Species_Profile :=
     (Cruise_Speed_m_s => 30_000.0,
      Cargo_Mass_kg    => 50_000.0,
      Gross_Mass_kg    => 100_000.0);

   -- Lean stub: β = Max_Beta; tiny cargo/gross placeholders
   Relativistic_Stub_Profile : constant Species_Profile :=
     (Cruise_Speed_m_s => Max_Beta * Float (c_m_s),
      Cargo_Mass_kg    => 1_000.0,
      Gross_Mass_kg    => 5_000.0);

   function Profile_Of (S : Fleet_Species) return Species_Profile
   with
     Post => Profile_Of'Result.Cruise_Speed_m_s < Float (c_m_s);

   function Cruise_Speed_m_s (S : Fleet_Species) return Float
   with
     Post => Cruise_Speed_m_s'Result < Float (c_m_s);

   -- Haul_Mode cruise (Space_Haul = Barge_Inner 3000)
   function Cruise_Speed_m_s (Mode : Haul_Mode) return Float
     renames Speed_Of;

   Barge_Gross_Mass_kg : constant Float := Barge_Inner_Profile.Gross_Mass_kg;
   Barge_Cargo_Mass_kg : constant Float := Barge_Inner_Profile.Cargo_Mass_kg;

   type Species_Counts is array (Fleet_Species) of Natural;

   ------------------------------------------------------------------
   -- Per-cell demand / stock / evolutionary fleet
   ------------------------------------------------------------------
   type Demand_Cell is record
      Demand_Rate_kg_s : Float := 0.0;
      Stock_kg         : Float := 0.0;
      Horizon_s        : Float := 0.0;
      Distance_m       : Float := 0.0;
      Fleet            : Species_Counts := [others => 0];
      Preferred        : Fleet_Species := Barge_Inner;
      Cell_Id          : Natural := 1;
   end record;

   function Ship_Count (Cell : Demand_Cell) return Natural;
   function Ship_Count
     (Cell : Demand_Cell; S : Fleet_Species) return Natural;

   function Deficit_kg (Cell : Demand_Cell) return Float
   with
     Post => Deficit_kg'Result >= 0.0;

   function Shipments_Needed (Cell : Demand_Cell) return Natural;

   function Transit_Duration_s
     (Distance_m : Float; S : Fleet_Species) return Float
   with
     Pre => Distance_m >= 0.0
       and then Cruise_Speed_m_s (S) < Float (c_m_s);

   function Transit_Duration_s (Cell : Demand_Cell) return Float
   with
     Pre => Cell.Distance_m >= 0.0;

   function Throughput_kg_s
     (S          : Fleet_Species;
      Distance_m : Float;
      Count      : Natural := 1) return Float
   with
     Pre => Distance_m > 0.0
       and then Cruise_Speed_m_s (S) < Float (c_m_s);

   function Throughput_kg_s (Cell : Demand_Cell) return Float;

   -- Fitness = Throughput / (Ship_Count * Gross)
   function Fitness
     (S          : Fleet_Species;
      Distance_m : Float;
      Count      : Natural := 1) return Float
   with
     Pre => Distance_m > 0.0
       and then Count > 0
       and then Cruise_Speed_m_s (S) < Float (c_m_s);

   function Beta_Of (S : Fleet_Species) return Float;

   function Best_Species (Distance_m : Float) return Fleet_Species
   with
     Pre => Distance_m > 0.0;

   function Under_Served (Cell : Demand_Cell) return Boolean;
   function Over_Served (Cell : Demand_Cell) return Boolean;

   function ETA_s (Cell : Demand_Cell) return Float
   with
     Pre  => Cell.Distance_m >= 0.0,
     Post => ETA_s'Result = Transit_Duration_s (Cell);

   procedure Tick_Cell
     (Cell    : in out Demand_Cell;
      Delta_s : Float)
   with
     Pre => Delta_s >= 0.0;

   -- First line: # run_id=ISO Time_Rate=… AU_m=… c_m_s=…
   -- then SI header (+ ATC cols Fleet_In_Flight,Lane_Capacity,Assign_Rejected);
   -- subsequent Life_Ticks append cell×species rows (ATC zeros from Fitness path).
   procedure Begin_Sim_Run
     (Time_Rate : Float;
      Path      : String := Sim_Log_Path;
      Run_Id    : String := "");

   procedure Append_Sim_Rows
     (Cell : Demand_Cell;
      T_s  : Float;
      Path : String := Sim_Log_Path);

   -- Life: under-served → spawn/prefer higher Fitness; over-served → cull lower
   -- Appends sim_run.csv when Log (default).
   procedure Life_Tick
     (Cell    : in out Demand_Cell;
      Delta_s : Float;
      T_s     : Float := 0.0;
      Log     : Boolean := True;
      Path    : String := Sim_Log_Path;
      Time_Rate : Float := 1.0)
   with
     Pre => Delta_s >= 0.0;

   procedure Apply_Arrival
     (Cell       : in out Demand_Cell;
      Arrived_kg : Float)
   with
     Pre => Arrived_kg >= 0.0;

   procedure On_Demand_Birth (Cell : in out Demand_Cell);
   procedure On_Demand_Death (Cell : in out Demand_Cell);

end Logistics_Module.Demand_Cells;
