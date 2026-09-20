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
   Check (Compatible (Container_Cargo, Container, Space), "container space");
   Check (not Compatible (Flatbed_Cargo, Flatbed, Space), "flatbed not space");

   Check (Mode_Allows_Hazard (Road, Explosives), "road allows explosives");
   Check (not Mode_Allows_Hazard (Air, Explosives), "air denies explosives");
   Check (not Mode_Allows_Hazard (Space, Radioactive), "space denies radioactive");
   Check (Mode_Allows_Hazard (Air, Flammable_Liquids), "air allows flammable liquids");
   Check (Mode_Allows_Hazard (Space, Corrosive), "space allows corrosive");
   Check (Requires_Tank_Body (Gases)
            and then Requires_Tank_Body (Flammable_Liquids)
            and then not Requires_Tank_Body (Explosives),
          "tank required for gases/flammable liquids");
   declare
      Cost_Img : constant String := Space_Cost_Factor'Image;
      Time_Img : constant String := Space_Time_Factor'Image;
   begin
      Check (Cost_Img'Length > 0 and then Time_Img'Length > 0,
             "space cost/time factors present");
   end;

   ------------------------------------------------------------------
   -- Company / cities
   ------------------------------------------------------------------
   C := Create_Company (80_000.00, 5);
   Add_City (C, "Alpha", True, True, False, A);
   Add_City (C, "Beta", True, True, False, B);
   City := Get_City (C, A);
   Check (City.Has_Rail and then not City.Has_Spaceport, "city rail always");
   Add_City (C, "OrbitGate", True, False, True, Sp1);
   Add_City (C, "LunaDock", False, False, True, Sp2);

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
   Dispatch_Order (C, Oid, Space, Success => Ok);
   Check (Ok, "space container like air gate");
   Complete_Delivery (C, Oid, Ok);

   Create_Order (C, Sp1, Sp2, Flatbed_Cargo, 2, 100.00, Oid, Ok);
   Make_Offer (C, Oid, 100.00, Off, Ok);
   Accept_Offer (C, Off, Ok);
   Dispatch_Order (C, Oid, Space, Success => Ok);
   Check (not Ok, "space non-container rejected");

   Create_Order (C, A, B, Container_Cargo, 1, 100.00, Oid, Ok);
   Make_Offer (C, Oid, 100.00, Off, Ok);
   Accept_Offer (C, Off, Ok);
   Dispatch_Order (C, Oid, Space, Success => Ok);
   Check (not Ok, "space without spaceports");

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
   Dispatch_Order (C, Oid, Space, Success => Ok);
   Check (not Ok, "space rejects explosives");

   Create_Order
     (C, Sp1, Sp2, Container_Cargo, 1, 200.00, Oid, Ok,
      Hazard => Radioactive, Placard => "70/XXXX ");
   Make_Offer (C, Oid, 200.00, Off, Ok);
   Accept_Offer (C, Off, Ok);
   Dispatch_Order (C, Oid, Space, Success => Ok);
   Check (not Ok, "space rejects radioactive");

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

   New_Line;
   Put_Line ("Passed:" & Passed'Image & "  Failed:" & Failed'Image);
   if Failed > 0 then
      raise Program_Error with "tests failed";
   end if;
end Tests;
