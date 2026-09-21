--  Lean ATC: lane capacity, separation, assign gate (not Fitness).

pragma Ada_2022;

with Ada.Directories;
with Ada.Float_Text_IO;
with Ada.Strings;
with Ada.Strings.Fixed;

package body Logistics_Module.ATC is

   function Default_Separation_m (Mode : Haul_Mode) return Float is
   begin
      case Mode is
         when Road =>
            return Separation_Road_m;
         when Tunnel =>
            return Separation_Tunnel_m;
         when Space_Haul =>
            return Separation_Space_Haul_m;
      end case;
   end Default_Separation_m;

   function Capacity_From_Corridor
     (Distance_m   : Float;
      Separation_m : Float;
      Mode         : Haul_Mode) return Positive
   is
      Raw : Natural;
   begin
      if Separation_m <= 0.0 or else Distance_m <= 0.0 then
         Raw := 1;
      else
         Raw := Natural (Float'Floor (Distance_m / Separation_m));
         if Raw < 1 then
            Raw := 1;
         end if;
      end if;
      case Mode is
         when Space_Haul =>
            if Raw > Space_Haul_Capacity_Cap then
               return Space_Haul_Capacity_Cap;
            else
               return Positive (Raw);
            end if;
         when Road | Tunnel =>
            return Positive (Raw);
      end case;
   end Capacity_From_Corridor;

   function Make_Lane
     (Origin        : City_Id;
      Destination   : City_Id;
      Mode          : Haul_Mode;
      Distance_m    : Float;
      Separation_m  : Float := 0.0;
      Lane_Capacity : Natural := 0) return Traffic_Lane
   is
      Sep : Float;
      Cap : Positive;
      L   : Traffic_Lane;
   begin
      if Separation_m > 0.0 then
         Sep := Separation_m;
      else
         Sep := Default_Separation_m (Mode);
      end if;
      -- Space_Haul: enforce Separation_m ≥ 50_000 lock
      if Mode = Space_Haul and then Sep < Separation_Space_Haul_m then
         Sep := Separation_Space_Haul_m;
      end if;
      if Lane_Capacity > 0 then
         Cap := Positive (Lane_Capacity);
         if Mode = Space_Haul and then Cap > Space_Haul_Capacity_Cap then
            Cap := Space_Haul_Capacity_Cap;
         end if;
      else
         Cap := Capacity_From_Corridor (Distance_m, Sep, Mode);
      end if;
      L :=
        (Origin          => Origin,
         Destination     => Destination,
         Mode            => Mode,
         Distance_m      => Distance_m,
         Separation_m    => Sep,
         Lane_Capacity   => Cap,
         Fleet_In_Flight => 0,
         Assign_Rejected => 0);
      return L;
   end Make_Lane;

   function Min_Slot_Spacing_s
     (Separation_m     : Float;
      Cruise_Speed_m_s : Float) return Float
   is
   begin
      return Separation_m / Cruise_Speed_m_s;
   end Min_Slot_Spacing_s;

   function Min_Slot_Spacing_s (Lane : Traffic_Lane) return Float is
   begin
      return Min_Slot_Spacing_s (Lane.Separation_m, Speed_Of (Lane.Mode));
   end Min_Slot_Spacing_s;

   procedure Try_Occupy
     (Lane    : in out Traffic_Lane;
      Success : out Boolean)
   is
   begin
      if At_Capacity (Lane) then
         Lane.Assign_Rejected := Lane.Assign_Rejected + 1;
         Success := False;
         return;
      end if;
      Lane.Fleet_In_Flight := Lane.Fleet_In_Flight + 1;
      Success := True;
   end Try_Occupy;

   procedure Occupy_Or_Raise (Lane : in out Traffic_Lane) is
      Ok : Boolean;
   begin
      Try_Occupy (Lane, Ok);
      if not Ok then
         raise ATC_Capacity_Exceeded
           with "Fleet_In_Flight >= Lane_Capacity";
      end if;
   end Occupy_Or_Raise;

   procedure Release (Lane : in out Traffic_Lane) is
   begin
      if Lane.Fleet_In_Flight > 0 then
         Lane.Fleet_In_Flight := Lane.Fleet_In_Flight - 1;
      end if;
   end Release;

   procedure Release_After_Delivery (Lane : in out Traffic_Lane) renames
     Release;

   procedure Assign_On_Lane
     (C          : in out Company;
      Lane       : in out Traffic_Lane;
      Order      : Order_Id;
      Vehicle    : Vehicle_Id;
      Distance_m : Float;
      Mode       : Haul_Mode := Road;
      Success    : out Boolean;
      Now        : Ada.Calendar.Time := Ada.Calendar.Clock)
   is
      Slot_Ok : Boolean;
   begin
      Success := False;
      Try_Occupy (Lane, Slot_Ok);
      if not Slot_Ok then
         Mark_Rejected_ATC (C, Order);
         return;
      end if;
      Assign_Vehicle (C, Order, Vehicle, Distance_m, Mode, Success, Now);
      if not Success then
         -- Roll back occupy if assign failed for other reasons
         Release (Lane);
      end if;
   end Assign_On_Lane;

   function Trim_Img (S : String) return String is
      use Ada.Strings.Fixed;
   begin
      return Trim (S, Side => Ada.Strings.Left);
   end Trim_Img;

   procedure Append_ATC_CSV
     (File : Ada.Text_IO.File_Type;
      Lane : Traffic_Lane)
   is
      use Ada.Text_IO;
   begin
      Put (File, Trim_Img (Lane.Fleet_In_Flight'Image));
      Put (File, ',');
      Put (File, Trim_Img (Lane.Lane_Capacity'Image));
      Put (File, ',');
      Put (File, Trim_Img (Lane.Assign_Rejected'Image));
   end Append_ATC_CSV;

   procedure Log_Lane_State
     (Lane : Traffic_Lane;
      T_s  : Float := 0.0;
      Path : String := "sim_run.csv")
   is
      use Ada.Text_IO;
      use Ada.Float_Text_IO;
      F : File_Type;
   begin
      if not Ada.Directories.Exists (Path) then
         Create (F, Out_File, Path);
         Put_Line (F, "# ATC lane snapshot");
         Put_Line
           (F,
            "t_s,Lane_Mode,Distance_m,Separation_m," & ATC_CSV_Columns);
      else
         Open (F, Append_File, Path);
      end if;
      Put (F, T_s, Fore => 1, Aft => 6, Exp => 3);
      Put (F, ',');
      Put (F, Trim_Img (Lane.Mode'Image));
      Put (F, ',');
      Put (F, Lane.Distance_m, Fore => 1, Aft => 6, Exp => 3);
      Put (F, ',');
      Put (F, Lane.Separation_m, Fore => 1, Aft => 6, Exp => 3);
      Put (F, ',');
      Append_ATC_CSV (F, Lane);
      New_Line (F);
      Close (F);
   end Log_Lane_State;

end Logistics_Module.ATC;
