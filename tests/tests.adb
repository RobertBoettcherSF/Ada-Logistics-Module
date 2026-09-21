--  Step-1 tests for Logistics_Module (clean-room).

pragma Ada_2022;

with Ada.Text_IO; use Ada.Text_IO;
with Ada.Directories;
with Ada.Strings.Fixed;
with Logistics_Module; use Logistics_Module;
with Logistics_Module.Demand_Cells;
use Logistics_Module.Demand_Cells;
with Logistics_Module.ATC;
use Logistics_Module.ATC;

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
   Check (Compatible (Reefer_Cargo, Reefer, Road), "reefer road");
   Check (not Compatible (Reefer_Cargo, Flatbed, Road), "reefer not flatbed road");
   Check (Compatible (Reefer_Cargo, Reefer, Rail)
            and then Compatible (Reefer_Cargo, Dry_Box, Sea)
            and then Compatible (Reefer_Cargo, Container, Air),
          "reefer rail/sea/air IRL");
   Check (not Compatible (Reefer_Cargo, Reefer, Space_Haul), "reefer not space");
   Check (Compatible (Container_Cargo, Container, Space_Haul), "container space_haul");
   Check (not Compatible (Flatbed_Cargo, Flatbed, Space_Haul), "flatbed not space_haul");
   Check (Compatible (Flatbed_Cargo, Flatbed, Sea), "flatbed sea IRL");

   -- Lowboy_Cargo: road/tunnel need Lowboy body; rail/sea any Equip; air/space refuse
   Check (Compatible (Lowboy_Cargo, Lowboy, Road), "lowboy road");
   Check (not Compatible (Lowboy_Cargo, Flatbed, Road), "lowboy not flatbed road");
   Check (Compatible (Lowboy_Cargo, Flatbed, Rail), "lowboy rail any equip");
   Check (Compatible (Lowboy_Cargo, Dry_Box, Sea), "lowboy sea any equip");
   Check (not Compatible (Lowboy_Cargo, Lowboy, Air), "lowboy not air");
   Check (not Compatible (Lowboy_Cargo, Lowboy, Space_Haul), "lowboy not space_haul");

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

   -- IRL: reefer may ride rail (cold cars / containers); need a slot like other rail
   Create_Order (C, A, B, Reefer_Cargo, 5, 700.00, Oid, Ok);
   Make_Offer (C, Oid, 700.00, Off, Ok);
   Accept_Offer (C, Off, Ok);
   Reserve_Rail_Slot (C, A, B, Slot, Ok);
   Dispatch_Order (C, Oid, Rail, Success => Ok);
   Check (Ok, "reefer rail IRL");
   Complete_Delivery (C, Oid, Ok);

   Create_Order (C, A, B, Reefer_Cargo, 5, 700.00, Oid, Ok);
   Make_Offer (C, Oid, 700.00, Off, Ok);
   Accept_Offer (C, Off, Ok);
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
   -- World_Body profiles + spaceport catalog + Pad_Reconcrete
   ------------------------------------------------------------------
   declare
      Sc          : Company;
      Venus_P     : Spaceport_Id;
      Moon_P      : Spaceport_Id;
      Mars_A, Mars_B : Spaceport_Id;
      Titan_1, Titan_2 : Spaceport_Id;
      Ca, Cb      : City_Id;
      Oid         : Order_Id;
      Off         : Offer_Id;
      Success     : Boolean;
      Cracked     : Boolean;
      Sp          : Spaceport_Record;
      Prof        : World_Body_Profile;
      Sid         : Staff_Id;
   begin
      -- Catalog SI: Venus cloud P/alt
      Prof := Profile_Of (Venus_Cloud_Port);
      Check (Prof.Altitude_m = 50_000.0
               and then Prof.Ext_Pressure_kPa = 101.0
               and then Prof.Temp_C_Lo = 60.0
               and then Prof.Temp_C_Hi = 75.0
               and then Prof.Gravity_g = 0.90
               and then Prof.Atmos = CO2
               and then Prof.Float_Pad
               and then Prof.Has_Spaceport,
             "Venus_Cloud_Port P/alt/g float pad");

      Prof := Profile_Of (Moon_Polar);
      Check (Prof.Ext_Pressure_kPa = 0.0
               and then Prof.Gravity_g = 0.17
               and then Prof.Rad_uSv_Per_h_Hi >= 50.0
               and then Prof.Relay,
             "Moon_Polar vacuum g relay");

      Prof := Profile_Of (Mars);
      Check (Prof.Ext_Pressure_kPa = 0.6 and then Prof.Gravity_g = 0.38,
             "Mars surface P/g");
      Prof := Profile_Of (Titan);
      Check (Prof.Ext_Pressure_kPa = 146.7 and then Prof.Gravity_g = 0.14
               and then Prof.Atmos = N2_CH4,
             "Titan surface P/g");

      Sc := Create_Company (100_000.00);
      Hire_Staff (Sc, Dispatcher, 1_000.00, Sid, Success);
      Check (Success, "spaceport catalog dispatcher");

      Add_Spaceport (Sc, "VenusFloat", Venus_Cloud_Port, 20_000, Venus_P, Success);
      Check (Success, "add Venus float pad");
      Check (Spaceport_Profile (Sc, Venus_P).Altitude_m = 50_000.0
               and then Spaceport_Profile (Sc, Venus_P).Ext_Pressure_kPa = 101.0,
             "Venus pad profile P/alt");

      Add_Spaceport (Sc, "LunaRelay", Moon_Polar, 10_000, Moon_P, Success);
      Check (Success and then Spaceport_Profile (Sc, Moon_P).Relay,
             "Moon polar relay pad");

      -- Mars: multiple Spaceport_Ids, same profile
      Add_Spaceport (Sc, "AresGate", Mars, 40_000, Mars_A, Success);
      Add_Spaceport (Sc, "VallesDock", Mars, 40_000, Mars_B, Success);
      Check (Success and then Mars_A /= Mars_B, "Mars two pads distinct ids");
      Check (Get_Spaceport (Sc, Mars_A).World = Mars
               and then Get_Spaceport (Sc, Mars_B).World = Mars
               and then Spaceport_Profile (Sc, Mars_A).Gravity_g =
                 Spaceport_Profile (Sc, Mars_B).Gravity_g,
             "Mars pads share profile");

      -- Titan: multiple pads
      Add_Spaceport (Sc, "KrakenPad", Titan, 15_000, Titan_1, Success);
      Add_Spaceport (Sc, "OntarioPad", Titan, 15_000, Titan_2, Success);
      Check (Success and then Titan_1 /= Titan_2
               and then Get_Spaceport (Sc, Titan_1).World = Titan
               and then Get_Spaceport (Sc, Titan_2).World = Titan,
             "Titan multiple pads");
      Check (Spaceport_Count (Sc) = 6, "spaceport catalog count 6");

      -- Bind Venus + Moon for Space_Haul path
      Add_City (Sc, "VenusCity", False, False, False, Id => Ca);
      Add_City (Sc, "MoonCity", False, False, False, Id => Cb);
      Bind_City_Pad (Sc, Ca, Venus_P, Success);
      Check (Success and then Get_City (Sc, Ca).Has_Spaceport
               and then Get_City (Sc, Ca).Has_Pad_Link,
             "bind Venus city pad");
      Bind_City_Pad (Sc, Cb, Moon_P, Success);
      Check (Success and then City_Pad_Open (Sc, Ca)
               and then City_Pad_Open (Sc, Cb),
             "pads open before crack");

      -- Crack threshold: mass > Pad_Limit
      Pad_Reconcrete
        (Sc, Venus_P, Landing_Mass_kg => 20_000,
         Cracked_Out => Cracked, Reconcrete_Hours => 2.0,
         Story => "within limit");
      Check (not Cracked and then Get_Spaceport (Sc, Venus_P).Status = Pad_Status'Val (0),
             "at pad limit no crack");

      Pad_Reconcrete
        (Sc, Venus_P, Landing_Mass_kg => 20_001,
         Cracked_Out => Cracked, Reconcrete_Hours => 2.0,
         Story => "pad cracked heavy lander");
      Check (Cracked and then Get_Spaceport (Sc, Venus_P).Status = Pad_Status'Val (1),
             "over pad limit → Cracked");
      Check (Pad_Story (Sc, Venus_P) = "pad cracked heavy lander",
             "optional story stored");
      Check (not Pad_Open (Sc, Venus_P)
               and then not City_Pad_Open (Sc, Ca),
             "cracked pad closed");

      -- Space_Haul blocked to/from cracked pad
      Create_Order (Sc, Ca, Cb, Container_Cargo, 1, 1_000.00, Oid, Success);
      Make_Offer (Sc, Oid, 1_000.00, Off, Success);
      Accept_Offer (Sc, Off, Success);
      Dispatch_Order (Sc, Oid, Space_Haul, Success => Success);
      Check (not Success, "Space_Haul blocked while pad Cracked");

      -- Repair via Tick: 2.0 hours → 7200 sim seconds
      Set_Time_Rate (Sc, 1.0);
      Tick_Delta (Sc, 3_600.0);  -- 1 h
      Sp := Get_Spaceport (Sc, Venus_P);
      Check (Sp.Status = Pad_Status'Val (1) and then Sp.Repair_Hours_Left > 0.0,
             "half repair still Cracked");
      Tick_Delta (Sc, 3_600.0);  -- 2nd hour clears
      Check (Get_Spaceport (Sc, Venus_P).Status = Pad_Status'Val (0)
               and then Pad_Open (Sc, Venus_P)
               and then City_Pad_Open (Sc, Ca),
             "repair clears after Reconcrete_Hours");

      Dispatch_Order (Sc, Oid, Space_Haul, Success => Success);
      Check (Success, "Space_Haul ok after pad repair");
      Complete_Delivery (Sc, Oid, Success);
      Check (Success, "space haul delivered post-repair");
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


   ------------------------------------------------------------------
   -- Demand_Cells: SI constants, fitness fleet, Life_Tick
   ------------------------------------------------------------------
   declare
      Cell : Demand_Cell;
      Dist : constant Float := 1.0e11;  -- long haul (~0.67 AU)
      F_Fast, F_Barge : Float;
   begin
      Check (c_m_s = 299_792_458, "c_m_s constant");
      Check (AU_m > 1.4e11 and then AU_m < 1.6e11, "AU_m SI ~1.496e11");
      Check (Barge_Gross_Mass_kg = 1_900_000.0, "barge gross 1.9e6 kg");
      Check (Barge_Cargo_Mass_kg = 1_045_000.0, "barge cargo 0.55 gross");
      Check (abs (Barge_Cargo_Mass_kg - 0.55 * Barge_Gross_Mass_kg) < 1.0,
             "cargo is 0.55 of gross");
      Check (Cruise_Speed_m_s (Barge_Inner) = 3_000.0, "Barge_Inner cruise");
      Check (Cruise_Speed_m_s (Fast_Courier) = 30_000.0, "Fast_Courier cruise");
      Check (Cruise_Speed_m_s (Barge_Inner) < Float (c_m_s), "barge speed < c");
      Check (Cruise_Speed_m_s (Fast_Courier) < Float (c_m_s), "fast speed < c");
      Check (Cruise_Speed_m_s (Relativistic_Stub) < Float (c_m_s),
             "relativistic stub speed < c");
      Check (Cruise_Speed_m_s (Relativistic_Stub)
             <= Max_Beta * Float (c_m_s) + 1.0,
             "relativistic β≤0.01");
      Check (Cruise_Speed_m_s (Space_Haul) = 3_000.0,
             "cruise Space_Haul 3000");

      F_Fast := Fitness (Fast_Courier, Dist, 1);
      F_Barge := Fitness (Barge_Inner, Dist, 1);
      Check (F_Fast > F_Barge,
             "fitness Fast_Courier > Barge_Inner on long Distance");

      -- Need 2.1e6 kg over horizon, stock 0 → deficit 2.1e6 → ceil(/1.045e6)=3
      Cell :=
        (Demand_Rate_kg_s => 210.0,
         Stock_kg         => 0.0,
         Horizon_s        => 10_000.0,
         Distance_m       => 3_000_000.0,  -- 1000 s @ barge 3000 m/s
         Fleet            => [others => 0],
         Preferred        => Barge_Inner,
         Cell_Id          => 1);
      Check (Deficit_kg (Cell) = 2_100_000.0, "deficit rate*horizon");
      Check (Shipments_Needed (Cell) = 3, "ceil deficit/cargo → 3");
      Check (Transit_Duration_s (Cell) = 1_000.0, "transit 3e6/3000");
      Check (ETA_s (Cell) = 1_000.0, "ETA matches transit");

      Cell.Stock_kg := 2_100_000.0;
      Check (Deficit_kg (Cell) = 0.0 and then Shipments_Needed (Cell) = 0,
             "full stock no deficit");

      Cell.Stock_kg := 1_055_000.0;
      Check (abs (Deficit_kg (Cell) - 1_045_000.0) < 0.1, "partial stock deficit");
      Check (Shipments_Needed (Cell) = 1, "one shipment covers remainder");

      -- Throughput: 2 barges, round-trip 2*1000 s → 1045 kg/s
      Cell.Fleet (Barge_Inner) := 2;
      Cell.Stock_kg := 0.0;
      Check (abs (Throughput_kg_s (Cell) - 1_045.0) < 0.01,
             "throughput 2*cargo/(2*transit)");

      Cell.Stock_kg := 5_000.0;
      Tick_Cell (Cell, 10.0);
      Check (abs (Cell.Stock_kg - (5_000.0 - 2_100.0 + 10_450.0)) < 0.1,
             "tick consume + arrival throughput");

      Apply_Arrival (Cell, 100.0);
      declare
         S : constant Float := Cell.Stock_kg;
      begin
         Check (abs (S - (5_000.0 - 2_100.0 + 10_450.0 + 100.0)) < 0.1,
                "Apply_Arrival adds stock");
      end;

      -- Life_Tick under-served: prefer/spawn higher fitness
      Cell :=
        (Demand_Rate_kg_s => 1_000.0,
         Stock_kg         => 0.0,
         Horizon_s        => 1_000.0,
         Distance_m       => Dist,
         Fleet            => [others => 0],
         Preferred        => Barge_Inner,
         Cell_Id          => 1);
      Check (Under_Served (Cell), "empty fleet under-served");
      Life_Tick (Cell, 0.0, Log => False);
      Check (Cell.Preferred = Best_Species (Dist),
             "Life_Tick prefers best fitness species");
      Check (Cell.Fleet (Cell.Preferred) = 1, "Life_Tick spawns one");

      -- sim_run.csv: Begin + Life_Tick append (3 species rows each)
      declare
         Log_Path : constant String := "obj/sim_run_test.csv";
         F : File_Type;
         Lines : Natural := 0;
         Buf : String (1 .. 512);
         Last : Natural;
         T : Float := 0.0;
      begin
         if Ada.Directories.Exists (Log_Path) then
            Ada.Directories.Delete_File (Log_Path);
         end if;
         Cell.Cell_Id := 42;
         Cell.Fleet := [others => 0];
         Cell.Preferred := Barge_Inner;
         Begin_Sim_Run (1.0, Log_Path, "test-run");
         Check (Ada.Directories.Exists (Log_Path), "sim_run created");
         Life_Tick (Cell, 1.0, T_s => T, Path => Log_Path, Time_Rate => 1.0);
         T := T + 1.0;
         Life_Tick (Cell, 1.0, T_s => T, Path => Log_Path, Time_Rate => 1.0);
         Open (F, In_File, Log_Path);
         while not End_Of_File (F) loop
            Get_Line (F, Buf, Last);
            Lines := Lines + 1;
         end loop;
         Close (F);
         -- #comment + header + 2 ticks × 3 species = 8 lines
         Check (Lines = 8, "sim_run comment+header+6 data rows");
         Open (F, In_File, Log_Path);
         Get_Line (F, Buf, Last);
         Check (Buf (1 .. 2) = "# " or else Buf (1) = '#',
                "sim_run first line comment");
         Check (Ada.Strings.Fixed.Index (Buf (1 .. Last), "run_id=") > 0,
                "sim_run run_id comment");
         Get_Line (F, Buf, Last);
         Check (Ada.Strings.Fixed.Index
                  (Buf (1 .. Last), "t_s,cell_id,Demand_Rate_kg_s") = 1,
                "sim_run SI header");
         Check (Ada.Strings.Fixed.Index (Buf (1 .. Last), "Fuel_Mass_kg") > 0
                  and then
                Ada.Strings.Fixed.Index (Buf (1 .. Last), "Score_kg_s") > 0,
                "sim_run SI-audit Fuel_Mass_kg+Score_kg_s");
         -- data row has non-zero fuel for Fast_Courier when Distance>0
         Get_Line (F, Buf, Last);
         Check (Ada.Strings.Fixed.Index (Buf (1 .. Last), "E+") > 0
                  or else Ada.Strings.Fixed.Index (Buf (1 .. Last), "E-") > 0
                  or else Ada.Strings.Fixed.Index (Buf (1 .. Last), ".") > 0,
                "sim_run data row numeric SI");
         Close (F);
      end;

      On_Demand_Birth (Cell);
      On_Demand_Death (Cell);
      Check (True, "demand birth/death stubs callable");
   end;


   ------------------------------------------------------------------
   -- ATC: lane capacity / separation (separate from Fitness)
   ------------------------------------------------------------------
   declare
      Pc     : Company;
      Ca, Cb : City_Id;
      V1, V2, V3 : Vehicle_Id;
      O1, O2, O3 : Order_Id;
      Ok     : Boolean;
      Lane   : Traffic_Lane;
      Cap    : Positive;
   begin
      Check (Default_Separation_m (Road) = 100.0, "ATC Road Separation_m 100");
      Check (Default_Separation_m (Tunnel) = 50.0, "ATC Tunnel Separation_m 50");
      Check (Default_Separation_m (Space_Haul) = 50_000.0,
             "ATC Space_Haul Separation_m 50000");
      Check (Space_Haul_Capacity_Cap = 8, "ATC Space_Haul capacity cap 8");

      Cap := Capacity_From_Corridor (1_000.0, 100.0, Road);
      Check (Cap = 10, "ATC Road capacity from corridor 1000/100");
      Cap := Capacity_From_Corridor (500.0, 50.0, Tunnel);
      Check (Cap = 10, "ATC Tunnel capacity from corridor 500/50");
      Cap := Capacity_From_Corridor (400_000.0, 50_000.0, Space_Haul);
      Check (Cap = 8, "ATC Space capacity 400k/50k → 8");
      Cap := Capacity_From_Corridor (500_000.0, 50_000.0, Space_Haul);
      Check (Cap = 8, "ATC Space capacity hard-capped at 8");
      Cap := Capacity_From_Corridor (50_000.0, 50_000.0, Space_Haul);
      Check (Cap = 1, "ATC Space capacity 50k/50k → 1");

      Check (Min_Slot_Spacing_s (50_000.0, 3_000.0) = 50_000.0 / 3_000.0,
             "ATC Min_Slot_Spacing_s Space_Haul");
      Check (Min_Slot_Spacing_s (100.0, 22.0) = 100.0 / 22.0,
             "ATC Min_Slot_Spacing_s Road");

      -- Below capacity OK; fill to capacity; next assign fails → Rejected_ATC
      Pc := Create_Company (20_000.00);
      Add_City (Pc, "PortA", False, False, True, Id => Ca);
      Add_City (Pc, "PortB", False, False, True, Id => Cb);
      Add_Vehicle (Pc, Light_Van, Container, True, 4, 1_000.00, V1, Ok);
      Add_Vehicle (Pc, Light_Van, Container, True, 4, 1_000.00, V2, Ok);
      Add_Vehicle (Pc, Light_Van, Container, True, 4, 1_000.00, V3, Ok);
      Check (Ok, "ATC fleet vans");

      -- Capacity 2 corridor (explicit) — Space_Haul sep lock
      Lane := Make_Lane (Ca, Cb, Space_Haul, 200_000.0, Lane_Capacity => 2);
      Check (Lane.Separation_m = 50_000.0, "Make_Lane Space sep lock 50k");
      Check (Lane.Lane_Capacity = 2, "Make_Lane explicit capacity 2");
      Check (Lane.Fleet_In_Flight = 0, "lane starts empty");

      Create_Order (Pc, Ca, Cb, Container_Cargo, 1, 100.00, O1, Ok);
      Create_Order (Pc, Ca, Cb, Container_Cargo, 1, 100.00, O2, Ok);
      Create_Order (Pc, Ca, Cb, Container_Cargo, 1, 100.00, O3, Ok);

      Assign_On_Lane (Pc, Lane, O1, V1, 200_000.0, Space_Haul, Ok);
      Check (Ok, "ATC assign below capacity OK");
      Check (Lane.Fleet_In_Flight = 1, "Fleet_In_Flight 1 after first");
      Check (Get_Order (Pc, O1).Status = En_Route, "first En_Route");

      Assign_On_Lane (Pc, Lane, O2, V2, 200_000.0, Space_Haul, Ok);
      Check (Ok, "ATC assign at last slot OK");
      Check (Lane.Fleet_In_Flight = 2, "Fleet_In_Flight at capacity");
      Check (At_Capacity (Lane), "lane At_Capacity");

      Assign_On_Lane (Pc, Lane, O3, V3, 200_000.0, Space_Haul, Ok);
      Check (not Ok, "ATC assign over capacity fails");
      Check (Get_Order (Pc, O3).Status = Rejected_ATC, "status Rejected_ATC");
      Check (Lane.Assign_Rejected = 1, "Assign_Rejected counted");
      Check (Lane.Fleet_In_Flight = 2, "Fleet_In_Flight unchanged on reject");

      -- Exception path
      begin
         Occupy_Or_Raise (Lane);
         Check (False, "Occupy_Or_Raise should raise");
      exception
         when ATC_Capacity_Exceeded =>
            Check (True, "Occupy_Or_Raise raises ATC_Capacity_Exceeded");
      end;

      Release_After_Delivery (Lane);
      Check (Lane.Fleet_In_Flight = 1, "Release frees one slot");
      Assign_On_Lane (Pc, Lane, O3, V3, 200_000.0, Space_Haul, Ok);
      -- O3 was Rejected_ATC — Assign_Vehicle only accepts Pending|Accepted
      Check (not Ok, "Rejected_ATC order not re-assignable without new order");

      declare
         O4 : Order_Id;
      begin
         Create_Order (Pc, Ca, Cb, Container_Cargo, 1, 50.00, O4, Ok);
         Assign_On_Lane (Pc, Lane, O4, V3, 200_000.0, Space_Haul, Ok);
         Check (Ok, "after Release, assign below capacity OK");
         Check (Lane.Fleet_In_Flight = 2, "back at capacity");
      end;

      -- Road corridor capacity from length
      Lane := Make_Lane (Ca, Cb, Road, 200.0);
      Check (Lane.Separation_m = 100.0, "Road Make_Lane sep 100");
      Check (Lane.Lane_Capacity = 2, "Road 200/100 capacity 2");
      Check (abs (Min_Slot_Spacing_s (Lane) - 100.0 / 22.0) < 1.0e-5,
             "Road Min_Slot_Spacing_s via lane");

      -- Log ATC columns to sim_run
      declare
         Log_Path : constant String := "obj/sim_run_atc_test.csv";
         F : File_Type;
         Buf : String (1 .. 512);
         Last : Natural;
         Found : Boolean := False;
      begin
         if Ada.Directories.Exists (Log_Path) then
            Ada.Directories.Delete_File (Log_Path);
         end if;
         Log_Lane_State (Lane, T_s => 1.0, Path => Log_Path);
         Open (F, In_File, Log_Path);
         while not End_Of_File (F) loop
            Get_Line (F, Buf, Last);
            if Ada.Strings.Fixed.Index
                 (Buf (1 .. Last), "Fleet_In_Flight") > 0
            then
               Found := True;
            end if;
         end loop;
         Close (F);
         Check (Found, "ATC sim_run logs Fleet_In_Flight header");
      end;
   end;

   ------------------------------------------------------------------
   -- Cargo kinds (TDD): Food_Dry / Food_Cold / Cosmetics / Pharma_Cold
   ------------------------------------------------------------------
   declare
      Tb : Temp_Band_C;
   begin
      Check (Primary_Body (Food_Dry) = Dry_Box, "Food_Dry primary Dry_Box");
      Check (Allows_Body (Food_Dry, Dry_Box)
               and then Allows_Body (Food_Dry, Container),
             "Food_Dry Dry_Box/Container");
      Check (Default_Hazard_Band (Food_Dry) = None
               and then Hazard_Band_Allowed (Food_Dry, Low),
             "Food_Dry hazard None/Low");
      Check (abs (Density_kg_m3_Of (Food_Dry) - 400.0) < 1.0,
             "Food_Dry density ~400");

      Check (Primary_Body (Food_Cold) = Reefer, "Food_Cold primary Reefer");
      Check (Default_Hazard_Band (Food_Cold) = Low, "Food_Cold hazard Low");
      Tb := Temp_Band_Of (Food_Cold);
      Check (Tb.Controlled and then Tb.Lo_C = 0.0 and then Tb.Hi_C = 4.0,
             "Food_Cold T 0..4 C");

      Check (Primary_Body (Cosmetics) = Dry_Box, "Cosmetics Dry_Box");
      Check (Default_Hazard_Band (Cosmetics) = Low, "Cosmetics hazard Low");
      Check (abs (Density_kg_m3_Of (Cosmetics) - 600.0) < 1.0,
             "Cosmetics density ~600");

      Check (Primary_Body (Pharma_Cold) = Reefer, "Pharma_Cold Reefer");
      Check (Default_Hazard_Band (Pharma_Cold) = Mid, "Pharma_Cold Mid");
      Tb := Temp_Band_Of (Pharma_Cold);
      Check (Tb.Controlled and then Tb.Lo_C = 2.0 and then Tb.Hi_C = 8.0,
             "Pharma_Cold T 2..8 C");

      Check (not Allows_Body (Food_Cold, Flatbed)
               and then not Allows_Body (Pharma_Cold, Flatbed),
             "reject cold on Flatbed");
      Check (not Compatible (Food_Cold, Flatbed, Road),
             "Food_Cold not Flatbed Compatible");
      Check (Compatible (Food_Dry, Dry_Box, Road)
               and then Compatible (Food_Dry, Container, Road),
             "Food_Dry Compatible Dry_Box/Container");
      Check (Compatible (Cosmetics, Dry_Box, Road), "Cosmetics Compatible");
      Check (Compatible (Pharma_Cold, Reefer, Road), "Pharma_Cold Compatible");

      -- Extreme hazard banned on M1 Car_*
      Check (not Vehicle_Cargo_Ok
                (Profile_M1 (Car_Small), Food_Dry, Dry_Box, Explosives),
             "reject Extreme on M1 Car_Small");
      Check (not Vehicle_Cargo_Ok
                (Profile_M1 (Car_Medium), Cosmetics, Dry_Box, Radioactive),
             "reject Extreme on M1 Car_Medium");
      Check (Vehicle_Cargo_Ok
                (Profile_M1 (Car_Large), Food_Dry, Dry_Box, None),
             "M1 Car_Large Food_Dry OK");
      Check (not Vehicle_Cargo_Ok
                (Profile_M1 (Car_Small), Food_Cold, Reefer, None),
             "M1 rejects Food_Cold last-mile");
      Check (not Vehicle_Cargo_Ok
                (Van_N1, Food_Cold, Flatbed, None),
             "N1 rejects Food_Cold on Flatbed");
   end;

   ------------------------------------------------------------------
   -- M1 last-mile assign: Cosmetics / Food_Dry; N1 van / N2-N3 bulk
   ------------------------------------------------------------------
   declare
      Pc : Company;
      Ca, Cb : City_Id;
      Vs, Vm, Vl, Vn, Vr : Vehicle_Id;
      O1, O2, O3, O4 : Order_Id;
      Ok : Boolean;
      Sid : Staff_Id;
   begin
      Pc := Create_Company (100_000.00);
      Add_City (Pc, "ShopA", False, False, Id => Ca);
      Add_City (Pc, "ShopB", False, False, Id => Cb);
      Hire_Staff (Pc, Dispatcher, 100.00, Sid, Ok);
      Hire_Staff (Pc, Driver, 100.00, Sid, Ok);

      Add_Vehicle
        (Pc, Light_Van, Dry_Box, True, 2, 1_000.00, Vs, Ok,
         Phys => Profile_M1 (Car_Small));
      Add_Vehicle
        (Pc, Light_Van, Dry_Box, True, 2, 1_000.00, Vm, Ok,
         Phys => Profile_M1 (Car_Medium));
      Add_Vehicle
        (Pc, Light_Van, Dry_Box, True, 2, 1_000.00, Vl, Ok,
         Phys => Profile_M1 (Car_Large));
      Add_Vehicle (Pc, Light_Van, Dry_Box, True, 4, 2_000.00, Vn, Ok);
      Add_Vehicle (Pc, Rigid, Reefer, True, 16, 8_000.00, Vr, Ok);
      Check (Ok, "M1/N1/N2 fleet seed");

      Create_Order (Pc, Ca, Cb, Cosmetics, 1, 50.00, O1, Ok);
      Create_Order (Pc, Ca, Cb, Food_Dry, 1, 50.00, O2, Ok);
      Create_Order (Pc, Ca, Cb, Food_Cold, 1, 80.00, O3, Ok);
      Create_Order (Pc, Ca, Cb, Pharma_Cold, 2, 120.00, O4, Ok);

      -- Accept via offer path
      declare
         Off : Offer_Id;
      begin
         Make_Offer (Pc, O1, 50.00, Off, Ok);
         Accept_Offer (Pc, Off, Ok);
         Make_Offer (Pc, O2, 50.00, Off, Ok);
         Accept_Offer (Pc, Off, Ok);
         Make_Offer (Pc, O3, 80.00, Off, Ok);
         Accept_Offer (Pc, Off, Ok);
         Make_Offer (Pc, O4, 120.00, Off, Ok);
         Accept_Offer (Pc, Off, Ok);
      end;

      Dispatch_Order (Pc, O1, Road, Vs, Ok);
      Check (Ok, "M1 Car_Small Cosmetics assign");
      Dispatch_Order (Pc, O2, Road, Vm, Ok);
      Check (Ok, "M1 Car_Medium Food_Dry assign");

      -- Cold needs reefer rigid (N2/N3), not M1
      Dispatch_Order (Pc, O3, Road, Vl, Ok);
      Check (not Ok, "M1 rejects Food_Cold assign");
      Dispatch_Order (Pc, O3, Road, Vr, Ok);
      Check (Ok, "N2/N3 reefer Food_Cold assign");

      -- N1 van still Dry_Box Food_Dry
      declare
         O5 : Order_Id;
         Off : Offer_Id;
      begin
         Create_Order (Pc, Ca, Cb, Food_Dry, 1, 40.00, O5, Ok);
         Make_Offer (Pc, O5, 40.00, Off, Ok);
         Accept_Offer (Pc, Off, Ok);
         Dispatch_Order (Pc, O5, Road, Vn, Ok);
         Check (Ok, "N1 van Food_Dry still works");
      end;

      Dispatch_Order (Pc, O4, Road, Vr, Ok);
      -- Vr already busy on O3
      Check (not Ok or else Get_Vehicle (Pc, Vr).Available = False,
             "Pharma_Cold uses bulk reefer path");
   end;

   ------------------------------------------------------------------
   -- Hub Position_m / Distance_m (Terra_0 origin)
   ------------------------------------------------------------------
   declare
      D_Moon, D_Back, D_Mars : Float;
      Pa, Pb : Position_m;
   begin
      Check (Position_Of (Terra_0).X = 0.0
               and then Position_Of (Terra_0).Y = 0.0
               and then Position_Of (Terra_0).Z = 0.0,
             "Terra_0 at origin");
      D_Moon := Distance_m (Terra_0, Moon_Polar);
      Check (abs (D_Moon - Earth_Moon_Distance_m) < 1.0e3,
             "Moon distance ~3.84e8");
      D_Back := Distance_m (Moon_Polar, Terra_0);
      Check (abs (D_Moon - D_Back) < 1.0e-3, "Distance(A,B)=Distance(B,A)");
      D_Mars := Distance_m (Terra_0, Mars);
      Check (abs (D_Mars - Mars_Offset_m) < 1.0, "Mars AU-scale offset");
      Pa := (X => 3.0, Y => 4.0, Z => 0.0);
      Pb := Terra_Origin;
      Check (abs (Distance_m (Pa, Pb) - 5.0) < 1.0e-5, "Euclidean 3-4-5");
   end;

   ------------------------------------------------------------------
   -- Consumables SI + min cruise (Moon / Mars, Crew_150)
   ------------------------------------------------------------------
   declare
      Dr : Float;
      V_Moon, V_Mars : Float;
   begin
      Check (Consumables_kg_person_day = 2.5, "Consumables_kg_person_day 2.5");
      Check (Crew_150 = 150, "Crew_150 constant");
      Dr := Demand_Rate_kg_s (Crew_150);
      Check (abs (Dr - Float (Crew_150) * 2.5 / 86_400.0) < 1.0e-9,
             "Demand_Rate_kg_s crew*kg_d/86400");
      V_Moon := Min_Cruise_Speed_m_s
        (Dr, Earth_Moon_Distance_m, Barge_Cargo_Mass_kg);
      Check (V_Moon >= 3.18 and then V_Moon < 3.25,
             "Moon 3.84e8 Barge min cruise ~>=3.2 m/s");
      V_Mars := Min_Cruise_Speed_m_s
        (Dr, Mars_Offset_m, Barge_Cargo_Mass_kg);
      Check (V_Mars >= 1.8e3 and then V_Mars < 2.0e3,
             "Mars 2.25e11 Barge min cruise ~>=1.9e3");
      Check (Speed_Space_Haul_m_s >= V_Mars,
             "Space_Haul 3000 suffices one 150-person Mars port");
   end;

   ------------------------------------------------------------------
   -- Tournament Score_kg_s + fuel; Reward_Coin; N-tick evolve
   ------------------------------------------------------------------
   declare
      Dist : constant Float := 3_000_000.0;
      Sc_B, Sc_F, Sc_R : Float;
      Fu_B, Fu_F : Float;
      Ref : Float;
      Cell : Demand_Cell;
      State : Tournament_State;
      Log_Path : constant String := "obj/sim_run_tournament_test.csv";
      F : File_Type;
      Buf : String (1 .. 512);
      Last : Natural;
      Found_Score, Found_Fuel, Found_Pay : Boolean := False;
   begin
      Fu_B := Fuel_Mass_kg (Barge_Inner);
      Fu_F := Fuel_Mass_kg (Fast_Courier);
      Check (Fu_F > Fu_B, "higher speed increases fuel");
      Check (Cruise_Speed_m_s (Fast_Courier) < Float (c_m_s)
               and then Cruise_Speed_m_s (Relativistic_Stub) < Float (c_m_s),
             "cruise still < c");

      Sc_B := Score_kg_s (Barge_Inner, Dist);
      Sc_F := Score_kg_s (Fast_Courier, Dist);
      Sc_R := Score_kg_s (Relativistic_Stub, Dist);
      Check (Sc_B > 0.0, "barge mid score > 0");
      Check (Sc_F < Sc_B or else Payload_Net_kg (Fast_Courier) = 0.0,
             "extreme speed can lower Score vs mid");
      Check (Sc_R <= Sc_B, "relativistic score not above barge mid");

      Ref := Score_Ref_kg_s (Dist);
      Check (abs (Ref - Sc_B) < 1.0e-6, "Score_Ref = Barge Score");
      Check (abs (Reward_Coin (Barge_Inner, Dist, Ref) - 1.00) < 1.0e-5,
             "Reward_Coin barge = 1.00 * ratio");

      -- more cargo at same speed → higher score (barge > stub cargo)
      Check (Profile_Of (Barge_Inner).Cargo_Mass_kg
               > Profile_Of (Relativistic_Stub).Cargo_Mass_kg,
             "barge has more cargo than stub");

      Cell :=
        (Demand_Rate_kg_s => 500.0,
         Stock_kg         => 0.0,
         Horizon_s        => 1_000.0,
         Distance_m       => Dist,
         Fleet            => [others => 0],
         Preferred        => Barge_Inner,
         Cell_Id          => 7);
      State := (others => <>);
      if Ada.Directories.Exists (Log_Path) then
         Ada.Directories.Delete_File (Log_Path);
      end if;
      Run_Tournament_Ticks
        (Cell, State, N_Ticks => 5, Delta_s => 1.0,
         Log => True, Path => Log_Path, Time_Rate => 1.0);
      Check (State.Active and then State.Rewards (Tournament_Winner (State, Dist))
               >= State.Rewards (Barge_Inner),
             "tournament accrues rewards; winner max sum");
      Check (Ship_Count (Cell) > 0, "tournament N ticks spawn biased");

      Open (F, In_File, Log_Path);
      Get_Line (F, Buf, Last);  -- comment
      Get_Line (F, Buf, Last);  -- header
      Found_Score := Ada.Strings.Fixed.Index (Buf (1 .. Last), "Score_kg_s") > 0;
      Found_Fuel := Ada.Strings.Fixed.Index (Buf (1 .. Last), "Fuel_Mass_kg") > 0;
      Found_Pay := Ada.Strings.Fixed.Index (Buf (1 .. Last), "Payload_Net_kg") > 0;
      Close (F);
      Check (Found_Score and then
               Ada.Strings.Fixed.Index (Buf (1 .. Last), "Reward_Coin") > 0,
             "sim_run logs Score_kg_s,Reward_Coin");
      Check (Found_Fuel and then Found_Pay,
             "sim_run logs Fuel_Mass_kg,Payload_Net_kg");
   end;

   New_Line;
   Put_Line ("Passed:" & Passed'Image & "  Failed:" & Failed'Image);
   if Failed > 0 then
      raise Program_Error with "tests failed";
   end if;
end Tests;
