--  Step-1 tests for Logistics_Module (clean-room).

pragma Ada_2022;

with Ada.Text_IO; use Ada.Text_IO;
with Logistics_Module; use Logistics_Module;

procedure Tests is
   Failed : Natural := 0;
   Passed : Natural := 0;

   procedure Check (Cond : Boolean; Msg : String) is
   begin
      if Cond then
         Passed := Passed + 1;
         Put_Line ("PASS: " & Msg);
      else
         Failed := Failed + 1;
         Put_Line ("FAIL: " & Msg);
      end if;
   end Check;

   C          : Company;
   A, B       : City_Id;
   Sp1, Sp2   : City_Id;
   Vid, Tid   : Vehicle_Id;
   Tank_V     : Vehicle_Id;
   Sid        : Staff_Id;
   Oid        : Order_Id;
   Off        : Offer_Id;
   Slot       : Rail_Slot_Id;
   Ok         : Boolean;
   Ord        : Order_Record;
   City       : City_Record;
   Plate      : constant Placard_Code := "33/1203 ";
begin
   ------------------------------------------------------------------
   -- Compatibility + hazard mode allow-list
   ------------------------------------------------------------------
   Check (Compatible (Silo_Cargo, Silo, Road), "silo road");
   Check (not Compatible (Silo_Cargo, Tank, Road), "silo not tank");
   Check (Compatible (Reefer_Cargo, Reefer, Road)
            and then not Compatible (Reefer_Cargo, Reefer, Rail),
          "reefer road only");
   Check (Compatible (Container_Cargo, Container, Space_Haul), "container space_haul");
   Check (not Compatible (Flatbed_Cargo, Flatbed, Space_Haul), "flatbed not space_haul");

   Check (Mode_Allows_Hazard (Road, Explosives), "road allows explosives");
   Check (not Mode_Allows_Hazard (Air, Explosives), "air denies explosives");
   Check (not Mode_Allows_Hazard (Space_Haul, Radioactive), "space_haul denies radioactive");
   Check (Mode_Allows_Hazard (Air, Flammable_Liquids), "air allows flammable liquids");
   Check (Mode_Allows_Hazard (Space_Haul, Corrosive), "space_haul allows corrosive");
   Check (Requires_Tank_Body (Gases)
            and then Requires_Tank_Body (Flammable_Liquids)
            and then not Requires_Tank_Body (Explosives),
          "tank required for gases/flammable liquids");
   declare
      Cost_Img : constant String := Space_Cost_Factor'Image;
      Time_Img : constant String := Space_Time_Factor'Image;
   begin
      Check (Cost_Img'Length > 0 and then Time_Img'Length > 0,
             "space_haul cost/time factors present");
   end;

   ------------------------------------------------------------------
   -- Company / cities
   ------------------------------------------------------------------
   C := Create_Company (80_000.00, 5);
   Add_City (C, "Alpha", True, True, False, Id => A);
   Add_City (C, "Beta", True, True, False, Id => B);
   City := Get_City (C, A);
   Check (City.Has_Rail and then not City.Has_Spaceport, "city rail always");
   Add_City (C, "OrbitGate", True, False, True, Id => Sp1);
   Add_City (C, "LunaDock", False, False, True, Id => Sp2);

   ------------------------------------------------------------------
   -- Fleet
   ------------------------------------------------------------------
   Add_Vehicle (C, Light_Van, Flatbed, True, 4, 5_000.00, Vid, Ok);
   Check (Ok, "light van");
   Add_Vehicle (C, Rigid, Reefer, True, 16, 12_000.00, Vid, Ok);
   Check (Ok, "rigid reefer");
   Add_Vehicle
     (C, Artic_Tractor, Flatbed, False, 0, 8_000.00, Tid, Ok,
      ADR_Approved => False);
   Check (Ok and then Get_Vehicle (C, Tid).Capacity_FE = 0, "artic 0 FE");
   Attach_Body (C, Tid, Silo, 20, Ok);
   Check (Ok, "attach silo");

   Add_Vehicle
     (C, Rigid, Tank, True, 18, 15_000.00, Tank_V, Ok,
      ADR_Approved => True);
   Check (Ok and then Get_Vehicle (C, Tank_V).Vehicle_ADR_Approved,
          "ADR tank rigid");

   Maintain_Vehicle (C, 1, 100.00, Ok);
   Check (Ok, "maintain");

   Hire_Staff (C, Dispatcher, 2_000.00, Sid, Ok);
   Check (Ok, "dispatcher");
   Hire_Staff (C, Driver, 1_800.00, Sid, Ok, ADR_Certified => False);
   Check (Ok and then not Get_Staff (C, Sid).Driver_Has_ADR_Cert,
          "driver without ADR");
   Hire_Staff (C, Driver, 2_200.00, Sid, Ok, ADR_Certified => True);
   Check (Ok and then Get_Staff (C, Sid).Driver_Has_ADR_Cert,
          "driver with ADR");

   ------------------------------------------------------------------
   -- Offer + road silo
   ------------------------------------------------------------------
   Create_Order (C, A, B, Silo_Cargo, 10, 1_500.00, Oid, Ok);
   Make_Offer (C, Oid, 1_800.00, Off, Ok);
   Accept_Offer (C, Off, Ok);
   Dispatch_Order (C, Oid, Road, Vehicle => Tid, Success => Ok);
   Check (Ok, "road silo artic");
   Complete_Delivery (C, Oid, Ok);
   Check (Ok, "silo delivered");

   Detach_Body (C, Tid, Ok);
   Create_Order (C, A, B, Flatbed_Cargo, 2, 100.00, Oid, Ok);
   Make_Offer (C, Oid, 100.00, Off, Ok);
   Accept_Offer (C, Off, Ok);
   Dispatch_Order (C, Oid, Road, Vehicle => Tid, Success => Ok);
   Check (not Ok, "artic alone rejected");

   ------------------------------------------------------------------
   -- Rail / Air / Sea / Space
   ------------------------------------------------------------------
   Create_Order (C, A, B, Flatbed_Cargo, 8, 900.00, Oid, Ok);
   Make_Offer (C, Oid, 900.00, Off, Ok);
   Accept_Offer (C, Off, Ok);
   Dispatch_Order (C, Oid, Rail, Success => Ok);
   Check (not Ok, "rail without slot");
   Reserve_Rail_Slot (C, A, B, Slot, Ok);
   Dispatch_Order (C, Oid, Rail, Success => Ok);
   Check (Ok, "rail with slot");
   Complete_Delivery (C, Oid, Ok);

   Create_Order (C, A, B, Reefer_Cargo, 5, 700.00, Oid, Ok);
   Make_Offer (C, Oid, 700.00, Off, Ok);
   Accept_Offer (C, Off, Ok);
   Dispatch_Order (C, Oid, Rail, Success => Ok);
   Check (not Ok, "reefer not rail");
   Dispatch_Order (C, Oid, Road, Vehicle => 2, Success => Ok);
   Check (Ok, "reefer road");
   Complete_Delivery (C, Oid, Ok);

   Create_Order (C, A, B, Container_Cargo, 6, 2_000.00, Oid, Ok);
   Make_Offer (C, Oid, 2_000.00, Off, Ok);
   Accept_Offer (C, Off, Ok);
   Dispatch_Order (C, Oid, Air, Success => Ok);
   Check (Ok, "air ok");
   Complete_Delivery (C, Oid, Ok);

   Create_Order (C, A, B, Tank_Cargo, 12, 1_200.00, Oid, Ok);
   Make_Offer (C, Oid, 1_200.00, Off, Ok);
   Accept_Offer (C, Off, Ok);
   Dispatch_Order (C, Oid, Sea, Success => Ok);
   Check (Ok, "sea ok");
   Complete_Delivery (C, Oid, Ok);

   Create_Order (C, Sp1, Sp2, Container_Cargo, 3, 5_000.00, Oid, Ok);
   Make_Offer (C, Oid, 5_000.00, Off, Ok);
   Accept_Offer (C, Off, Ok);
   Dispatch_Order (C, Oid, Space_Haul, Success => Ok);
   Check (Ok, "space_haul container like air gate");
   Complete_Delivery (C, Oid, Ok);

   Create_Order (C, Sp1, Sp2, Flatbed_Cargo, 2, 100.00, Oid, Ok);
   Make_Offer (C, Oid, 100.00, Off, Ok);
   Accept_Offer (C, Off, Ok);
   Dispatch_Order (C, Oid, Space_Haul, Success => Ok);
   Check (not Ok, "space_haul non-container rejected");

   Create_Order (C, A, B, Container_Cargo, 1, 100.00, Oid, Ok);
   Make_Offer (C, Oid, 100.00, Off, Ok);
   Accept_Offer (C, Off, Ok);
   Dispatch_Order (C, Oid, Space_Haul, Success => Ok);
   Check (not Ok, "space_haul without spaceports");

   ------------------------------------------------------------------
   -- Hazard rejects: Air/Space explosives; Road without ADR; tank body
   ------------------------------------------------------------------
   Create_Order
     (C, A, B, Container_Cargo, 2, 500.00, Oid, Ok,
      Hazard => Explosives, Placard => Plate);
   Check (Ok, "create explosives order");
   Ord := Get_Order (C, Oid);
   Check (Ord.Hazard = Explosives and then Ord.Placard = Plate, "placard stored");
   Make_Offer (C, Oid, 500.00, Off, Ok);
   Accept_Offer (C, Off, Ok);
   Dispatch_Order (C, Oid, Air, Success => Ok);
   Check (not Ok, "air rejects explosives");
   Dispatch_Order (C, Oid, Space_Haul, Success => Ok);
   Check (not Ok, "space_haul rejects explosives");

   Create_Order
     (C, Sp1, Sp2, Container_Cargo, 1, 200.00, Oid, Ok,
      Hazard => Radioactive, Placard => "70/XXXX ");
   Make_Offer (C, Oid, 200.00, Off, Ok);
   Accept_Offer (C, Off, Ok);
   Dispatch_Order (C, Oid, Space_Haul, Success => Ok);
   Check (not Ok, "space_haul rejects radioactive");

   -- Hazardous road without ADR-approved vehicle
   Create_Order
     (C, A, B, Flatbed_Cargo, 2, 300.00, Oid, Ok,
      Hazard => Flammable_Solids, Placard => "40/XXXX ");
   Make_Offer (C, Oid, 300.00, Off, Ok);
   Accept_Offer (C, Off, Ok);
   -- van #1 is not ADR approved
   Dispatch_Order (C, Oid, Road, Vehicle => 1, Success => Ok);
   Check (not Ok, "road hazard without ADR vehicle");

   -- Flammable liquids need tank body even with ADR tank vehicle path
   Create_Order
     (C, A, B, Tank_Cargo, 5, 800.00, Oid, Ok,
      Hazard => Flammable_Liquids, Placard => "33/1203 ");
   Make_Offer (C, Oid, 800.00, Off, Ok);
   Accept_Offer (C, Off, Ok);
   -- artic with silo (reattach) ADR false — use non-tank ADR? Tank_V is ADR+Tank
   -- First: ADR tank vehicle but wrong cargo class Compatible — Tank_Cargo+Tank ok
   Dispatch_Order (C, Oid, Road, Vehicle => Tank_V, Success => Ok);
   Check (Ok, "flammable liquids on ADR tank");
   Complete_Delivery (C, Oid, Ok);

   -- Gases on non-tank ADR vehicle should fail
   declare
      Flat_ADR : Vehicle_Id;
   begin
      Add_Vehicle
        (C, Rigid, Flatbed, True, 10, 9_000.00, Flat_ADR, Ok,
         ADR_Approved => True);
      Check (Ok, "flat ADR rigid");
      Create_Order
        (C, A, B, Flatbed_Cargo, 3, 400.00, Oid, Ok,
         Hazard => Gases, Placard => "23/XXXX ");
      Make_Offer (C, Oid, 400.00, Off, Ok);
      Accept_Offer (C, Off, Ok);
      Dispatch_Order (C, Oid, Road, Vehicle => Flat_ADR, Success => Ok);
      Check (not Ok, "gases require tank body");
   end;

   ------------------------------------------------------------------
   -- Tunnel cargo + ambient lean + hazard premiums + cover legs
   ------------------------------------------------------------------
   declare
      T1, T2 : City_Id;
      Sel    : Cover_Selection;
      PF     : Premium_Multiplier;
      City_T : City_Record;
   begin
      Add_City
        (C, "TunnelNorth", False, False,
         Has_Tunnel => True, Tunnel_Fire_Vent_Risk => True, Id => T1);
      Add_City
        (C, "TunnelSouth", False, False,
         Has_Tunnel => True, Tunnel_Fire_Vent_Risk => False, Id => T2);
      City_T := Get_City (C, T1);
      Check (City_T.Has_Tunnel and then City_T.Tunnel_Fire_Vent_Risk,
             "tunnel city fire/vent lean");

      Check (Compatible (Silo_Cargo, Silo, Tunnel), "silo tunnel like road");
      Check (Compatible (Container_Cargo, Container, Tunnel),
             "container tunnel");
      Check (Mode_Allows_Hazard (Tunnel, Explosives),
             "tunnel allows explosives");

      Check (Ambient_For (Road).Cabin_Pressure_kPa = 101.0
               and then Ambient_For (Road).Gravity_g = 1.0,
             "ambient road lean");
      Check (Ambient_For (Tunnel).Rad_uSv_Per_h_Lo = 0.05
               and then Ambient_For (Tunnel).Rad_uSv_Per_h_Hi = 0.2,
             "ambient tunnel rad band");
      Check (Ambient_For (Space_Haul).Ext_Pressure_kPa = 0.0
               and then Ambient_For (Space_Haul).Gravity_g = 0.0
               and then Ambient_For (Space_Haul).Rad_uSv_Per_h_Lo = 50.0
               and then Ambient_For (Space_Haul).Rad_uSv_Per_h_Hi = 100.0,
             "ambient space_haul lean");

      Check (Band_Of (None) = Hazard_Premium_Band'(None), "band none");
      Check (Band_Of (Misc_Dangerous) = Low, "band low misc");
      Check (Band_Of (Flammable_Liquids) = Mid, "band mid flammable");
      Check (Band_Of (Flammable_Solids) = Mid, "band mid solids");
      Check (Band_Of (Oxidizers) = Mid, "band mid oxidizers");
      Check (Band_Of (Gases) = High, "band high gases");
      Check (Band_Of (Toxic_Infectious) = High, "band high toxic");
      Check (Band_Of (Corrosive) = High, "band high corrosive");
      Check (Band_Of (Explosives) = Extreme, "band extreme explosives");
      Check (Band_Of (Radioactive) = Extreme, "band extreme radioactive");

      Check (Base_Band_Factor (Hazard_Premium_Band'(None)) = 1.0,
             "table None 1.0");
      Check (Base_Band_Factor (Low) = 1.2, "table Low 1.2");
      Check (Base_Band_Factor (Mid) = 2.0, "table Mid 2.0");
      Check (Base_Band_Factor (High) = 4.0, "table High 4.0");
      Check (Base_Band_Factor (Extreme) = 10.0, "table Extreme 10.0");

      Check (Premium_Factor (None, Road) = 1.0, "PF none road");
      Check (Premium_Factor (Misc_Dangerous, Road) = 1.2, "PF low");
      Check (Premium_Factor (Flammable_Liquids, Tunnel) = 2.0, "PF mid");
      Check (Premium_Factor (Gases, Space_Haul) = 4.0, "PF high no mode extra");
      Check (Premium_Factor (Explosives, Road) = 10.0,
             "PF extreme road 10");
      Check (Premium_Factor (Explosives, Tunnel) = 12.0,
             "PF extreme tunnel 10*1.2");
      Check (Premium_Factor (Radioactive, Space_Haul) = 15.0,
             "PF extreme space 10*1.5");

      Check (Cover_Leg_Factor (Cargo_Loss) = 1.0, "cover cargo 1.0");
      Check (Cover_Leg_Factor (Hull_Loss) = 0.6, "cover hull 0.6");
      Check (Cover_Leg_Factor (Crew_Loss) = 0.8, "cover crew 0.8");
      Check (Cover_Leg_Factor (Crew_Sick) = 0.25, "cover sick 0.25");
      Check (Cover_Leg_Factor (Emergency_Leave) = 0.10, "cover emerg 0.10");

      Sel := Empty_Cover;
      Sel (Cargo_Loss) := True;
      Check (Selected_Cover_Sum (Sel) = 1.0, "sum cargo only");
      Sel (Hull_Loss) := True;
      Check (Selected_Cover_Sum (Sel) = 1.6, "sum cargo+hull");
      Check (Selected_Cover_Sum (Full_Cover) = 2.75, "sum full covers");

      -- Total = sum(legs) × hazard×mode
      PF := Total_Premium_Factor (Explosives, Space_Haul, Sel);
      Check (PF = 1.6 * 15.0, "total cargo+hull × extreme space");
      PF := Total_Premium_Factor (None, Road, Full_Cover);
      Check (PF = 2.75 * 1.0, "total full × none");
      PF := Total_Premium_Factor (Gases, Tunnel, Full_Cover);
      Check (PF = 2.75 * 4.0, "total full × high tunnel");

      -- Claim_Event stub literals exist
      Check (Claim_Event'Pos (Claim_Cargo_Lost) =
               Claim_Event'Pos (Claim_Event'First),
             "claim stub cargo first");
      Check (Claim_Event'Pos (Claim_Emergency_Leave) =
               Claim_Event'Pos (Claim_Event'Last),
             "claim stub emergency last");

      -- Tunnel dispatch with EU fleet (artic silo re-attach)
      Attach_Body (C, Tid, Silo, 20, Ok);
      Check (Ok, "reattach silo for tunnel");
      Create_Order (C, T1, T2, Silo_Cargo, 8, 1_100.00, Oid, Ok);
      Make_Offer (C, Oid, 1_100.00, Off, Ok);
      Accept_Offer (C, Off, Ok);
      Dispatch_Order (C, Oid, Tunnel, Vehicle => Tid, Success => Ok);
      Check (Ok, "tunnel silo artic");
      Complete_Delivery (C, Oid, Ok);
      Check (Ok, "tunnel delivered");

      -- Tunnel denied without Has_Tunnel at both ends
      Create_Order (C, A, B, Container_Cargo, 1, 50.00, Oid, Ok);
      Make_Offer (C, Oid, 50.00, Off, Ok);
      Accept_Offer (C, Off, Ok);
      Dispatch_Order (C, Oid, Tunnel, Vehicle => 1, Success => Ok);
      Check (not Ok, "tunnel without Has_Tunnel rejected");
   end;

   ------------------------------------------------------------------
   -- EU vehicle class limits + M1 size tags (Physical_Data)
   ------------------------------------------------------------------
   declare
      P       : Vehicle_Physical;
      N2_Id   : Vehicle_Id;
      N3_Id   : Vehicle_Id;
      M1_Id   : Vehicle_Id;
      Bad_Id  : Vehicle_Id;
      Area    : Float;
   begin
      Check (Map_Kind_To_EU_Class (Light_Van, 3_500) = N1, "Light_Van→N1");
      Check (Map_Kind_To_EU_Class (Rigid, 12_000) = N2, "Rigid GVW<=12t →N2");
      Check (Map_Kind_To_EU_Class (Rigid, 18_000) = N3, "Rigid GVW>12t →N3");
      Check (Map_Kind_To_EU_Class (Artic_Tractor, 40_000) = N3,
             "Artic_Tractor→N3");
      Check (Map_Trailer_To_EU_Class (3_000) = O2, "trailer stub O2");
      Check (Map_Trailer_To_EU_Class (10_000) = O4, "trailer stub O4");

      Check (Class_GVW_Limit (N1) = 3_500, "N1 GVW max 3500");
      Check (Class_GVW_Limit (N2) = 12_000, "N2 GVW max 12000");
      Check (Class_GVW_Limit (N3) = 40_000, "N3 check cap 40000");
      Check (Within_GVW_Class_Limit (N1, 3_500), "N1 at limit ok");
      Check (not Within_GVW_Class_Limit (N1, 3_501), "N1 over limit");
      Check (Within_GVW_Class_Limit (N2, 12_000), "N2 at limit ok");
      Check (not Within_GVW_Class_Limit (N2, 12_001), "N2 over limit");
      Check (Within_GVW_Class_Limit (N3, 40_000), "N3 at artic cap ok");
      Check (not Within_GVW_Class_Limit (N3, 40_001), "N3 over artic cap");

      Check (Masses_Valid (1_100, 1_400), "GVW >= curb");
      Check (not Masses_Valid (2_000, 1_500), "GVW < curb rejected");

      P := Profile_M1 (Car_Small);
      Check (P.EU_Class = M1 and then P.M1_Size = Car_Small
               and then P.Curb_Mass = 1_100 and then P.GVW = 1_400
               and then P.Length_m = 4.00 and then P.Width_m = 1.70,
             "M1 Car_Small DS");
      Area := Footprint_Area_M2 (P.Length_m, P.Width_m);
      Check (Area > 6.7 and then Area < 6.9, "Car_Small area ~6.8");

      P := Profile_M1 (Car_Medium);
      Check (P.Curb_Mass = 1_500 and then P.GVW = 2_000
               and then P.Length_m = 4.60 and then P.Width_m = 1.80,
             "M1 Car_Medium DS");
      Area := Footprint_Area_M2 (P.Length_m, P.Width_m);
      Check (Area > 8.2 and then Area < 8.4, "Car_Medium area ~8.3");

      P := Profile_M1 (Car_Large);
      Check (P.Curb_Mass = 2_200 and then P.GVW = 3_000
               and then P.Length_m = 5.00 and then P.Width_m = 2.00,
             "M1 Car_Large DS");
      Area := Footprint_Area_M2 (P.Length_m, P.Width_m);
      Check (Area > 9.9 and then Area < 10.1, "Car_Large area ~10");

      Check (Lorry_Rigid.Curb_Mass = 8_000 and then Lorry_Rigid.GVW = 18_000
               and then Lorry_Rigid.Length_m = 8.00
               and then Lorry_Rigid.Width_m = 2.50,
             "lorry_size rigid DS");
      Check (Lorry_Artic.Curb_Mass = 15_000 and then Lorry_Artic.GVW = 40_000
               and then Lorry_Artic.Length_m = 16.50
               and then Lorry_Artic.Width_m = 2.55,
             "lorry_artic DS");

      -- Default Physical on existing fleet kinds
      Check (Get_Vehicle (C, 1).Phys.EU_Class = N1, "van stored as N1");
      Check (Get_Vehicle (C, Tid).Phys.EU_Class = N3, "artic stored as N3");
      Check (Get_Vehicle (C, 2).Phys.EU_Class = N3
               and then Get_Vehicle (C, 2).Phys.GVW = 18_000,
             "default rigid lorry → N3 by GVW");

      -- Explicit N2 rigid (GVW within N2 band)
      P := Make_Physical
        (Curb => 6_000, GVW => 11_000,
         Length => 7.50, Width => 2.50, Class => N2);
      Add_Vehicle
        (C, Rigid, Flatbed, True, 14, 1_000.00, N2_Id, Ok, Phys => P);
      Check (Ok and then Get_Vehicle (C, N2_Id).Phys.EU_Class = N2,
             "explicit N2 rigid");

      -- N1 over class limit rejected
      P := Make_Physical
        (Curb => 2_000, GVW => 4_000,
         Length => 5.50, Width => 2.00, Class => N1);
      Add_Vehicle
        (C, Light_Van, Flatbed, True, 4, 500.00, Bad_Id, Ok, Phys => P);
      Check (not Ok, "N1 over GVW limit rejected");

      -- GVW < curb rejected (via Masses_Valid path; avoid Pre on Make_Physical)
      declare
         Bad : constant Vehicle_Physical :=
           (Curb_Mass => 5_000,
            GVW       => 4_000,
            Length_m  => 5.00,
            Width_m   => 2.00,
            EU_Class  => N2,
            M1_Size   => Car_Medium);
      begin
         Add_Vehicle
           (C, Rigid, Flatbed, True, 10, 500.00, Bad_Id, Ok, Phys => Bad);
         Check (not Ok, "GVW < curb rejected on add");
      end;

      -- M1 passenger via size tag
      P := Profile_M1 (Car_Medium);
      Add_Vehicle
        (C, Light_Van, Flatbed, True, 2, 500.00, M1_Id, Ok, Phys => P);
      Check (Ok and then Get_Vehicle (C, M1_Id).Phys.EU_Class = M1
               and then Get_Vehicle (C, M1_Id).Phys.M1_Size = Car_Medium,
             "M1 Car_Medium vehicle");

      -- N3 artic profile
      Add_Vehicle
        (C, Artic_Tractor, Flatbed, False, 0, 500.00, N3_Id, Ok,
         Phys => Lorry_Artic);
      Check (Ok and then Get_Vehicle (C, N3_Id).Phys.EU_Class = N3
               and then Get_Vehicle (C, N3_Id).Phys.GVW = 40_000,
             "N3 artic profile stored");
   end;


   ------------------------------------------------------------------
   -- MVP ETA + tick deliver (inject time; no long sleep)
   ------------------------------------------------------------------
   declare
      Pc      : Company;
      Ca, Cb  : City_Id;
      V       : Vehicle_Id;
      O       : Order_Id;
      Ok      : Boolean;
      Ord     : Order_Record;
   begin
      Check (Speed_Of (Road) = 22.0, "speed Road 22");
      Check (Speed_Of (Tunnel) = 30.0, "speed Tunnel 30");
      Check (Speed_Of (Space_Haul) = 3_000.0, "speed Space_Haul 3000");
      Check (Compute_ETA_s (2_200.0, Road) = 100.0, "ETA Road 2200/22");
      Check (Compute_ETA_s (3_000.0, Tunnel) = 100.0, "ETA Tunnel 3000/30");
      Check (Compute_ETA_s (300_000.0, Space_Haul) = 100.0,
             "ETA Space 300000/3000");

      Pc := Create_Company (10_000.00);
      Set_Time_Rate (Pc, 1.0);
      Check (Time_Rate_Of (Pc) = 1.0, "Time_Rate default set 1");
      Add_City (Pc, "X", False, False, Id => Ca);
      Add_City (Pc, "Y", False, False, Id => Cb);
      Add_Vehicle (Pc, Light_Van, Flatbed, True, 4, 1_000.00, V, Ok);
      Check (Ok, "play fleet van");
      Create_Order (Pc, Ca, Cb, Flatbed_Cargo, 1, 500.00, O, Ok);
      Check (Ok, "play order");

      Assign_Vehicle (Pc, O, V, 2_200.0, Road, Ok);
      Check (Ok, "assign → En_Route");
      Ord := Get_Order (Pc, O);
      Check (Ord.Status = En_Route, "status En_Route");
      Check (Ord.ETA_s = 100.0, "assigned ETA 100");
      Check (Ord.Elapsed_s = 0.0, "elapsed starts 0");
      Check (not Get_Vehicle (Pc, V).Available, "vehicle busy");

      Tick_Delta (Pc, 50.0);
      Ord := Get_Order (Pc, O);
      Check (Ord.Status = En_Route and then Ord.Elapsed_s = 50.0,
             "half way still En_Route");

      Tick_Delta (Pc, 50.0);
      Ord := Get_Order (Pc, O);
      Check (Ord.Status = Delivered, "deliver when elapsed>=eta");
      Check (Get_Vehicle (Pc, V).Available, "vehicle freed");
      Check (Cash (Pc) = 9_500.00, "payment on deliver");

      -- Time_Rate scales injected wall delta
      Create_Order (Pc, Ca, Cb, Flatbed_Cargo, 1, 100.00, O, Ok);
      Assign_Vehicle (Pc, O, V, 2_200.0, Road, Ok);
      Set_Time_Rate (Pc, 10.0);
      Tick_Delta (Pc, 10.0);  -- sim += 100
      Check (Get_Order (Pc, O).Status = Delivered, "Time_Rate 10 delivers");
   end;

   New_Line;
   Put_Line ("Passed:" & Passed'Image & "  Failed:" & Failed'Image);
   if Failed > 0 then
      raise Program_Error with "tests failed";
   end if;
end Tests;
