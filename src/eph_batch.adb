--  Generate and round-trip a small MIT-safe ephemeris exchange batch.
pragma Ada_2022;

with Ada.Float_Text_IO;
with Ada.Text_IO;
with Logistics_Module;
with Logistics_Module.Ephemeris;
with Logistics_Module.Demand_Cells;

procedure Eph_Batch is
   use Ada.Text_IO;
   use Logistics_Module;
   use Logistics_Module.Ephemeris;

   Path       : constant String := "eph/batch_terra_mars_titan.csv";
   Year_s     : constant Float := 31_557_600.0;
   Sample_Day : constant Float := 180.0;
   F          : File_Type;
   P0, P1     : Position_m;
   D          : Float;
   Transit_y  : Float;
   ETA_s      : Float;
   Demand_ETA : Float;
   Ok         : Boolean;

   procedure Put_Field (Value : Float) is
   begin
      Ada.Float_Text_IO.Put
        (F, Value, Fore => 1, Aft => 6, Exp => 3);
   end Put_Field;

   procedure Put_Sample (Name : String; T_s : Float; P : Position_m) is
   begin
      Put (F, Name);
      Put (F, ",");
      Put_Field (T_s);
      Put (F, ",");
      Put_Field (P.X);
      Put (F, ",");
      Put_Field (P.Y);
      Put (F, ",");
      Put_Field (P.Z);
      New_Line (F);
   end Put_Sample;

begin
   Logistics_Module.Ephemeris.Clear_Ephemeris_Table;
   Create (F, Out_File, Path);
   Put_Line (F, "# Ada Logistics Ephemeris Table v1");
   Put_Line (F, "# columns: body,t_s,x_m,y_m,z_m");
   Put_Line (F, "# body: Terra_0|Moon_Polar|Venus_Cloud_Port|Mars|Titan");

   for I in 0 .. 11 loop
      declare
         T_s : constant Float := Float (I) * Sample_Day * 86_400.0;
      begin
         Put_Sample ("Terra_0", T_s, Kepler_Position (Terra_0, T_s));
         Put_Sample ("Mars", T_s, Kepler_Position (Mars, T_s));
         Put_Sample ("Titan", T_s, Kepler_Position (Titan, T_s));
      end;
   end loop;
   Close (F);

   P0 := Kepler_Position (Mars, 0.0);
   P1 := Kepler_Position (Mars, Sample_Day * 86_400.0);
   if abs (P0.X - P1.X) + abs (P0.Y - P1.Y) < 1.0 then
      raise Program_Error with "Kepler Mars position did not move";
   end if;

   Logistics_Module.Ephemeris.Load_Ephemeris_Table (Path, Ok);
   if not Ok or else not Logistics_Module.Ephemeris.Table_Loaded then
      raise Program_Error with "ephemeris table reload failed";
   end if;

   D := Logistics_Module.Distance_m (Terra_0, Titan, 0.0);
   Transit_y := D / 3_000.0 / Year_s;
   if abs (D - 9.5 * Hub_AU_m) > 0.01 * Hub_AU_m then
      raise Program_Error with "Terra-Titan distance is not about 9.5 AU";
   end if;
   if Transit_y < 14.0 or else Transit_y > 16.0 then
      raise Program_Error with "3000 m/s transit is not about 15 years";
   end if;
   ETA_s := Compute_ETA_s (Terra_0, Titan, Space_Haul, 0.0);
   Demand_ETA := Logistics_Module.Demand_Cells.Transit_Duration_s
     (Terra_0, Titan, Logistics_Module.Demand_Cells.Barge_Inner, 0.0);
   if abs (ETA_s - D / Speed_Space_Haul_m_s) > 1.0
     or else abs (Demand_ETA - D / 3_000.0) > 1.0
   then
      raise Program_Error with "departure-time ETA wiring failed";
   end if;

   P0 := Logistics_Module.Ephemeris.Sample_At (Mars, 0.0);
   P1 := Logistics_Module.Ephemeris.Sample_At (Mars, Sample_Day * 86_400.0);
   Put_Line ("PASS: generated and reloaded " & Path);
   Put_Line ("Terra-Titan t=0 distance (m):" & D'Image);
   Put_Line ("3000 m/s transit (years):" & Transit_y'Image);
   Put_Line ("Mars positions change: " & Boolean'Image
             (abs (P0.X - P1.X) + abs (P0.Y - P1.Y) > 1.0));
end Eph_Batch;
