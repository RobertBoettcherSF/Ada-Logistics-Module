--  Demand_Cells: deficit, fitness fleet, Life_Tick, sim_run.csv log.

pragma Ada_2022;

with Ada.Calendar;
with Ada.Calendar.Formatting;
with Ada.Directories;
with Ada.Text_IO;
with Ada.Float_Text_IO;
with Ada.Strings.Fixed;

package body Logistics_Module.Demand_Cells is

   Run_Open : Boolean := False;
   Run_Path : String (1 .. 256) := [others => ' '];
   Run_Len  : Natural := 0;
   Shared_Barge_Market : Barge_Market :=
     (Pool_Available => Barge_Pool_Max,
      Pool_Owned     => 0,
      Ask_Price      => Barge_Unit_Price,
      Generation     => 0,
      Wealth         => Initial_Barge_Budget,
      Inherited      => 0.0,
      Hold_Capacity_kg => 0.0,
      Hold_Booked_kg   => 0.0);

   function Init_Barge_Market return Barge_Market is
   begin
      return
        (Pool_Available => Barge_Pool_Max,
         Pool_Owned     => 0,
         Ask_Price      => Barge_Unit_Price,
         Generation     => 0,
         Wealth         => Initial_Barge_Budget,
         Inherited      => 0.0,
         Hold_Capacity_kg => 0.0,
         Hold_Booked_kg   => 0.0);
   end Init_Barge_Market;

   procedure Init_Barge_Market (Market : out Barge_Market) is
   begin
      Market := Init_Barge_Market;
   end Init_Barge_Market;

   function Current_Barge_Market return Barge_Market is
   begin
      return Shared_Barge_Market;
   end Current_Barge_Market;

   procedure Clamp_Barge_Pool (Market : in out Barge_Market) is
      Max_Available : Natural;
   begin
      if Market.Pool_Owned > Barge_Pool_Max then
         Market.Pool_Owned := Barge_Pool_Max;
      end if;
      Max_Available := Barge_Pool_Max - Market.Pool_Owned;
      if Market.Pool_Available > Max_Available then
         Market.Pool_Available := Max_Available;
      end if;
      Market.Hold_Capacity_kg :=
        Float (Market.Pool_Owned) * Barge_Cargo_Mass_kg;
      if Market.Hold_Booked_kg < 0.0 then
         Market.Hold_Booked_kg := 0.0;
      elsif Market.Hold_Booked_kg > Market.Hold_Capacity_kg then
         -- A cull can remove a hull with open bookings.  Do not let old
         -- bookings make a newly available hull look over-filled.
         Market.Hold_Booked_kg := Market.Hold_Capacity_kg;
      end if;
      if Market.Ask_Price <= 0.0 then
         Market.Ask_Price := Barge_Unit_Price;
      end if;
      if Market.Wealth < 0.0 then
         Market.Wealth := 0.0;
      end if;
      if Market.Inherited < 0.0 then
         Market.Inherited := 0.0;
      end if;
   end Clamp_Barge_Pool;

   function Ask_Per_Kg (Market : Barge_Market) return Float is
   begin
      if Barge_Cargo_Mass_kg <= 0.0 then
         return 0.0;
      end if;
      return Market.Ask_Price / Barge_Cargo_Mass_kg;
   end Ask_Per_Kg;

   function Remaining_Hold_kg (Market : Barge_Market) return Float is
      Capacity : constant Float :=
        Float (Market.Pool_Owned) * Barge_Cargo_Mass_kg;
   begin
      if Capacity > Market.Hold_Booked_kg then
         return Capacity - Market.Hold_Booked_kg;
      else
         return 0.0;
      end if;
   end Remaining_Hold_kg;

   function Bid_Hold_Slot
     (Market     : in out Barge_Market;
      Mass_kg    : Float;
      Bid_Amount : Float) return Boolean
   is
      Minimum_Bid : Float;
   begin
      Clamp_Barge_Pool (Market);
      Minimum_Bid := Ask_Per_Kg (Market) * Mass_kg;
      if Mass_kg <= 0.0
        or else Mass_kg > Remaining_Hold_kg (Market)
        or else Bid_Amount < Minimum_Bid
        or else Bid_Amount > Market.Wealth
        or else Bid_Amount <= 0.0
      then
         return False;
      end if;

      Market.Wealth := Market.Wealth - Bid_Amount;
      Market.Hold_Booked_kg := Market.Hold_Booked_kg + Mass_kg;
      Clamp_Barge_Pool (Market);
      return True;
   end Bid_Hold_Slot;

   procedure Bid_Hold_Slot
     (Market     : in out Barge_Market;
      Mass_kg    : Float;
      Bid_Amount : Float;
      Success    : out Boolean)
   is
   begin
      Success := Bid_Hold_Slot (Market, Mass_kg, Bid_Amount);
   end Bid_Hold_Slot;

   function Bid_For_Barge
     (Market     : in out Barge_Market;
      Bid_Amount : Float) return Boolean
   is
   begin
      Clamp_Barge_Pool (Market);
      if Market.Pool_Owned >= Barge_Pool_Max
        or else Market.Pool_Available = 0
        or else Bid_Amount < Market.Ask_Price
        or else Bid_Amount > Market.Wealth
        or else Bid_Amount <= 0.0
      then
         return False;
      end if;

      Market.Wealth := Market.Wealth - Bid_Amount;
      Market.Pool_Owned := Market.Pool_Owned + 1;
      Market.Pool_Available := Market.Pool_Available - 1;
      -- A successful bid makes the next barge one percent dearer.  This is
      -- intentionally a small educational market signal, not a currency API.
      Market.Ask_Price := Market.Ask_Price * 1.01;
      Clamp_Barge_Pool (Market);
      return True;
   end Bid_For_Barge;

   procedure End_Generation (Market : in out Barge_Market) is
   begin
      Clamp_Barge_Pool (Market);
      -- Demo coins are inherited in full; barges remain owned by the family.
      Market.Inherited := Market.Wealth;
      Market.Wealth := Market.Inherited;
      if Market.Generation < Generation_Id'Last then
         Market.Generation := Market.Generation + 1;
      end if;
   end End_Generation;

   function Profile_Of (S : Fleet_Species) return Species_Profile is
   begin
      case S is
         when Barge_Inner =>
            return Barge_Inner_Profile;
         when Fast_Courier =>
            return Fast_Courier_Profile;
         when Relativistic_Stub =>
            return Relativistic_Stub_Profile;
      end case;
   end Profile_Of;

   function Cruise_Speed_m_s (S : Fleet_Species) return Float is
      P : constant Species_Profile := Profile_Of (S);
   begin
      pragma Assert (P.Cruise_Speed_m_s < Float (c_m_s));
      return P.Cruise_Speed_m_s;
   end Cruise_Speed_m_s;

   function Effective_Cargo_Mass_kg
     (S : Fleet_Species; World : World_Body) return Float
   is
      pragma Unreferenced (World);
   begin
      -- World derating is deliberately left as a later exercise: this
      -- table keeps the profile payload stable while exposing the seam.
      return Profile_Of (S).Cargo_Mass_kg;
   end Effective_Cargo_Mass_kg;

   function Cost_Factor
     (S : Fleet_Species; World : World_Body) return Float
   is
   begin
      case S is
         when Barge_Inner =>
            case World is
               when Terra_0 | Moon_Polar => return 1.0;
               when Mars                  => return 1.5;
               when Titan                 => return 2.0;
               when Venus_Cloud_Port      => return 1.3;
            end case;
         when Fast_Courier =>
            case World is
               when Terra_0                => return 0.8;
               when Moon_Polar              => return 1.0;
               when Mars                    => return 1.8;
               when Titan                   => return 2.5;
               when Venus_Cloud_Port        => return 1.4;
            end case;
         when Relativistic_Stub =>
            case World is
               when Terra_0                => return 2.0;
               when Moon_Polar              => return 3.0;
               when Mars                    => return 5.0;
               when Titan                   => return 6.0;
               when Venus_Cloud_Port        => return 4.0;
            end case;
      end case;
   end Cost_Factor;

   function Demand_Rate_kg_s
     (Crew              : Natural;
      Kg_Per_Person_Day : Float := Consumables_kg_person_day) return Float
   is
   begin
      return Float (Crew) * Kg_Per_Person_Day / Seconds_Per_Day_s;
   end Demand_Rate_kg_s;

   function Min_Cruise_Speed_m_s
     (Demand_Rate_kg_s : Float;
      Distance_m       : Float;
      Cargo_Mass_kg    : Float) return Float
   is
   begin
      return Demand_Rate_kg_s * 2.0 * Distance_m / Cargo_Mass_kg;
   end Min_Cruise_Speed_m_s;

   function Barge_Market_Of (Cell : Demand_Cell) return Barge_Market is
      pragma Unreferenced (Cell);
   begin
      return Shared_Barge_Market;
   end Barge_Market_Of;

   procedure Seed_Cell_With_Barge_Market
     (Cell : in out Demand_Cell)
   is
      pragma Unreferenced (Cell);
   begin
      Shared_Barge_Market := Init_Barge_Market;
   end Seed_Cell_With_Barge_Market;

   procedure Seed_Cell_With_Barge_Market
     (Cell   : in out Demand_Cell;
      Market : Barge_Market)
   is
      pragma Unreferenced (Cell);
   begin
      Shared_Barge_Market := Market;
      Clamp_Barge_Pool (Shared_Barge_Market);
   end Seed_Cell_With_Barge_Market;

   procedure Try_Barge_Bid (Cell : in out Demand_Cell);

   procedure Clamp_Barge_Pool (Cell : in out Demand_Cell) is
   begin
      Clamp_Barge_Pool (Shared_Barge_Market);
      -- Under-served demand tries to establish the policy floor, but every
      -- unit still goes through the normal ask/wealth/pool checks.
      if Cell.Distance_m > 0.0 and then Under_Served (Cell) then
         while Shared_Barge_Market.Pool_Owned < Barge_Pool_Min
           and then Shared_Barge_Market.Pool_Available > 0
           and then Shared_Barge_Market.Wealth >= Shared_Barge_Market.Ask_Price
         loop
            Try_Barge_Bid (Cell);
         end loop;
      end if;
   end Clamp_Barge_Pool;

   function Bid_For_Barge
     (Cell       : in out Demand_Cell;
      Bid_Amount : Float) return Boolean
   is
   begin
      if Bid_For_Barge (Shared_Barge_Market, Bid_Amount) then
         Cell.Fleet (Barge_Inner) := Cell.Fleet (Barge_Inner) + 1;
         return True;
      end if;
      return False;
   end Bid_For_Barge;

   procedure Bid_For_Barge
     (Market     : in out Barge_Market;
      Bid_Amount : Float;
      Success    : out Boolean)
   is
   begin
      Success := Bid_For_Barge (Market, Bid_Amount);
   end Bid_For_Barge;

   procedure Bid_For_Barge
     (Cell       : in out Demand_Cell;
      Bid_Amount : Float;
      Success    : out Boolean)
   is
   begin
      Success := Bid_For_Barge (Cell, Bid_Amount);
   end Bid_For_Barge;

   function Remaining_Hold_kg (Cell : Demand_Cell) return Float is
      pragma Unreferenced (Cell);
   begin
      return Remaining_Hold_kg (Shared_Barge_Market);
   end Remaining_Hold_kg;

   function Bid_Hold_Slot
     (Cell       : in out Demand_Cell;
      Mass_kg    : Float;
      Bid_Amount : Float) return Boolean
   is
      pragma Unreferenced (Cell);
   begin
      return Bid_Hold_Slot (Shared_Barge_Market, Mass_kg, Bid_Amount);
   end Bid_Hold_Slot;

   procedure Bid_Hold_Slot
     (Cell       : in out Demand_Cell;
      Mass_kg    : Float;
      Bid_Amount : Float;
      Success    : out Boolean)
   is
   begin
      Success := Bid_Hold_Slot (Cell, Mass_kg, Bid_Amount);
   end Bid_Hold_Slot;


   function Can_Buy_Barge return Boolean is
   begin
      return Shared_Barge_Market.Pool_Owned < Barge_Pool_Max
        and then Shared_Barge_Market.Pool_Available > 0
        and then Shared_Barge_Market.Wealth
          >= Shared_Barge_Market.Ask_Price;
   end Can_Buy_Barge;

   procedure Escalate_Under_Served
     (Cell : in out Demand_Cell;
      W    : Fleet_Species)
   is
      Target : Fleet_Species := W;
   begin
      -- When barges cannot be bought (pool max or wealth < ask), spawn the
      -- fitness-best class for this distance (never another barge) so long
      -- runs keep climbing toward service instead of freezing.
      if Cell.Distance_m > 0.0 then
         Target := Best_Species (Cell.Distance_m);
      end if;
      if Target = Barge_Inner then
         if W = Relativistic_Stub then
            Target := Relativistic_Stub;
         else
            Target := Fast_Courier;
         end if;
      end if;
      Cell.Fleet (Target) := Cell.Fleet (Target) + 1;
      Cell.Preferred := Target;
   end Escalate_Under_Served;

   procedure Try_Barge_Bid (Cell : in out Demand_Cell) is
   begin
      if Bid_For_Barge (Cell, Shared_Barge_Market.Ask_Price) then
         null;
      end if;
   end Try_Barge_Bid;

   function Try_Hold_Bid (Cell : in out Demand_Cell) return Boolean is
      Need      : constant Float := Deficit_kg (Cell);
      Remaining : constant Float := Remaining_Hold_kg (Cell);
      Mass      : constant Float := Float'Min (Need, Remaining);
      Bid       : constant Float := Ask_Per_Kg (Shared_Barge_Market) * Mass;
   begin
      if Cell.Fleet (Barge_Inner) = 0
        or else Shared_Barge_Market.Pool_Owned = 0
        or else Mass <= 0.0
        or else Bid > Shared_Barge_Market.Wealth
      then
         return False;
      end if;
      return Bid_Hold_Slot (Cell, Mass, Bid);
   end Try_Hold_Bid;

   procedure End_Generation (Cell : in out Demand_Cell) is
   begin
      On_Demand_Death (Cell);
      End_Generation (Shared_Barge_Market);
      On_Demand_Birth (Cell);
   end End_Generation;

   function Ship_Count (Cell : Demand_Cell) return Natural is
      N : Natural := 0;
   begin
      for S in Fleet_Species loop
         N := N + Cell.Fleet (S);
      end loop;
      return N;
   end Ship_Count;

   function Ship_Count
     (Cell : Demand_Cell; S : Fleet_Species) return Natural
   is
   begin
      return Cell.Fleet (S);
   end Ship_Count;

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
      C : constant Float := Profile_Of (Cell.Preferred).Cargo_Mass_kg;
   begin
      if D <= 0.0 or else C <= 0.0 then
         return 0;
      end if;
      return Natural (Float'Ceiling (D / C));
   end Shipments_Needed;

   function Transit_Duration_s
     (Distance_m : Float; S : Fleet_Species) return Float
   is
   begin
      return Distance_m / Cruise_Speed_m_s (S);
   end Transit_Duration_s;

   function Transit_Duration_s
     (A, B : World_Body;
      S    : Fleet_Species;
      T_s  : Float := 0.0) return Float
   is
   begin
      return Transit_Duration_s (Logistics_Module.Distance_m (A, B, T_s), S);
   end Transit_Duration_s;

   function Transit_Duration_s (Cell : Demand_Cell) return Float is
   begin
      return Transit_Duration_s (Cell.Distance_m, Cell.Preferred);
   end Transit_Duration_s;

   function Throughput_kg_s
     (S          : Fleet_Species;
      Distance_m : Float;
      Count      : Natural := 1) return Float
   is
      P : constant Species_Profile := Profile_Of (S);
      T : constant Float := Transit_Duration_s (Distance_m, S);
   begin
      if Count = 0 or else T <= 0.0 then
         return 0.0;
      end if;
      return Float (Count) * P.Cargo_Mass_kg / (2.0 * T);
   end Throughput_kg_s;

   function Throughput_kg_s (Cell : Demand_Cell) return Float is
      Sum : Float := 0.0;
   begin
      if Cell.Distance_m <= 0.0 then
         return 0.0;
      end if;
      for S in Fleet_Species loop
         if Cell.Fleet (S) > 0 then
            Sum := Sum + Throughput_kg_s (S, Cell.Distance_m, Cell.Fleet (S));
         end if;
      end loop;
      return Sum;
   end Throughput_kg_s;

   function Fitness
     (S          : Fleet_Species;
      Distance_m : Float;
      Count      : Natural := 1) return Float
   is
      P   : constant Species_Profile := Profile_Of (S);
      Thr : constant Float := Throughput_kg_s (S, Distance_m, Count);
      Den : constant Float := Float (Count) * P.Gross_Mass_kg;
   begin
      if Den <= 0.0 then
         return 0.0;
      end if;
      return Thr / Den;
   end Fitness;

   function Fuel_Mass_kg (S : Fleet_Species) return Float is
      V : constant Float := Cruise_Speed_m_s (S);
      R : constant Float := V / Speed_Ref_m_s;
   begin
      return Fuel_Coeff_kg * R * R;
   end Fuel_Mass_kg;

   function Payload_Net_kg (S : Fleet_Species) return Float is
      P    : constant Species_Profile := Profile_Of (S);
      Fuel : constant Float := Fuel_Mass_kg (S);
      Net  : constant Float := P.Cargo_Mass_kg - Fuel;
   begin
      if Net > 0.0 then
         return Net;
      else
         return 0.0;
      end if;
   end Payload_Net_kg;

   function Score_kg_s
     (S          : Fleet_Species;
      Distance_m : Float) return Float
   is
      Tr  : constant Float := Transit_Duration_s (Distance_m, S);
      Net : constant Float := Payload_Net_kg (S);
   begin
      if Tr <= 0.0 then
         return 0.0;
      end if;
      -- One-way default. Optional round-trip: Score_kg_s / 2.0 externally.
      return Net / Tr;
   end Score_kg_s;

   function Score_Ref_kg_s (Distance_m : Float) return Float is
   begin
      return Score_kg_s (Barge_Inner, Distance_m);
   end Score_Ref_kg_s;

   function Reward_Coin
     (S          : Fleet_Species;
      Distance_m : Float;
      Score_Ref  : Float) return Float
   is
      Sc : constant Float := Score_kg_s (S, Distance_m);
   begin
      if Score_Ref <= 0.0 then
         return 0.0;
      end if;
      return Reward_Coin_Base * (Sc / Score_Ref);
   end Reward_Coin;

   procedure Accrue_Rewards
     (State      : in out Tournament_State;
      Distance_m : Float)
   is
      Ref : Float;
      Sc  : Float;
   begin
      if State.Score_Ref_kg_s <= 0.0 then
         State.Distance_Ref_m := Distance_m;
         State.Score_Ref_kg_s := Score_Ref_kg_s (Distance_m);
      end if;
      Ref := State.Score_Ref_kg_s;
      for S in Fleet_Species loop
         Sc := Score_kg_s (S, Distance_m);
         State.Scores (S) := Sc;
         State.Fuel (S) := Fuel_Mass_kg (S);
         State.Payload (S) := Payload_Net_kg (S);
         State.Rewards (S) :=
           State.Rewards (S) + Reward_Coin (S, Distance_m, Ref);
      end loop;
   end Accrue_Rewards;

   function Tournament_Winner
     (State      : Tournament_State;
      Distance_m : Float) return Fleet_Species
   is
      Best : Fleet_Species := Barge_Inner;
      R, Rb : Float;
      F, Fb : Float;
   begin
      Rb := State.Rewards (Best);
      Fb := Fitness (Best, Distance_m, 1);
      for S in Fleet_Species loop
         R := State.Rewards (S);
         F := Fitness (S, Distance_m, 1);
         if R > Rb or else (R = Rb and then F > Fb) then
            Rb := R;
            Fb := F;
            Best := S;
         end if;
      end loop;
      return Best;
   end Tournament_Winner;

   function Beta_Of (S : Fleet_Species) return Float is
   begin
      return Cruise_Speed_m_s (S) / Float (c_m_s);
   end Beta_Of;

   function Best_Species (Distance_m : Float) return Fleet_Species is
      Best : Fleet_Species := Barge_Inner;
      F, Fb : Float;
   begin
      Fb := Fitness (Best, Distance_m, 1);
      for S in Fleet_Species loop
         F := Fitness (S, Distance_m, 1);
         if F > Fb then
            Fb := F;
            Best := S;
         end if;
      end loop;
      return Best;
   end Best_Species;

   function Worst_Present (Cell : Demand_Cell) return Fleet_Species is
      Worst : Fleet_Species := Cell.Preferred;
      Found : Boolean := False;
      F, Fw : Float := 0.0;
   begin
      for S in Fleet_Species loop
         if Cell.Fleet (S) > 0 then
            F := Fitness (S, Cell.Distance_m, 1);
            if not Found or else F < Fw then
               Found := True;
               Fw := F;
               Worst := S;
            end if;
         end if;
      end loop;
      return Worst;
   end Worst_Present;

   function Under_Served (Cell : Demand_Cell) return Boolean is
   begin
      return Deficit_kg (Cell) > 0.0
        and then Throughput_kg_s (Cell) < Cell.Demand_Rate_kg_s;
   end Under_Served;

   function Over_Supply_Ratio (Cell : Demand_Cell) return Float is
   begin
      if Cell.Demand_Rate_kg_s <= 0.0 then
         return 0.0;
      end if;
      return Throughput_kg_s (Cell) / Cell.Demand_Rate_kg_s;
   end Over_Supply_Ratio;

   function Over_Served (Cell : Demand_Cell) return Boolean is
   begin
      return Deficit_kg (Cell) = 0.0
        and then Ship_Count (Cell) > 0
        and then Over_Supply_Ratio (Cell) > 1.0;
   end Over_Served;

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

   procedure Put_Sci (File : Ada.Text_IO.File_Type; X : Float) is
   begin
      Ada.Float_Text_IO.Put (File, X, Fore => 1, Aft => 8, Exp => 3);
   end Put_Sci;

   function Trim_Img (S : String) return String is
   begin
      return Ada.Strings.Fixed.Trim (S, Ada.Strings.Both);
   end Trim_Img;

   function Default_Run_Id return String is
      use Ada.Calendar;
      N : constant Time := Clock;
   begin
      return Ada.Calendar.Formatting.Image (N);
   end Default_Run_Id;

   procedure Begin_Sim_Run
     (Time_Rate : Float;
      Path      : String := Sim_Log_Path;
      Run_Id    : String := "")
   is
      use Ada.Text_IO;
      F   : File_Type;
      Rid : constant String :=
        (if Run_Id'Length = 0 then Default_Run_Id else Run_Id);
   begin
      Create (F, Out_File, Path);
      Put (F, "# run_id=");
      Put (F, Rid);
      Put (F, " Time_Rate=");
      Put_Sci (F, Time_Rate);
      Put (F, " AU_m=");
      Put_Sci (F, AU_m);
      Put (F, " c_m_s=");
      Put (F, Trim_Img (c_m_s'Image));
      New_Line (F);
      Put_Line
        (F,
         "t_s,cell_id,Demand_Rate_kg_s,Stock_kg,Deficit_kg,species,"
         & "Ship_Count,Cruise_Speed_m_s,Cargo_Mass_kg,Gross_Mass_kg,"
         & "Distance_m,Transit_Duration_s,Throughput_kg_s,Fitness,beta,c_m_s,"
         & "Fleet_In_Flight,Lane_Capacity,Assign_Rejected,"
         & "Score_kg_s,Reward_Coin,Fuel_Mass_kg,Payload_Net_kg");
      Close (F);
      Run_Open := True;
      Run_Len := Natural'Min (Path'Length, Run_Path'Length);
      Run_Path (1 .. Run_Len) := Path (Path'First .. Path'First + Run_Len - 1);
   end Begin_Sim_Run;


   procedure Append_Sim_Rows
     (Cell     : Demand_Cell;
      T_s      : Float;
      Path     : String := Sim_Log_Path;
      Scores   : Species_Scores := [others => 0.0];
      Rewards  : Species_Rewards := [others => 0.0];
      Fuel     : Species_Fuel := [others => 0.0];
      Payload  : Species_Payload := [others => 0.0])
   is
      use Ada.Text_IO;
      F    : File_Type;
      P    : Species_Profile;
      Def  : constant Float := Deficit_kg (Cell);
      Tr, Thr, Fit, B : Float;
      N    : Natural;
   begin
      Open (F, Append_File, Path);
      for S in Fleet_Species loop
         P := Profile_Of (S);
         N := Cell.Fleet (S);
         if Cell.Distance_m > 0.0 then
            Tr := Transit_Duration_s (Cell.Distance_m, S);
            Thr := Throughput_kg_s (S, Cell.Distance_m, N);
            if N > 0 then
               Fit := Fitness (S, Cell.Distance_m, N);
            else
               Fit := Fitness (S, Cell.Distance_m, 1);
            end if;
         else
            Tr := 0.0;
            Thr := 0.0;
            Fit := 0.0;
         end if;
         B := Beta_Of (S);

         Put_Sci (F, T_s); Put (F, ',');
         Put (F, Trim_Img (Cell.Cell_Id'Image)); Put (F, ',');
         Put_Sci (F, Cell.Demand_Rate_kg_s); Put (F, ',');
         Put_Sci (F, Cell.Stock_kg); Put (F, ',');
         Put_Sci (F, Def); Put (F, ',');
         Put (F, Trim_Img (S'Image)); Put (F, ',');
         Put (F, Trim_Img (N'Image)); Put (F, ',');
         Put_Sci (F, P.Cruise_Speed_m_s); Put (F, ',');
         Put_Sci (F, P.Cargo_Mass_kg); Put (F, ',');
         Put_Sci (F, P.Gross_Mass_kg); Put (F, ',');
         Put_Sci (F, Cell.Distance_m); Put (F, ',');
         Put_Sci (F, Tr); Put (F, ',');
         Put_Sci (F, Thr); Put (F, ',');
         Put_Sci (F, Fit); Put (F, ',');
         Put_Sci (F, B); Put (F, ',');
         Put (F, Trim_Img (c_m_s'Image)); Put (F, ',');
         -- ATC columns (Fitness path logs zeros; ATC package logs real lane SI)
         Put (F, '0'); Put (F, ',');
         Put (F, '0'); Put (F, ',');
         Put (F, '0'); Put (F, ',');
         Put_Sci (F, Scores (S)); Put (F, ',');
         Put_Sci (F, Rewards (S)); Put (F, ',');
         Put_Sci (F, Fuel (S)); Put (F, ',');
         Put_Sci (F, Payload (S));
         New_Line (F);
      end loop;
      Close (F);
   end Append_Sim_Rows;

   procedure Life_Tick
     (Cell      : in out Demand_Cell;
      Delta_s   : Float;
      T_s       : Float := 0.0;
      Log       : Boolean := True;
      Path      : String := Sim_Log_Path;
      Time_Rate : Float := 1.0)
   is
      Best  : Fleet_Species;
      Worst : Fleet_Species;
   begin
      Tick_Cell (Cell, Delta_s);
      if Cell.Distance_m > 0.0 then
         Clamp_Barge_Pool (Cell);
         if Under_Served (Cell) then
            Best := Best_Species (Cell.Distance_m);
            Cell.Preferred := Best;
            -- Fill an owned hull before buying another one.  A slot is paid
            -- for by mass; Fitness/throughput remains hull based.
            if not Try_Hold_Bid (Cell) then
               if Best = Barge_Inner then
                  -- Barges are scarce capital: only a successful market bid may
                  -- add one.  If the market cannot clear ask (or the pool is
                  -- exhausted), escalate to faster classes.
                  if Can_Buy_Barge then
                     Try_Barge_Bid (Cell);
                  else
                     Escalate_Under_Served (Cell, Best);
                  end if;
               else
                  Cell.Fleet (Best) := Cell.Fleet (Best) + 1;
               end if;
            end if;
         elsif Over_Served (Cell) then
            Worst := Worst_Present (Cell);
            if Cell.Fleet (Worst) > 0 then
               Cell.Fleet (Worst) := Cell.Fleet (Worst) - 1;
               if Worst = Barge_Inner then
                  if Shared_Barge_Market.Pool_Owned > 0 then
                     Shared_Barge_Market.Pool_Owned := Shared_Barge_Market.Pool_Owned - 1;
                     if Shared_Barge_Market.Pool_Available < Barge_Pool_Max then
                        Shared_Barge_Market.Pool_Available :=
                          Shared_Barge_Market.Pool_Available + 1;
                     end if;
                     -- A sale/cull returns half the current ask to the
                     -- generation treasury, preserving a useful sink.
                     Shared_Barge_Market.Wealth := Shared_Barge_Market.Wealth
                       + 0.5 * Shared_Barge_Market.Ask_Price;
                     Clamp_Barge_Pool (Cell);
                  end if;
               end if;
            end if;
         end if;
      end if;
      if Log then
         if not Run_Open
           or else Run_Len /= Path'Length
           or else Run_Path (1 .. Run_Len) /= Path
         then
            Begin_Sim_Run (Time_Rate, Path);
         elsif not Ada.Directories.Exists (Path) then
            Begin_Sim_Run (Time_Rate, Path);
         end if;
         declare
            Scores  : Species_Scores := [others => 0.0];
            Rewards : Species_Rewards := [others => 0.0];
            Fuel    : Species_Fuel := [others => 0.0];
            Payload : Species_Payload := [others => 0.0];
            Ref     : Float;
         begin
            -- SI-audit: expose Fuel_Mass_kg / Score_kg_s on evo path too
            if Cell.Distance_m > 0.0 then
               Ref := Score_Ref_kg_s (Cell.Distance_m);
               for S in Fleet_Species loop
                  Fuel (S) := Fuel_Mass_kg (S);
                  Payload (S) := Payload_Net_kg (S);
                  Scores (S) := Score_kg_s (S, Cell.Distance_m);
                  if Ref > 0.0 then
                     Rewards (S) := Reward_Coin (S, Cell.Distance_m, Ref);
                  end if;
               end loop;
            end if;
            Append_Sim_Rows
              (Cell, T_s, Path,
               Scores  => Scores,
               Rewards => Rewards,
               Fuel    => Fuel,
               Payload => Payload);
         end;
      end if;
   end Life_Tick;

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
   is
      T     : Float := T0_s;
      W     : Fleet_Species;
      Worst : Fleet_Species;
   begin
      State.Active := True;
      if Cell.Distance_m > 0.0 then
         if State.Score_Ref_kg_s <= 0.0 then
            State.Distance_Ref_m := Cell.Distance_m;
            State.Score_Ref_kg_s := Score_Ref_kg_s (Cell.Distance_m);
         end if;
      end if;

      if Log then
         if not Run_Open
           or else Run_Len /= Path'Length
           or else Run_Path (1 .. Run_Len) /= Path
         then
            Begin_Sim_Run (Time_Rate, Path);
         elsif not Ada.Directories.Exists (Path) then
            Begin_Sim_Run (Time_Rate, Path);
         end if;
      end if;

      for I in 1 .. N_Ticks loop
         if Cell.Distance_m > 0.0 then
            Accrue_Rewards (State, Cell.Distance_m);
            W := Tournament_Winner (State, Cell.Distance_m);
            --  Haul income: this tick's Reward_Coin only (not cumulative State).
            declare
               Income : Float := 0.0;
               Ref    : constant Float := State.Score_Ref_kg_s;
            begin
               if Ref > 0.0 then
                  for S in Fleet_Species loop
                     Income := Income
                       + Reward_Coin (S, Cell.Distance_m, Ref);
                  end loop;
               end if;
               -- Scale: dimensionless reward → market coin via ask.
               if Income > 0.0 then
                  Shared_Barge_Market.Wealth :=
                    Shared_Barge_Market.Wealth
                      + Income * 0.05 * Shared_Barge_Market.Ask_Price;
               end if;
            end;
            -- Soft generation handoff every 500 ticks (genes + wealth carry).
            if I mod 500 = 0 then
               End_Generation (Shared_Barge_Market);
            end if;
         else
            W := Cell.Preferred;
         end if;

         Tick_Cell (Cell, Delta_s);
         if Evolve and then Cell.Distance_m > 0.0 then
            Clamp_Barge_Pool (Cell);
            if Under_Served (Cell) then
               -- Bias spawn to max Score/Reward winners (Fitness formula untouched).
               Cell.Preferred := W;
               if not Try_Hold_Bid (Cell) then
                  if Can_Buy_Barge and then W = Barge_Inner then
                     Try_Barge_Bid (Cell);
                  elsif Can_Buy_Barge then
                     Cell.Fleet (W) := Cell.Fleet (W) + 1;
                  else
                     -- Pool maxed or wealth < ask: escalate so long runs do
                     -- not freeze on barges alone while still under-served.
                     Escalate_Under_Served (Cell, W);
                  end if;
               end if;
            elsif Over_Served (Cell) then
               Worst := Worst_Present (Cell);
               if Cell.Fleet (Worst) > 0 then
                  Cell.Fleet (Worst) := Cell.Fleet (Worst) - 1;
                  if Worst = Barge_Inner
                    and then Shared_Barge_Market.Pool_Owned > 0
                  then
                     Shared_Barge_Market.Pool_Owned := Shared_Barge_Market.Pool_Owned - 1;
                     if Shared_Barge_Market.Pool_Available < Barge_Pool_Max then
                        Shared_Barge_Market.Pool_Available :=
                          Shared_Barge_Market.Pool_Available + 1;
                     end if;
                     Shared_Barge_Market.Wealth := Shared_Barge_Market.Wealth
                       + 0.5 * Shared_Barge_Market.Ask_Price;
                     Clamp_Barge_Pool (Cell);
                  end if;
               end if;
            end if;
         end if;

         if Log then
            Append_Sim_Rows
              (Cell, T, Path,
               Scores  => State.Scores,
               Rewards => State.Rewards,
               Fuel    => State.Fuel,
               Payload => State.Payload);
         end if;
         T := T + Delta_s;
      end loop;
   end Run_Tournament_Ticks;

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
      null;
   end On_Demand_Birth;

   procedure On_Demand_Death (Cell : in out Demand_Cell) is
      pragma Unreferenced (Cell);
   begin
      null;
   end On_Demand_Death;

end Logistics_Module.Demand_Cells;
