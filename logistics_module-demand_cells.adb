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

   function Over_Served (Cell : Demand_Cell) return Boolean is
   begin
      return Deficit_kg (Cell) = 0.0
        and then Ship_Count (Cell) > 0
        and then Throughput_kg_s (Cell) > Cell.Demand_Rate_kg_s;
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
         & "Fleet_In_Flight,Lane_Capacity,Assign_Rejected");
      Close (F);
      Run_Open := True;
      Run_Len := Natural'Min (Path'Length, Run_Path'Length);
      Run_Path (1 .. Run_Len) := Path (Path'First .. Path'First + Run_Len - 1);
   end Begin_Sim_Run;


   procedure Append_Sim_Rows
     (Cell : Demand_Cell;
      T_s  : Float;
      Path : String := Sim_Log_Path)
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
         Put (F, '0');
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
         if Under_Served (Cell) then
            Best := Best_Species (Cell.Distance_m);
            Cell.Preferred := Best;
            Cell.Fleet (Best) := Cell.Fleet (Best) + 1;
         elsif Over_Served (Cell) then
            Worst := Worst_Present (Cell);
            if Cell.Fleet (Worst) > 0 then
               Cell.Fleet (Worst) := Cell.Fleet (Worst) - 1;
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
         Append_Sim_Rows (Cell, T_s, Path);
      end if;
   end Life_Tick;

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
