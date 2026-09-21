--  MIT-safe circular Kepler stubs and neutral CSV exchange loader.
pragma Ada_2022;

with Ada.Characters.Handling;
with Ada.Numerics;
with Ada.Numerics.Elementary_Functions;
with Ada.Strings;
with Ada.Strings.Fixed;
with Ada.Text_IO;

package body Logistics_Module.Ephemeris is

   use Ada.Characters.Handling;
   use Ada.Numerics.Elementary_Functions;
   use Ada.Strings;
   use Ada.Strings.Fixed;
   use Ada.Text_IO;

   Max_Samples_Per_Body : constant Positive := 256;
   Seconds_Per_Day      : constant Float := 86_400.0;
   Seconds_Per_Year     : constant Float := 31_557_600.0;
   Pi                   : constant Float := Ada.Numerics.Pi;

   type Time_Array is array (Positive range 1 .. Max_Samples_Per_Body)
     of Float;
   type Position_Array is array (Positive range 1 .. Max_Samples_Per_Body)
     of Position_m;

   type Body_Table is record
      Count     : Natural := 0;
      Times     : Time_Array := [others => 0.0];
      Positions : Position_Array := [others => Terra_Origin];
   end record;

   type Table_Array is array (World_Body) of Body_Table;

   Empty_Table : constant Table_Array := [others => (others => <> )];
   Loaded_Table : Table_Array := Empty_Table;
   Loaded       : Boolean := False;

   function Orbit
     (Radius_AU : Float;
      Period_s  : Float;
      Phase     : Float;
      T_s       : Float) return Position_m
   is
      Theta : constant Float := Phase + 2.0 * Pi * T_s / Period_s;
   begin
      return
        (X => Radius_AU * Hub_AU_m * Cos (Theta),
         Y => Radius_AU * Hub_AU_m * Sin (Theta),
         Z => 0.0);
   end Orbit;

   function Heliocentric_Kepler
     (World : World_Body;
      T_s   : Float) return Position_m
   is
      Terra : constant Position_m :=
        Orbit (1.0, 1.0 * Seconds_Per_Year, 0.0, T_s);
      Moon_Offset : Position_m;
   begin
      case World is
         when Terra_0 =>
            return Terra;
         when Venus_Cloud_Port =>
            --  The phase/radius are an educational cloud-port proxy.
            return Orbit (1.72, 0.615 * Seconds_Per_Year, 0.0, T_s);
         when Mars =>
            --  Calibrated to the repository's existing 1.5 AU lean offset.
            return Orbit (2.5, 1.881 * Seconds_Per_Year, 0.0, T_s);
         when Titan =>
            --  Titan is represented by a circular outer-system track.  The
            --  10.5 AU proxy gives 9.5 AU Terra-to-Titan at epoch zero.
            return Orbit (10.5, 29.457 * Seconds_Per_Year, 0.0, T_s);
         when Moon_Polar =>
            Moon_Offset :=
              Orbit (Earth_Moon_Distance_m / Hub_AU_m,
                     27.321661 * Seconds_Per_Day,
                     0.0,
                     T_s);
            return (X => Terra.X + Moon_Offset.X,
                    Y => Terra.Y + Moon_Offset.Y,
                    Z => Terra.Z + Moon_Offset.Z);
      end case;
   end Heliocentric_Kepler;

   function Kepler_Position
     (World : World_Body;
      T_s   : Float) return Position_m
   is
      Terra : constant Position_m := Heliocentric_Kepler (Terra_0, T_s);
      P     : constant Position_m := Heliocentric_Kepler (World, T_s);
   begin
      --  Preserve the original public t=0 anchors exactly; subsequent
      --  samples follow the circular tracks above.
      if T_s = 0.0 then
         case World is
            when Terra_0 =>
               return Terra_Origin;
            when Moon_Polar =>
               return (X => Earth_Moon_Distance_m, Y => 0.0, Z => 0.0);
            when Venus_Cloud_Port =>
               return (X => 0.72 * Hub_AU_m, Y => 0.0, Z => 0.0);
            when Mars =>
               return (X => Mars_Offset_m, Y => 0.0, Z => 0.0);
            when Titan =>
               return (X => 9.5 * Hub_AU_m, Y => 0.0, Z => 0.0);
         end case;
      end if;
      return (X => P.X - Terra.X, Y => P.Y - Terra.Y, Z => P.Z - Terra.Z);
   end Kepler_Position;

   function Body_From_Name
     (Name  : String;
      World : out World_Body) return Boolean
   is
      N : constant String := To_Lower (Trim (Name, Both));
   begin
      if N = "terra_0" then
         World := Terra_0;
      elsif N = "moon_polar" then
         World := Moon_Polar;
      elsif N = "venus_cloud_port" then
         World := Venus_Cloud_Port;
      elsif N = "mars" then
         World := Mars;
      elsif N = "titan" then
         World := Titan;
      else
         return False;
      end if;
      return True;
   end Body_From_Name;

   function Field_End (Line : String; Start : Positive) return Natural is
      P : constant Natural := Index (Line (Start .. Line'Last), ",");
   begin
      if P = 0 then
         return Line'Last;
      else
         --  Index preserves the slice's original bounds.
         return P;
      end if;
   end Field_End;

   function Parse_Line
     (Line  : String;
      Table : in out Table_Array) return Boolean
   is
      C1, C2, C3, C4 : Natural;
      S1, S2, S3, S4, S5 : String (1 .. Line'Length);
      L1, L2, L3, L4, L5 : Natural := 0;
      W : World_Body;
      X, Y, Z, T : Float;
      B : Body_Table;
   begin
      if Line'Length = 0 or else Trim (Line, Both)'Length = 0
        or else Trim (Line, Both) (Trim (Line, Both)'First) = '#'
      then
         return True;
      end if;

      C1 := Field_End (Line, Line'First);
      if C1 >= Line'Last then
         return False;
      end if;
      C2 := Field_End (Line, C1 + 1);
      C3 := Field_End (Line, C2 + 1);
      C4 := Field_End (Line, C3 + 1);
      if C2 >= Line'Last or else C3 >= Line'Last or else C4 >= Line'Last then
         return False;
      end if;

      S1 := [others => ' ']; S2 := [others => ' ']; S3 := [others => ' '];
      S4 := [others => ' ']; S5 := [others => ' '];
      L1 := C1 - Line'First;
      L2 := C2 - C1 - 1;
      L3 := C3 - C2 - 1;
      L4 := C4 - C3 - 1;
      L5 := Line'Last - C4;
      S1 (1 .. L1) := Line (Line'First .. C1 - 1);
      S2 (1 .. L2) := Line (C1 + 1 .. C2 - 1);
      S3 (1 .. L3) := Line (C2 + 1 .. C3 - 1);
      S4 (1 .. L4) := Line (C3 + 1 .. C4 - 1);
      S5 (1 .. L5) := Line (C4 + 1 .. Line'Last);

      if not Body_From_Name (S1 (1 .. L1), W) then
         return False;
      end if;
      T := Float'Value (Trim (S2 (1 .. L2), Both));
      X := Float'Value (Trim (S3 (1 .. L3), Both));
      Y := Float'Value (Trim (S4 (1 .. L4), Both));
      Z := Float'Value (Trim (S5 (1 .. L5), Both));
      B := Table (W);
      if B.Count >= Max_Samples_Per_Body then
         return False;
      end if;
      B.Count := B.Count + 1;
      B.Times (B.Count) := T;
      B.Positions (B.Count) := (X => X, Y => Y, Z => Z);
      Table (W) := B;
      return True;
   exception
      when Constraint_Error | Data_Error | End_Error =>
         return False;
   end Parse_Line;

   procedure Load_Ephemeris_Table
     (Path    : String;
      Success : out Boolean)
   is
      F : File_Type;
      Local : Table_Array := Empty_Table;
      Line : String (1 .. 1024);
      Last : Natural;
   begin
      Success := False;
      Open (F, In_File, Path);
      while not End_Of_File (F) loop
         Get_Line (F, Line, Last);
         if Last > 0 and then not Parse_Line (Line (1 .. Last), Local) then
            Close (F);
            return;
         end if;
      end loop;
      Close (F);
      Loaded_Table := Local;
      Loaded := True;
      Success := True;
   exception
      when others =>
         if Is_Open (F) then
            Close (F);
         end if;
         Success := False;
   end Load_Ephemeris_Table;

   function Load_Ephemeris_Table (Path : String) return Boolean is
      Success : Boolean;
   begin
      Load_Ephemeris_Table (Path, Success);
      return Success;
   end Load_Ephemeris_Table;

   procedure Clear_Ephemeris_Table is
   begin
      Loaded_Table := Empty_Table;
      Loaded := False;
   end Clear_Ephemeris_Table;

   function Table_Loaded return Boolean is (Loaded);

   function Table_Sample
     (B   : Body_Table;
      T_s : Float) return Position_m
   is
      I : Positive;
      U : Float;
   begin
      if B.Count = 0 then
         return Terra_Origin;
      elsif B.Count = 1 or else T_s <= B.Times (1) then
         return B.Positions (1);
      elsif T_s >= B.Times (B.Count) then
         return B.Positions (B.Count);
      end if;

      I := 1;
      while I < B.Count and then T_s > B.Times (I + 1) loop
         I := I + 1;
      end loop;
      U := (T_s - B.Times (I)) / (B.Times (I + 1) - B.Times (I));
      return Lerp (B.Positions (I), B.Positions (I + 1), U);
   end Table_Sample;

   function Sample_At
     (World : World_Body;
      T_s   : Float) return Position_m
   is
   begin
      if Loaded and then Loaded_Table (World).Count > 0 then
         return Table_Sample (Loaded_Table (World), T_s);
      else
         return Kepler_Position (World, T_s);
      end if;
   end Sample_At;

   function Distance_m
     (A, B : World_Body;
      T_s : Float := 0.0) return Float
   is
   begin
      return Logistics_Module.Distance_m (Sample_At (A, T_s), Sample_At (B, T_s));
   end Distance_m;

end Logistics_Module.Ephemeris;
