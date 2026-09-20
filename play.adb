--  MVP Text_IO play loop: jobs / assign / tick / quit.

pragma Ada_2022;

with Ada.Text_IO;          use Ada.Text_IO;
with Ada.Strings.Fixed;
with Logistics_Module;     use Logistics_Module;

procedure Play is
   C     : Company;
   A, B  : City_Id;
   Vid   : Vehicle_Id;
   Oid1, Oid2 : Order_Id;
   Ok    : Boolean;
   Line  : String (1 .. 80);
   Last  : Natural;
   Cmd   : Character;

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
   Put_Line ("Ada Logistics MVP — [j]obs [a]ssign [t]/Enter tick [r]ate [q]uit");
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
            Put_Line ("tick");
            Show_Jobs;
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
