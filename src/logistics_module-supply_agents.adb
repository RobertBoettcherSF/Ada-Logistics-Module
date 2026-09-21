--  Five-agent supply market simulation and two explicit sizing lenses.
pragma Ada_2022;

with Logistics_Module.Station_Sizing;

package body Logistics_Module.Supply_Agents is

   use Logistics_Module.Demand_Cells;
   use Logistics_Module.Station_Sizing;

   function Clamp (X, Lo, Hi : Float) return Float is
   begin
      return Float'Max (Lo, Float'Min (Hi, X));
   end Clamp;

   function Effective_Cap (Cap : Natural) return Natural is
   begin
      return Natural'Min (Cap, Barge_Pool_Max);
   end Effective_Cap;

   function Ratio (Cell : Demand_Cell) return Float is
   begin
      return Over_Supply_Ratio (Cell);
   end Ratio;

   function Default_Genes (A : Agent_Id) return Agent_Genes is
   begin
      case A is
         when 1 =>
            return (Bid_Aggressiveness      => 0.05,
                    Prefer_Hold_Slots       => False,
                    Target_Oversupply_Ratio => 1.05,
                    Max_Barges_Willingness  => Barge_Pool_Max,
                    Wealth_Reserve_Fraction => 0.10);
         when 2 =>
            return (Bid_Aggressiveness      => 0.15,
                    Prefer_Hold_Slots       => True,
                    Target_Oversupply_Ratio => 1.10,
                    Max_Barges_Willingness  => Barge_Pool_Max,
                    Wealth_Reserve_Fraction => 0.15);
         when 3 =>
            return (Bid_Aggressiveness      => 0.20,
                    Prefer_Hold_Slots       => False,
                    Target_Oversupply_Ratio => 1.40,
                    Max_Barges_Willingness  => Barge_Pool_Max,
                    Wealth_Reserve_Fraction => 0.20);
         when 4 =>
            return (Bid_Aggressiveness      => 0.30,
                    Prefer_Hold_Slots       => True,
                    Target_Oversupply_Ratio => 1.80,
                    Max_Barges_Willingness  => Barge_Pool_Max,
                    Wealth_Reserve_Fraction => 0.25);
         when 5 =>
            return (Bid_Aggressiveness      => 0.10,
                    Prefer_Hold_Slots       => True,
                    Target_Oversupply_Ratio => 1.25,
                    Max_Barges_Willingness  => Barge_Pool_Max,
                    Wealth_Reserve_Fraction => 0.10);
      end case;
   end Default_Genes;

   procedure Initialize_Agents (Population : out Agent_Population) is
   begin
      for A in Agent_Id loop
         Population (A) :=
           (Genes          => Default_Genes (A),
            Fitness        => 0.0,
            Barges_Bought  => 0,
            Hold_Booked_kg => 0.0,
            Alive          => True);
      end loop;
   end Initialize_Agents;

   function Mutate (G : Agent_Genes; Salt : Natural) return Agent_Genes is
      R : Agent_Genes := G;
   begin
      --  Deterministic light mutation keeps tests/replays reproducible.
      if Salt mod 2 = 0 then
         R.Bid_Aggressiveness := R.Bid_Aggressiveness + 0.02;
      else
         R.Bid_Aggressiveness := R.Bid_Aggressiveness - 0.02;
      end if;
      if Salt mod 3 = 0 then
         R.Target_Oversupply_Ratio := R.Target_Oversupply_Ratio + 0.03;
      else
         R.Target_Oversupply_Ratio := R.Target_Oversupply_Ratio - 0.02;
      end if;
      R.Bid_Aggressiveness := Clamp (R.Bid_Aggressiveness, 0.0, 1.0);
      R.Target_Oversupply_Ratio := Clamp (R.Target_Oversupply_Ratio, 1.0, 1.8);
      R.Wealth_Reserve_Fraction :=
        Clamp (R.Wealth_Reserve_Fraction, 0.0, 0.90);
      return R;
   end Mutate;

   function Crossover
     (Left, Right : Agent_Genes; Salt : Natural) return Agent_Genes
   is
      R : Agent_Genes :=
        (Bid_Aggressiveness      =>
           0.5 * (Left.Bid_Aggressiveness + Right.Bid_Aggressiveness),
         Prefer_Hold_Slots       =>
           (if Salt mod 2 = 0 then Left.Prefer_Hold_Slots
            else Right.Prefer_Hold_Slots),
         Target_Oversupply_Ratio =>
           0.5 * (Left.Target_Oversupply_Ratio
                  + Right.Target_Oversupply_Ratio),
         Max_Barges_Willingness  =>
           (Left.Max_Barges_Willingness + Right.Max_Barges_Willingness) / 2,
         Wealth_Reserve_Fraction =>
           0.5 * (Left.Wealth_Reserve_Fraction
                  + Right.Wealth_Reserve_Fraction));
   begin
      R := Mutate (R, Salt);
      return R;
   end Crossover;

   function Best_Agent (Population : Agent_Population) return Agent_Id is
      Best : Agent_Id := Agent_Id'First;
   begin
      for A in Agent_Id loop
         if Population (A).Fitness > Population (Best).Fitness then
            Best := A;
         end if;
      end loop;
      return Best;
   end Best_Agent;

   procedure Agent_Death
     (Population : in out Agent_Population;
      Victim     : Agent_Id)
   is
      Best : constant Agent_Id := Best_Agent (Population);
   begin
      Population (Victim).Genes :=
        Mutate (Population (Best).Genes, Natural (Victim) + 7);
      Population (Victim).Fitness := 0.0;
      Population (Victim).Barges_Bought := 0;
      Population (Victim).Hold_Booked_kg := 0.0;
      Population (Victim).Alive := True;
   end Agent_Death;

   procedure End_Generation (Population : in out Agent_Population) is
      Snapshot : constant Agent_Population := Population;
      First, Second : Agent_Id := Agent_Id'First;
   begin
      for A in Agent_Id loop
         if Snapshot (A).Fitness > Snapshot (First).Fitness then
            Second := First;
            First := A;
         elsif A /= First and then Snapshot (A).Fitness > Snapshot (Second).Fitness then
            Second := A;
         end if;
      end loop;

      --  Elites retain their genes; all other slots are offspring.
      for A in Agent_Id loop
         if A /= First and then A /= Second then
            Population (A).Genes :=
              Crossover (Snapshot (First).Genes, Snapshot (Second).Genes,
                         A);
         end if;
         Population (A).Fitness := 0.0;
         Population (A).Barges_Bought := 0;
         Population (A).Hold_Booked_kg := 0.0;
         Population (A).Alive := True;
      end loop;
   end End_Generation;

   procedure Prepare_Cell
     (Crew       : Positive;
      Distance_m : Float;
      Cap        : Natural;
      Horizon_s  : Float;
      Cell       : out Demand_Cell)
   is
      Rate : constant Float := Total_Demand_Rate_kg_s (Crew);
   begin
      Cell :=
        (Demand_Rate_kg_s => Rate,
         Stock_kg         => 0.0,
         Horizon_s        => Horizon_s,
         Distance_m       => Distance_m,
         Fleet            => [others => 0],
         Preferred        => Barge_Inner,
         Cell_Id          => Crew);
      declare
         Market : Barge_Market := Init_Barge_Market;
      begin
         --  The simulation allocation is deliberately ample: bids and ask
         --  escalation still apply, while the scenario isolates hull sizing
         --  from the old 1,000,000-coin demo purse.
         Market.Pool_Available := Cap;
         Market.Wealth := 100_000_000.0;
         Seed_Cell_With_Barge_Market (Cell, Market);
      end;
   end Prepare_Cell;

   function Try_Buy
     (Cell       : in out Demand_Cell;
      State      : in out Agent_State;
      Cap        : Natural;
      Distance_m : Float) return Boolean
   is
      Market : constant Barge_Market := Current_Barge_Market;
      Current : constant Float := Ratio (Cell);
      Target  : constant Float := Clamp (State.Genes.Target_Oversupply_Ratio,
                                         1.0, 1.8);
      Bid     : Float;
      Reserve : Float;
   begin
      if Cell.Fleet (Barge_Inner) >= Cap
        or else State.Barges_Bought >= State.Genes.Max_Barges_Willingness
        or else Market.Pool_Available = 0
        or else Distance_m <= 0.0
        or else (Current >= Target and then Current >= 1.0)
      then
         return False;
      end if;
      Bid := Market.Ask_Price * (1.0 + Clamp (State.Genes.Bid_Aggressiveness,
                                               0.0, 1.0));
      Reserve := Market.Wealth
        * Clamp (State.Genes.Wealth_Reserve_Fraction, 0.0, 0.90);
      if Bid > Market.Wealth - Reserve then
         return False;
      end if;
      if Bid_For_Barge (Cell, Bid) then
         State.Barges_Bought := State.Barges_Bought + 1;
         return True;
      end if;
      return False;
   end Try_Buy;

   procedure Run_Competing_Agents
     (Crew             : Positive := 150;
      N_Ticks          : Positive := 6000;
      Delta_s          : Float := 1_296_000.0;
      Distance_m       : Float := Mars_Offset_m;
      Barge_Cap        : Natural := Barge_Pool_Max;
      Population       : in out Agent_Population;
      Barges_Used      : out Natural;
      Mean_Deficit_kg  : out Float;
      Under_Fraction   : out Float;
      Achieved_Ratio   : out Float)
   is
      Cap : constant Natural := Effective_Cap (Barge_Cap);
      Cell : Demand_Cell;
      State : Tournament_State;
      Deficit_Sum : Float := 0.0;
      Under_Ticks : Natural := 0;
      Rate : Float;
   begin
      Barges_Used := 0;
      Mean_Deficit_kg := 0.0;
      Under_Fraction := 0.0;
      Achieved_Ratio := 0.0;
      if Delta_s <= 0.0 or else Distance_m <= 0.0 then
         return;
      end if;

      declare
         Need_Init : Boolean := True;
      begin
         for A in Agent_Id loop
            Need_Init := Need_Init
              and then Population (A).Genes.Max_Barges_Willingness = 0;
         end loop;
         if Need_Init then
            Initialize_Agents (Population);
         end if;
      end;
      Prepare_Cell (Crew, Distance_m, Cap, Delta_s, Cell);
      Rate := Cell.Demand_Rate_kg_s;

      for I in 1 .. N_Ticks loop
         --  Five turns, one shared market, one shared cell.  Hold preference
         --  affects cargo-slot bids; whole-hull bids remain the only way to
         --  increase throughput.
         for A in Agent_Id loop
            if Try_Buy (Cell, Population (A), Cap, Distance_m) then
               null;
            end if;
            if Population (A).Barges_Bought > 0
              and then Population (A).Genes.Prefer_Hold_Slots
              and then Remaining_Hold_kg (Cell) > 0.0
            then
               declare
                  Mass : constant Float :=
                    Float'Min (Rate * Delta_s, Remaining_Hold_kg (Cell));
                  M : constant Barge_Market := Current_Barge_Market;
                  Bid : constant Float := Ask_Per_Kg (M) * Mass;
                  Reserve : constant Float :=
                    M.Wealth * Clamp
                      (Population (A).Genes.Wealth_Reserve_Fraction, 0.0, 0.90);
                  Booked : Boolean;
               begin
                  if Mass > 0.0 and then Bid <= M.Wealth - Reserve then
                     Bid_Hold_Slot (Cell, Mass, Bid, Booked);
                     if Booked then
                        Population (A).Hold_Booked_kg :=
                          Population (A).Hold_Booked_kg + Mass;
                     end if;
                  end if;
               end;
            end if;
         end loop;

         Run_Tournament_Ticks
           (Cell    => Cell,
            State   => State,
            N_Ticks => 1,
            Delta_s => Delta_s,
            Log     => False,
            Evolve  => False);
         Deficit_Sum := Deficit_Sum + Deficit_kg (Cell);
         if Under_Served (Cell) then
            Under_Ticks := Under_Ticks + 1;
         end if;
      end loop;

      Barges_Used := Cell.Fleet (Barge_Inner);
      Mean_Deficit_kg := Deficit_Sum / Float (N_Ticks);
      Under_Fraction := Float (Under_Ticks) / Float (N_Ticks);
      Achieved_Ratio := Ratio (Cell);
      for A in Agent_Id loop
         Population (A).Fitness :=
           1.0 / (1.0 + Mean_Deficit_kg
                  + abs (Achieved_Ratio
                        - Clamp (Population (A).Genes.Target_Oversupply_Ratio,
                                 1.0, 1.8)));
      end loop;
   end Run_Competing_Agents;

   procedure Run_Limited_Barge_Agent
     (Crew           : Positive := 150;
      N_Ticks        : Positive := 6000;
      Delta_s        : Float := 1_296_000.0;
      Distance_m     : Float := Mars_Offset_m;
      Barge_Cap      : Natural := Barge_Pool_Max;
      Barges_Used    : out Natural;
      Undersupply_kg : out Float;
      Under_Fraction : out Float)
   is
      Population : Agent_Population;
      Achieved : Float;
   begin
      Initialize_Agents (Population);
      Run_Competing_Agents
        (Crew, N_Ticks, Delta_s, Distance_m, Barge_Cap, Population,
         Barges_Used, Undersupply_kg, Under_Fraction, Achieved);
   end Run_Limited_Barge_Agent;

   procedure Size_Min_Barges_Oversupply
     (Crew             : Positive := 150;
      N_Ticks          : Positive := 6000;
      Delta_s          : Float := 1_296_000.0;
      Distance_m       : Float := Mars_Offset_m;
      Oversupply_Cap   : Float := 1.80;
      Sweep_Min_Barges : Natural := 1;
      Min_Barges       : out Natural;
      Achieved_Ratio   : out Float;
      Ok               : out Boolean)
   is
      Population : Agent_Population;
      Used, Under_Count : Natural;
      Deficit, Fraction, Ratio_Value : Float;
      Start : constant Natural := Effective_Cap (Sweep_Min_Barges);
      Tail : constant Positive := Positive'Min (Sustained_Window_Ticks, N_Ticks);
   begin
      Min_Barges := 0;
      Achieved_Ratio := 0.0;
      Ok := False;
      if Delta_s <= 0.0 or else Distance_m <= 0.0
        or else Oversupply_Cap < 1.0
      then
         return;
      end if;

      --  Each candidate uses a fresh five-agent population and the same shared
      --  market/cell rules.  The final Tail ticks are the sustained window.
      for N in Start .. Barge_Pool_Max loop
         Initialize_Agents (Population);
         Run_Competing_Agents
           (Crew, Tail, Delta_s, Distance_m, N, Population,
            Used, Deficit, Fraction, Ratio_Value);
         Under_Count := Natural (Float (Tail) * Fraction);
         if Used >= N
           and then Ratio_Value >= 1.0
           and then Ratio_Value <= Oversupply_Cap
           and then Under_Count = 0
         then
            Min_Barges := N;
            Achieved_Ratio := Ratio_Value;
            Ok := True;
            return;
         end if;
      end loop;
   end Size_Min_Barges_Oversupply;

end Logistics_Module.Supply_Agents;
