--  MIT-safe circular Kepler stubs and a neutral exchange-table loader.
--  No Swiss Ephemeris code or data is used by this package.
pragma Ada_2022;

package Logistics_Module.Ephemeris is

   --  The built-in model is deliberately small: circular heliocentric
   --  tracks, with the result expressed relative to Terra_0.
   function Kepler_Position
     (World : World_Body;
      T_s   : Float) return Position_m;

   --  Load a v1 exchange table.  A successful load replaces the previous
   --  table; a failed load leaves the previous table and returns False.
   function Load_Ephemeris_Table (Path : String) return Boolean;
   procedure Load_Ephemeris_Table
     (Path    : String;
      Success : out Boolean);
   procedure Clear_Ephemeris_Table;
   function Table_Loaded return Boolean;

   --  A loaded table is linearly interpolated (and clamped at its ends) for
   --  bodies it contains.  Other bodies, or no loaded table, use Kepler.
   function Sample_At
     (World : World_Body;
      T_s   : Float) return Position_m;

   function Distance_m
     (A, B : World_Body;
      T_s : Float := 0.0) return Float;

end Logistics_Module.Ephemeris;
