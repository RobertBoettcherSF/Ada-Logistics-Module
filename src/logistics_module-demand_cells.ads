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

   -- Educational naming alias: fleet species are the current Ship_Class
   -- concepts; the legacy Fleet_Species name remains source-compatible.
   subtype Ship_Class is Fleet_Species;

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

   ------------------------------------------------------------------
   -- Per-world capacity and haul-cost lookup (thin educational table).
   -- This parallel API intentionally does not change legacy Score/Reward.
   ------------------------------------------------------------------
   function Effective_Cargo_Mass_kg
     (S : Fleet_Species; World : World_Body) return Float
   with
     Post => Effective_Cargo_Mass_kg'Result >= 0.0;

   function Cargo_Capacity_kg
     (S : Fleet_Species; World : World_Body) return Float
     renames Effective_Cargo_Mass_kg;

   function Cost_Factor
     (S : Fleet_Species; World : World_Body) return Float
   with
     Post => Cost_Factor'Result > 0.0;

   -- Haul_Mode cruise (Space_Haul = Barge_Inner 3000)
   function Cruise_Speed_m_s (Mode : Haul_Mode) return Float
     renames Speed_Of;

   Barge_Gross_Mass_kg : constant Float := Barge_Inner_Profile.Gross_Mass_kg;
   Barge_Cargo_Mass_kg : constant Float := Barge_Inner_Profile.Cargo_Mass_kg;

   ------------------------------------------------------------------
   -- Consumables SI helpers (crew demand → min cruise)
   ------------------------------------------------------------------
   Consumables_kg_person_day : constant Float := 2.5;
   Seconds_Per_Day_s         : constant Float := 86_400.0;
   Crew_150                  : constant Natural := 150;

   function Demand_Rate_kg_s
     (Crew               : Natural;
      Kg_Per_Person_Day  : Float := Consumables_kg_person_day) return Float
   with
     Post => Demand_Rate_kg_s'Result =
       Float (Crew) * Kg_Per_Person_Day / Seconds_Per_Day_s;

   -- Round-trip sustain: Demand * 2 * Distance / Cargo
   function Min_Cruise_Speed_m_s
     (Demand_Rate_kg_s : Float;
      Distance_m       : Float;
      Cargo_Mass_kg    : Float) return Float
   with
     Pre  => Cargo_Mass_kg > 0.0 and then Distance_m >= 0.0,
     Post => Min_Cruise_Speed_m_s'Result =
       Demand_Rate_kg_s * 2.0 * Distance_m / Cargo_Mass_kg;

   ------------------------------------------------------------------
   -- Tournament MVP — single metric Score_kg_s (Fitness unchanged).
   -- Fuel_Mass_kg = Fuel_Coeff_kg * (Cruise / Speed_Ref)**2
   -- Payload_Net_kg = max(0, Cargo_Mass_kg - Fuel_Mass_kg)
   -- Score_kg_s = Payload_Net_kg / Transit_Duration_s  (one-way; /2 opt. RT)
   -- Reward_Coin = 1.00 * (Score_kg_s / Score_Ref_kg_s);
   -- Score_Ref from Barge_Inner at ref Distance_m. Cruise < c still.
   ------------------------------------------------------------------
   Reward_Coin_Base : constant Float := 1.00;

   -- Lean fuel model (ops-owned). Speed_Ref = Barge_Inner cruise.
   Fuel_Coeff_kg : constant Float := 50_000.0;
   Speed_Ref_m_s : constant Float := Barge_Inner_Profile.Cruise_Speed_m_s;

   type Species_Scores is array (Fleet_Species) of Float;
   type Species_Rewards is array (Fleet_Species) of Float;
   type Species_Fuel is array (Fleet_Species) of Float;
   type Species_Payload is array (Fleet_Species) of Float;

   type Tournament_State is record
      Rewards        : Species_Rewards := [others => 0.0];
      Scores         : Species_Scores := [others => 0.0];
      Fuel           : Species_Fuel := [others => 0.0];
      Payload        : Species_Payload := [others => 0.0];
      Score_Ref_kg_s : Float := 0.0;
      Distance_Ref_m : Float := 0.0;
      Active         : Boolean := False;
   end record;

   function Fuel_Mass_kg (S : Fleet_Species) return Float
   with
     Pre  => Cruise_Speed_m_s (S) < Float (c_m_s),
     Post => Fuel_Mass_kg'Result >= 0.0;

   function Payload_Net_kg (S : Fleet_Species) return Float
   with
     Post => Payload_Net_kg'Result >= 0.0;

   function Score_kg_s
     (S          : Fleet_Species;
      Distance_m : Float) return Float
   with
     Pre => Distance_m > 0.0 and then Cruise_Speed_m_s (S) < Float (c_m_s);

   function Score_Ref_kg_s (Distance_m : Float) return Float
   with
     Pre  => Distance_m > 0.0,
     Post => Score_Ref_kg_s'Result = Score_kg_s (Barge_Inner, Distance_m);

   function Reward_Coin
     (S          : Fleet_Species;
      Distance_m : Float;
      Score_Ref  : Float) return Float
   with
     Pre => Distance_m > 0.0 and then Score_Ref > 0.0;

   procedure Accrue_Rewards
     (State      : in out Tournament_State;
      Distance_m : Float)
   with
     Pre => Distance_m > 0.0;

   -- Winner = max Reward_Coin sum (≡ max Score); ties → higher Fitness
   function Tournament_Winner
     (State      : Tournament_State;
      Distance_m : Float) return Fleet_Species
   with
     Pre => Distance_m > 0.0;

   type Species_Counts is array (Fleet_Species) of Natural;

   ------------------------------------------------------------------
   -- Barge ownership market (educational demo coins, not Company money)
   ------------------------------------------------------------------
   Barge_Pool_Min    : constant Natural := 12;
   Barge_Pool_Max    : constant Natural := 1000;
   Barge_Unit_Price  : constant Float := 50_000.0;
   Initial_Barge_Budget : constant Float := 1_000_000.0;

   type Generation_Id is new Natural;

   type Barge_Market is record
      Pool_Available : Natural := Barge_Pool_Max;
      Pool_Owned     : Natural := 0;
      Ask_Price      : Float := Barge_Unit_Price;
      Generation     : Generation_Id := 0;
      Wealth         : Float := Initial_Barge_Budget;
      Inherited      : Float := 0.0;
      -- Hold bookings are aggregate market state.  Throughput and Fitness
      -- remain hull based; this is the separately paid cargo-slot metric.
      Hold_Capacity_kg : Float := 0.0;
      Hold_Booked_kg   : Float := 0.0;
   end record;

   function Init_Barge_Market return Barge_Market;
   procedure Init_Barge_Market (Market : out Barge_Market);

   -- Demand cells share this one market, so old cell aggregates remain valid.
   function Current_Barge_Market return Barge_Market;

   procedure Clamp_Barge_Pool (Market : in out Barge_Market);

   -- Slot bids use total coin for the requested mass (not a per-kg bid).
   function Ask_Per_Kg (Market : Barge_Market) return Float;
   function Remaining_Hold_kg (Market : Barge_Market) return Float;

   function Bid_Hold_Slot
     (Market     : in out Barge_Market;
      Mass_kg    : Float;
      Bid_Amount : Float) return Boolean;
   procedure Bid_Hold_Slot
     (Market     : in out Barge_Market;
      Mass_kg    : Float;
      Bid_Amount : Float;
      Success    : out Boolean);

   function Bid_For_Barge
     (Market     : in out Barge_Market;
      Bid_Amount : Float) return Boolean;
   procedure Bid_For_Barge
     (Market     : in out Barge_Market;
      Bid_Amount : Float;
      Success    : out Boolean);

   procedure End_Generation (Market : in out Barge_Market);

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

   -- A cell normally owns one market.  The market overload is useful for
   -- tournament/evolution seeds that share a global market explicitly.
   function Barge_Market_Of (Cell : Demand_Cell) return Barge_Market;

   procedure Seed_Cell_With_Barge_Market
     (Cell : in out Demand_Cell);
   procedure Seed_Cell_With_Barge_Market
     (Cell   : in out Demand_Cell;
      Market : Barge_Market);

   procedure Clamp_Barge_Pool (Cell : in out Demand_Cell);

   function Remaining_Hold_kg (Cell : Demand_Cell) return Float;
   function Bid_Hold_Slot
     (Cell       : in out Demand_Cell;
      Mass_kg    : Float;
      Bid_Amount : Float) return Boolean;
   procedure Bid_Hold_Slot
     (Cell       : in out Demand_Cell;
      Mass_kg    : Float;
      Bid_Amount : Float;
      Success    : out Boolean);

   function Bid_For_Barge
     (Cell       : in out Demand_Cell;
      Bid_Amount : Float) return Boolean;
   procedure Bid_For_Barge
     (Cell       : in out Demand_Cell;
      Bid_Amount : Float;
      Success    : out Boolean);

   procedure End_Generation (Cell : in out Demand_Cell);

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

   --  World-route helper: resolve the distance at departure T_s, then use
   --  the same fleet transit calculation as the legacy distance overload.
   function Transit_Duration_s
     (A, B : World_Body;
      S    : Fleet_Species;
      T_s  : Float := 0.0) return Float
   with
     Pre => Cruise_Speed_m_s (S) < Float (c_m_s);

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

   --  Throughput / demand; zero when demand is not positive.  Over_Served
   --  additionally requires stock to cover the cell horizon.
   function Over_Supply_Ratio (Cell : Demand_Cell) return Float;
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
     (Cell     : Demand_Cell;
      T_s      : Float;
      Path     : String := Sim_Log_Path;
      Scores   : Species_Scores := [others => 0.0];
      Rewards  : Species_Rewards := [others => 0.0];
      Fuel     : Species_Fuel := [others => 0.0];
      Payload  : Species_Payload := [others => 0.0]);

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

   -- N automated ticks; accrue Score/Reward; spawn biased to winners.
   -- Evolve => False is a fixed-fleet probe for sizing sweeps.
   procedure Run_Tournament_Ticks
     (Cell      : in out Demand_Cell;
      State     : in out Tournament_State;
      N_Ticks   : Positive;
      Delta_s   : Float;
      T0_s      : Float := 0.0;
      Log       : Boolean := True;
      Path      : String := Sim_Log_Path;
      Time_Rate : Float := 1.0;
      Evolve    : Boolean := True)
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
