--  Five bounded supply agents competing in one barge market and demand cell.
pragma Ada_2022;

with Logistics_Module.Demand_Cells;

package Logistics_Module.Supply_Agents is

   Agent_Count : constant Positive := 5;
   subtype Agent_Id is Positive range 1 .. Agent_Count;

   --  Educational genes.  Implementations clamp Float genes to the documented
   --  ranges after crossover/mutation.
   type Agent_Genes is record
      Bid_Aggressiveness       : Float := 0.0; -- 0.0 .. 1.0 above ask
      Prefer_Hold_Slots        : Boolean := True;
      Target_Oversupply_Ratio  : Float := 1.0; -- 1.0 .. 1.80
      Max_Barges_Willingness   : Natural := 0;
      Wealth_Reserve_Fraction  : Float := 0.0; -- 0.0 .. 0.90
   end record;

   type Agent_State is record
      Genes         : Agent_Genes;
      Fitness       : Float := 0.0;
      Barges_Bought : Natural := 0;
      Hold_Booked_kg : Float := 0.0;
      Alive         : Boolean := True;
   end record;

   type Agent_Population is array (Agent_Id) of Agent_State;

   procedure Initialize_Agents (Population : out Agent_Population);

   --  A dead agent is immediately respawned from the current best genes.
   procedure Agent_Death
     (Population : in out Agent_Population;
      Victim     : Agent_Id);

   --  The top two gene records survive; the remaining three receive bounded
   --  crossover/mutation offspring.  Market wealth inheritance remains owned by
   --  Demand_Cells.End_Generation; this procedure carries strategy genes.
   procedure End_Generation (Population : in out Agent_Population);

   --  Run all five agents against one shared Barge_Market and Demand_Cell.
   --  No hidden sixth agent is spawned: Evolve is deliberately disabled in the
   --  underlying tick loop and every hull is bought through the shared market.
   procedure Run_Competing_Agents
     (Crew             : Positive := 150;
      N_Ticks          : Positive := 6000;
      Delta_s          : Float := 1_296_000.0;
      Distance_m       : Float := Logistics_Module.Mars_Offset_m;
      Barge_Cap        : Natural := Logistics_Module.Demand_Cells.Barge_Pool_Max;
      Population       : in out Agent_Population;
      Barges_Used      : out Natural;
      Mean_Deficit_kg  : out Float;
      Under_Fraction   : out Float;
      Achieved_Ratio   : out Float);

   --  Scenario 1: cap hull ownership and minimise the run-average deficit.
   procedure Run_Limited_Barge_Agent
     (Crew          : Positive := 150;
      N_Ticks       : Positive := 6000;
      Delta_s       : Float := 1_296_000.0;
      Distance_m    : Float := Logistics_Module.Mars_Offset_m;
      Barge_Cap     : Natural := Logistics_Module.Demand_Cells.Barge_Pool_Max;
      Barges_Used   : out Natural;
      Undersupply_kg : out Float;
      Under_Fraction : out Float);

   --  Scenario 2: find the smallest operational N whose sustained ratio is in
   --  [1.0, Oversupply_Cap].  Sweep_Min_Barges defaults to one operational hull
   --  because the shared market policy floor (12) is a pool reserve, not a
   --  physical requirement for this sizing lens.
   procedure Size_Min_Barges_Oversupply
     (Crew               : Positive := 150;
      N_Ticks            : Positive := 6000;
      Delta_s            : Float := 1_296_000.0;
      Distance_m         : Float := Logistics_Module.Mars_Offset_m;
      Oversupply_Cap     : Float := 1.80;
      Sweep_Min_Barges   : Natural := 1;
      Min_Barges         : out Natural;
      Achieved_Ratio     : out Float;
      Ok                 : out Boolean);

end Logistics_Module.Supply_Agents;
