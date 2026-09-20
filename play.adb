--  MVP Text_IO play loop: jobs / assign / tick / quit.

pragma Ada_2022;

with Ada.Text_IO;          use Ada.Text_IO;
with Ada.Strings.Fixed;
with Logistics_Module;     use Logistics_Module;
with Logistics_Module.Demand_Cells;
use Logistics_Module.Demand_Cells;

procedure Play is
   C     : Company;
   A, B  : City_Id;
   Vid   : Vehicle_Id;
   Oid1, Oid2 : Order_Id;
   Ok    : Boolean;
   Line  : String (1 .. 80);
   Last  : Natural;
   Cmd   : Character;
   Sp_V, Sp_M : Spaceport_Id;

   procedure Seed is
   begin
      C := Create_Company (50_000.00, 0);
      Set_Time_Rate (C, 60.0);  -- demo pace
      Add_City (C, "Depot", False, False, Id => A);
      Add_City (C, "Hub", False, False, Id => B);
      Add_Vehicle (C, Light_Van, Flatbed, True, 4, 5_000.00, Vid, Ok);
      Create_Order
        (C, A, B, Flatbed_Cargo, 2, 1_200.00, Oid1, Ok);
      Create_Order
        (C, B, A, Flatbed_Cargo, 1, 900.00, Oid2, Ok);
      -- Optional spaceport catalog (list with [s])
      declare
         Ok_Sp : Boolean;
      begin
         Add_Spaceport
           (C, "VenusFloat", Venus_Cloud_Port, 20_000, Sp_V, Ok_Sp);
         Add_Spaceport
           (C, "LunaRelay", Moon_Polar, 10_000, Sp_M, Ok_Sp);
      end;
      Begin_Sim_Run (Time_Rate_Of (C), Sim_Log_Path);
   end Seed;

   procedure Show_Jobs is
      O : Order_Record;
   begin
      Put_Line ("-- jobs (Time_Rate=" & Time_Rate_Of (C)'Image & ") --");
      for I in Order_Id range 1 .. Order_Id (Order_Count (C)) loop
         O := Get_Order (C, I);
         Put ("  #" & I'Image & " " & O.Status'Image);
         Put (" FE" & O.Amount_FE'Image & " pay" & O.Payment'Image);
         if O.Status = En_Route then
            Put (" ETA" & O.ETA_s'Image & "s el" & O.Elapsed_s'Image
                 & "s dist" & O.Distance_m'Image & "m");
         end if;
         New_Line;
      end loop;
      Put_Line ("vehicles: " & Vehicle_Count (C)'Image
               & "  cash:" & Cash (C)'Image);
   end Show_Jobs;


   Demo_Cell : Demand_Cell :=
     (Demand_Rate_kg_s => 50.0,
      Stock_kg         => 0.0,
      Horizon_s        => 86_400.0,
      Distance_m       => AU_m,
      Fleet            => [Barge_Inner => 1, others => 0],
      Preferred        => Barge_Inner,
      Cell_Id          => 1);
   Demo_T_s : Float := 0.0;

   procedure Show_Evo is
      Dist : constant Float := Demo_Cell.Distance_m;
   begin
      Put_Line ("-- evolutionary fleet --");
      Put_Line ("  c=" & c_m_s'Image & " m/s  AU=" & AU_m'Image & " m");
      Put_Line ("  Dist=" & Dist'Image & " m  deficit="
                & Deficit_kg (Demo_Cell)'Image & " kg");
      Put_Line ("  thr=" & Throughput_kg_s (Demo_Cell)'Image
                & " kg/s  ships=" & Ship_Count (Demo_Cell)'Image
                & " pref=" & Demo_Cell.Preferred'Image);
      for S in Fleet_Species loop
         Put ("  " & S'Image
              & " n=" & Demo_Cell.Fleet (S)'Image
              & " cruise=" & Cruise_Speed_m_s (S)'Image
              & " fit=");
         if Dist > 0.0 then
            Put (Fitness (S, Dist, 1)'Image);
         else
            Put (" n/a");
         end if;
         New_Line;
      end loop;
      Put_Line ("  best=" & Best_Species (Dist)'Image
                & " under=" & Under_Served (Demo_Cell)'Image
                & " over=" & Over_Served (Demo_Cell)'Image);
   end Show_Evo;

   procedure Show_Spaceports is
      Sp : Spaceport_Record;
      P  : World_Body_Profile;
   begin
      Put_Line ("-- spaceports --");
      if Spaceport_Count (C) = 0 then
         Put_Line ("  (none)");
         return;
      end if;
      for I in Spaceport_Id range 1 .. Spaceport_Id (Spaceport_Count (C)) loop
         Sp := Get_Spaceport (C, I);
         P := Spaceport_Profile (C, I);
         Put ("  #" & I'Image & " " & Spaceport_Name (C, I));
         Put (" " & Sp.World'Image & " " & Sp.Status'Image);
         Put (" lim" & Sp.Pad_Limit_kg'Image & "kg");
         Put (" P" & P.Ext_Pressure_kPa'Image & "kPa");
         Put (" alt" & P.Altitude_m'Image & "m");
         Put (" g" & P.Gravity_g'Image);
         if Sp.Status = Pad_Status'Val (1) then
            Put (" repair_h" & Sp.Repair_Hours_Left'Image);
         end if;
         New_Line;
      end loop;
   end Show_Spaceports;

   procedure Do_Assign is
      Oraw, Vraw : String (1 .. 20);
      OL, VL     : Natural;
      Onum, Vnum : Integer;
      Dist       : constant Float := 22_000.0;  -- 1000 s @ Road 22 m/s
   begin
      Put ("order id: ");
      Get_Line (Oraw, OL);
      Put ("vehicle id: ");
      Get_Line (Vraw, VL);
      begin
         Onum := Integer'Value (Ada.Strings.Fixed.Trim
           (Oraw (1 .. OL), Ada.Strings.Both));
         Vnum := Integer'Value (Ada.Strings.Fixed.Trim
           (Vraw (1 .. VL), Ada.Strings.Both));
      exception
         when others =>
            Put_Line ("bad id");
            return;
      end;
      if Onum < 1 or else Vnum < 1 then
         Put_Line ("bad id");
         return;
      end if;
      Assign_Vehicle
        (C, Order_Id (Onum), Vehicle_Id (Vnum), Dist, Road, Ok);
      if Ok then
         Put_Line ("assigned → En_Route ETA"
                   & Get_Order (C, Order_Id (Onum)).ETA_s'Image & "s");
      else
         Put_Line ("assign failed");
      end if;
   end Do_Assign;

begin
   Seed;
   Put_Line ("Ada Logistics MVP — [j]obs [a]ssign [t]/Enter tick [r]ate [s]paceports [e]vo [q]uit");
   Put_Line ("Time_Rate default demo 60.0 (wall*rate → sim seconds)");
   Show_Jobs;

   loop
      Put ("> ");
      Get_Line (Line, Last);
      Tick (C);  -- auto-tick on each key / line
      if Last = 0 then
         Cmd := 't';
      else
         Cmd := Line (1);
      end if;

      case Cmd is
         when 'j' | 'J' =>
            Show_Jobs;
         when 'a' | 'A' =>
            Do_Assign;
            Show_Jobs;
         when 't' | 'T' | ' ' =>
            Demo_T_s := Demo_T_s + 3600.0;
            Life_Tick
              (Demo_Cell, 3600.0, Demo_T_s,
               Time_Rate => Time_Rate_Of (C));
            Put_Line ("tick (+demand Life_Tick → sim_run.csv)");
            Show_Jobs;
         when 's' | 'S' =>
            Show_Spaceports;
         when 'e' | 'E' =>
            Demo_T_s := Demo_T_s + 3600.0;
            Life_Tick
              (Demo_Cell, 3600.0, Demo_T_s,
               Time_Rate => Time_Rate_Of (C));
            Show_Evo;
         when 'r' | 'R' =>
            declare
               Rraw : String (1 .. 20);
               RL   : Natural;
               R    : Float;
            begin
               Put ("time_rate (>0): ");
               Get_Line (Rraw, RL);
               R := Float'Value (Ada.Strings.Fixed.Trim
                 (Rraw (1 .. RL), Ada.Strings.Both));
               if R > 0.0 then
                  Set_Time_Rate (C, R);
                  Put_Line ("Time_Rate=" & Time_Rate_Of (C)'Image);
               end if;
            exception
               when others =>
                  Put_Line ("bad rate");
            end;
         when 'q' | 'Q' =>
            Put_Line ("bye");
            exit;
         when others =>
            Show_Jobs;
      end case;
   end loop;
end Play;
