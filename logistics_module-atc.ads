--  Lean air/space traffic control SI (ATC). Separate from evolutionary Fitness.
--  Corridors / lanes between cities or spaceports; capacity + separation.

pragma Ada_2022;

with Ada.Calendar;
with Ada.Text_IO;

package Logistics_Module.ATC is

   ------------------------------------------------------------------
   -- LOCK defaults (ops-owned SI)
   ------------------------------------------------------------------
   -- Space_Haul Separation_m ≥ 50_000; Lane_Capacity hard cap 8 MVP
   Separation_Road_m       : constant Float := 100.0;
   Separation_Tunnel_m     : constant Float := 50.0;
   Separation_Space_Haul_m : constant Float := 50_000.0;
   Space_Haul_Capacity_Cap : constant Positive := 8;

   Max_Lanes : constant := 64;
   type Lane_Id is range 1 .. Max_Lanes;

   ------------------------------------------------------------------
   -- Corridor / lane between spaceports or cities
   ------------------------------------------------------------------
   type Traffic_Lane is record
      Origin          : City_Id := 1;
      Destination     : City_Id := 1;
      Mode            : Haul_Mode := Road;
      Distance_m      : Float := 0.0;
      Separation_m    : Float := Separation_Road_m;
      Lane_Capacity   : Positive := 1;
      Fleet_In_Flight : Natural := 0;
      Assign_Rejected : Natural := 0;
   end record;

   function Default_Separation_m (Mode : Haul_Mode) return Float
   with
     Post =>
       (case Mode is
          when Road       => Default_Separation_m'Result = Separation_Road_m,
          when Tunnel     => Default_Separation_m'Result = Separation_Tunnel_m,
          when Space_Haul =>
            Default_Separation_m'Result = Separation_Space_Haul_m);

   -- Capacity from corridor length: floor(Distance_m / Separation_m), ≥ 1.
   -- Space_Haul hard-capped at Space_Haul_Capacity_Cap (8).
   function Capacity_From_Corridor
     (Distance_m   : Float;
      Separation_m : Float;
      Mode         : Haul_Mode) return Positive
   with
     Pre => Distance_m >= 0.0 and then Separation_m > 0.0;

   -- Separation_m <= 0 → mode default; Lane_Capacity 0 → from corridor
   function Make_Lane
     (Origin        : City_Id;
      Destination   : City_Id;
      Mode          : Haul_Mode;
      Distance_m    : Float;
      Separation_m  : Float := 0.0;
      Lane_Capacity : Natural := 0) return Traffic_Lane
   with
     Pre => Distance_m >= 0.0;

   -- Min_Slot_Spacing_s = Separation_m / Cruise_Speed_m_s (docs/tests)
   function Min_Slot_Spacing_s
     (Separation_m     : Float;
      Cruise_Speed_m_s : Float) return Float
   with
     Pre  => Separation_m >= 0.0 and then Cruise_Speed_m_s > 0.0,
     Post => Min_Slot_Spacing_s'Result = Separation_m / Cruise_Speed_m_s;

   function Min_Slot_Spacing_s (Lane : Traffic_Lane) return Float
   with
     Pre => Speed_Of (Lane.Mode) > 0.0;

   function At_Capacity (Lane : Traffic_Lane) return Boolean
   is (Lane.Fleet_In_Flight >= Natural (Lane.Lane_Capacity));

   -- Occupy one in-flight slot; at capacity → Success False, Assign_Rejected++
   procedure Try_Occupy
     (Lane    : in out Traffic_Lane;
      Success : out Boolean);

   -- Raise ATC_Capacity_Exceeded when at capacity (optional path)
   procedure Occupy_Or_Raise (Lane : in out Traffic_Lane);

   procedure Release (Lane : in out Traffic_Lane);

   ATC_Capacity_Exceeded : exception;

   ------------------------------------------------------------------
   -- Assign / spawn shipment gated by lane capacity (not Fitness)
   ------------------------------------------------------------------
   -- If Fleet_In_Flight >= Lane_Capacity → Mark Rejected_ATC, Success False.
   -- Else occupy slot and Assign_Vehicle (Pending/Accepted → En_Route).
   procedure Assign_On_Lane
     (C          : in out Company;
      Lane       : in out Traffic_Lane;
      Order      : Order_Id;
      Vehicle    : Vehicle_Id;
      Distance_m : Float;
      Mode       : Haul_Mode := Road;
      Success    : out Boolean;
      Now        : Ada.Calendar.Time := Ada.Calendar.Clock)
   with
     Pre => Distance_m >= 0.0;

   -- Release one slot when an En_Route shipment completes (tests / play)
   procedure Release_After_Delivery (Lane : in out Traffic_Lane);

   ------------------------------------------------------------------
   -- sim_run.csv ATC columns (separate from Fitness math)
   ------------------------------------------------------------------
   ATC_CSV_Columns : constant String :=
     "Fleet_In_Flight,Lane_Capacity,Assign_Rejected";

   procedure Append_ATC_CSV
     (File : Ada.Text_IO.File_Type;
      Lane : Traffic_Lane);

   -- Append one ATC snapshot row to sim_run.csv (after header exists)
   procedure Log_Lane_State
     (Lane : Traffic_Lane;
      T_s  : Float := 0.0;
      Path : String := "sim_run.csv");

end Logistics_Module.ATC;
