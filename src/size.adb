with Ada.Text_IO; use Ada.Text_IO;
with Logistics_Module.Station_Sizing; use Logistics_Module.Station_Sizing;

procedure Size is
   B, C, R : Natural;
   Deficit : Float;
   Good : Boolean;
begin
   Size_Station_Fleet
     (Min_Barges       => B,
      Min_Couriers     => C,
      Min_Rel_Stubs    => R,
      Final_Deficit_kg => Deficit,
      Sustained        => Good);

   Put_Line ("Station fleet sizing (educational SI sweep)");
   Put_Line ("Crew=150 Ticks=6000 Delta_s=1296000.0 Distance_m=2.25e11");
   Put_Line ("Demand_Rate_kg_s=" & Float'Image (Total_Demand_Rate_kg_s));
   Put_Line ("Minimum_Mix=(Barge_Inner =>" & Natural'Image (B)
             & ", Fast_Courier =>" & Natural'Image (C)
             & ", Relativistic_Stub =>" & Natural'Image (R) & ")");
   Put_Line ("Minimum_Barges=" & Natural'Image (B));
   Put_Line ("Minimum_Couriers=" & Natural'Image (C));
   Put_Line ("Minimum_Rel_Stubs=" & Natural'Image (R));
   Put_Line ("Final_Deficit_kg=" & Float'Image (Deficit));
   Put_Line ("Sustained=" & Boolean'Image (Good));
end Size;
