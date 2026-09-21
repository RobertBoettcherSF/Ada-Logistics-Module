with Ada.Text_IO; use Ada.Text_IO;
with Logistics_Module.Station_Sizing; use Logistics_Module.Station_Sizing;
with Logistics_Module.Supply_Agents; use Logistics_Module.Supply_Agents;

procedure Size is
   B, C, R : Natural;
   Deficit : Float;
   Good : Boolean;
   Limited_Barges : Natural;
   Limited_Undersupply : Float;
   Limited_Under_Fraction : Float;
   Oversupply_Barges : Natural;
   Oversupply_Ratio : Float;
   Oversupply_Ok : Boolean;
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

   Run_Limited_Barge_Agent
     (Crew           => 150,
      N_Ticks        => 6000,
      Barge_Cap      => 100,
      Barges_Used    => Limited_Barges,
      Undersupply_kg => Limited_Undersupply,
      Under_Fraction => Limited_Under_Fraction);
   Put_Line ("Scenario_1_Limited_Barges (cap=100)");
   Put_Line ("Barges_Used=" & Natural'Image (Limited_Barges));
   Put_Line ("Undersupply_kg_mean=" & Float'Image (Limited_Undersupply));
   Put_Line ("Under_Fraction=" & Float'Image (Limited_Under_Fraction));

   Size_Min_Barges_Oversupply
     (Crew             => 150,
      N_Ticks          => 6000,
      Sweep_Min_Barges => 1,
      Min_Barges       => Oversupply_Barges,
      Achieved_Ratio   => Oversupply_Ratio,
      Ok               => Oversupply_Ok);
   Put_Line ("Scenario_2_Min_Barges_Oversupply (cap=1.80)");
   Put_Line ("Min_Barges=" & Natural'Image (Oversupply_Barges));
   Put_Line ("Achieved_Ratio=" & Float'Image (Oversupply_Ratio));
   Put_Line ("Ok=" & Boolean'Image (Oversupply_Ok));
end Size;
