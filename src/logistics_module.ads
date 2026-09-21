--  Clean-room Ada 2022 logistics / forwarding simulation (Step 1).
--  Inspired by the public logistics-sim genre only.
--  Our types: fleet, bodies, cargo matrix, cities/facilities, FE,
--  ADR-inspired hazard classes (not legal text), EU vehicle classes
--  (inspired by EU vehicle categories VO 2018/858), haul ambient,
--  hazard insurance premiums + cover legs. No proprietary assets.

pragma Ada_2022;

with Ada.Calendar;

package Logistics_Module is

   pragma Elaborate_Body;

   type Money is delta 0.01 range -1_000_000_000.00 .. 1_000_000_000.00;
   type Reputation_Points is range -1000 .. 1000;

   subtype Freight_Units is Natural;

   type City_Id is new Positive;
   type Vehicle_Id is new Positive;
   type Body_Id is new Positive;
   type Order_Id is new Positive;
   type Staff_Id is new Positive;
   type Offer_Id is new Positive;
   type Rail_Slot_Id is new Positive;

   -- Light_Van / Rigid / Artic_Tractor (tractor alone carries 0 FE)
   type Vehicle_Kind is (Light_Van, Rigid, Artic_Tractor);
   type Body_Kind is (Silo, Tank, Reefer, Flatbed, Container, Lowboy, Dry_Box);

   ------------------------------------------------------------------
   -- EU vehicle categories (clean-room Physical_Data + category structure).
   -- Inspired by EU vehicle categories VO 2018/858.
   -- v0 focus: M1, N1, N2, N3; O2/O4 optional trailer stubs.
   ------------------------------------------------------------------
   type EU_Vehicle_Class is (M1, M2, M3, N1, N2, N3, O1, O2, O3, O4);

   -- M1 passenger size tags (no N-style goods GVW band)
   type EU_Class_M1 is (Car_Small, Car_Medium, Car_Large);

   subtype Mass_Kilograms is Natural range 0 .. 100_000;
   subtype GVW_Kilograms is Mass_Kilograms;
   type Metres is delta 0.01 digits 7;
   subtype Footprint_Length_m is Metres;
   subtype Footprint_Width_m is Metres;

   -- N-class GVW limits (Physical_Data). N3 uses typical artic check cap.
   N1_GVW_Max        : constant GVW_Kilograms := 3_500;
   N2_GVW_Max        : constant GVW_Kilograms := 12_000;
   N3_GVW_Check_Cap  : constant GVW_Kilograms := 40_000;
   -- O2/O4 trailer stubs
   O2_GVW_Stub_Max   : constant GVW_Kilograms := 3_500;
   O4_GVW_Stub_Max   : constant GVW_Kilograms := 40_000;

   type Vehicle_Physical is record
      Curb_Mass : Mass_Kilograms := 0;
      GVW       : GVW_Kilograms := 0;
      Length_m  : Footprint_Length_m := 0.0;
      Width_m   : Footprint_Width_m := 0.0;
      EU_Class  : EU_Vehicle_Class := N1;
      M1_Size   : EU_Class_M1 := Car_Medium;
   end record;

   -- Physical_Data DS: M1 size tags
   M1_Car_Small  : constant Vehicle_Physical :=
     (Curb_Mass          => 1_100,
      GVW                => 1_400,
      Length_m => 4.00,
      Width_m  => 1.70,
      EU_Class           => M1,
      M1_Size            => Car_Small);
   M1_Car_Medium : constant Vehicle_Physical :=
     (Curb_Mass          => 1_500,
      GVW                => 2_000,
      Length_m => 4.60,
      Width_m  => 1.80,
      EU_Class           => M1,
      M1_Size            => Car_Medium);
   M1_Car_Large  : constant Vehicle_Physical :=
     (Curb_Mass          => 2_200,
      GVW                => 3_000,
      Length_m => 5.00,
      Width_m  => 2.00,
      EU_Class           => M1,
      M1_Size            => Car_Large);

   -- Physical_Data DS: lorry rigid (N2/N3 by GVW) and optional artic N3
   Lorry_Rigid : constant Vehicle_Physical :=
     (Curb_Mass          => 8_000,
      GVW                => 18_000,
      Length_m => 8.00,
      Width_m  => 2.50,
      EU_Class           => N3,
      M1_Size            => Car_Medium);
   Lorry_Artic : constant Vehicle_Physical :=
     (Curb_Mass          => 15_000,
      GVW                => 40_000,
      Length_m => 16.50,
      Width_m  => 2.55,
      EU_Class           => N3,
      M1_Size            => Car_Medium);
   -- Light van / N1 default profile
   Van_N1 : constant Vehicle_Physical :=
     (Curb_Mass          => 2_000,
      GVW                => 3_500,
      Length_m => 5.50,
      Width_m  => 2.00,
      EU_Class           => N1,
      M1_Size            => Car_Medium);

   function Profile_M1 (Size : EU_Class_M1) return Vehicle_Physical;

   function Footprint_Area_M2
     (Length : Footprint_Length_m;
      Width  : Footprint_Width_m) return Float;

   -- Pre-condition helper: GVW must be >= curb mass
   function Masses_Valid
     (Curb : Mass_Kilograms; GVW : GVW_Kilograms) return Boolean
   with
     Post => Masses_Valid'Result = (GVW >= GVW_Kilograms (Curb));

   function Class_GVW_Limit (Class : EU_Vehicle_Class) return GVW_Kilograms;

   function Within_GVW_Class_Limit
     (Class : EU_Vehicle_Class; GVW : GVW_Kilograms) return Boolean;

   -- Light_Van→N1; Rigid→N2/N3 by GVW; Artic_Tractor→N3
   function Map_Kind_To_EU_Class
     (Kind : Vehicle_Kind; GVW : GVW_Kilograms) return EU_Vehicle_Class;

   -- Trailer stubs: O2 if GVW <= O2 stub max, else O4
   function Map_Trailer_To_EU_Class
     (GVW : GVW_Kilograms) return EU_Vehicle_Class;

   function Default_Physical (Kind : Vehicle_Kind) return Vehicle_Physical;

   function Make_Physical
     (Curb   : Mass_Kilograms;
      GVW    : GVW_Kilograms;
      Length : Footprint_Length_m;
      Width  : Footprint_Width_m;
      Class  : EU_Vehicle_Class;
      M1_Size : EU_Class_M1 := Car_Medium) return Vehicle_Physical
   with
     Pre => GVW >= GVW_Kilograms (Curb);

   type Cargo_Class is
     (Silo_Cargo, Tank_Cargo, Lowboy_Cargo, Reefer_Cargo,
      Flatbed_Cargo, Container_Cargo, Dry_Box_Cargo);

   -- Product cargo kinds (profiles declared with hazard bands below).
   type Cargo_Kind is (Food_Dry, Food_Cold, Cosmetics, Pharma_Cold);

   type Temp_Band_C is record
      Lo_C       : Float := 0.0;
      Hi_C       : Float := 0.0;
      Controlled : Boolean := False;
   end record;

   Density_Food_Dry_kg_m3  : constant Float := 400.0;
   Density_Cosmetics_kg_m3 : constant Float := 600.0;

   Food_Cold_Temp   : constant Temp_Band_C :=
     (Lo_C => 0.0, Hi_C => 4.0, Controlled => True);
   Pharma_Cold_Temp : constant Temp_Band_C :=
     (Lo_C => 2.0, Hi_C => 8.0, Controlled => True);

   type Dispatch_Mode is (Road, Rail, Sea, Air, Space_Haul, Tunnel);

   -- ADR-inspired lean classes 1–9 + None (clean-room; not legal copy)
   type Hazard_Class is
     (None,
      Explosives,
      Gases,
      Flammable_Liquids,
      Flammable_Solids,
      Oxidizers,
      Toxic_Infectious,
      Radioactive,
      Corrosive,
      Misc_Dangerous);

   -- Orange-plate style data field only (no graphics)
   subtype Placard_Code is String (1 .. 8);
   Empty_Placard : constant Placard_Code := "        ";

   -- Space_Haul ≅ Air (spaceport gate); higher cost/time multipliers
   Space_Cost_Factor : constant := 3;
   Space_Time_Factor : constant := 2;

   ------------------------------------------------------------------
   -- Haul / transport environment (ambient lean + insurance premiums).
   -- Road / Tunnel / Space_Haul. Rail/Air/Sea remain route Dispatch_Modes.
   ------------------------------------------------------------------
   type Haul_Mode is (Road, Tunnel, Space_Haul);

   -- Ambient lean (Physical_Data): pressure kPa, g, radiation µSv/h
   type Ambient_Lean is record
      Cabin_Pressure_kPa : Float := 101.0;
      Ext_Pressure_kPa   : Float := 101.0;
      Gravity_g          : Float := 1.0;
      Rad_uSv_Per_h_Lo   : Float := 0.1;
      Rad_uSv_Per_h_Hi   : Float := 0.1;
   end record;

   Ambient_Road : constant Ambient_Lean :=
     (Cabin_Pressure_kPa => 101.0, Ext_Pressure_kPa => 101.0,
      Gravity_g => 1.0, Rad_uSv_Per_h_Lo => 0.1, Rad_uSv_Per_h_Hi => 0.1);
   Ambient_Tunnel : constant Ambient_Lean :=
     (Cabin_Pressure_kPa => 101.0, Ext_Pressure_kPa => 101.0,
      Gravity_g => 1.0, Rad_uSv_Per_h_Lo => 0.05, Rad_uSv_Per_h_Hi => 0.2);
   Ambient_Space_Haul : constant Ambient_Lean :=
     (Cabin_Pressure_kPa => 101.0, Ext_Pressure_kPa => 0.0,
      Gravity_g => 0.0, Rad_uSv_Per_h_Lo => 50.0, Rad_uSv_Per_h_Hi => 100.0);

   function Ambient_For (Mode : Haul_Mode) return Ambient_Lean;

   function To_Haul_Mode (Mode : Dispatch_Mode) return Haul_Mode
   with
     Pre => Mode in Road | Tunnel | Space_Haul;

   ------------------------------------------------------------------
   -- World_Body profiles + spaceport catalog (DS SI, lean).
   ------------------------------------------------------------------
   type World_Body is (Terra_0, Venus_Cloud_Port, Moon_Polar, Mars, Titan);

   type Atmos_Kind is (CO2, Vacuum, Thin_CO2, N2_CH4, Earth_N2);

   type World_Body_Profile is record
      Altitude_m       : Float := 0.0;
      Ext_Pressure_kPa : Float := 0.0;
      Temp_C_Lo        : Float := 0.0;
      Temp_C_Hi        : Float := 0.0;
      Gravity_g        : Float := 1.0;
      Rad_uSv_Per_h_Lo : Float := 0.1;
      Rad_uSv_Per_h_Hi : Float := 0.1;
      Atmos            : Atmos_Kind := CO2;
      Has_Spaceport    : Boolean := False;
      Float_Pad        : Boolean := False;
      Relay            : Boolean := False;
   end record;

   ------------------------------------------------------------------
   -- Hub positions (SI metres). Origin = Terra_0 (0,0,0).
   -- Distance_m = Euclidean norm; Road/Tunnel may use local 2D on Terra.
   ------------------------------------------------------------------
   type Position_m is record
      X : Float := 0.0;
      Y : Float := 0.0;
      Z : Float := 0.0;
   end record;

   Terra_Origin : constant Position_m := (0.0, 0.0, 0.0);

   -- Lean stubs (ops-owned placeholders)
   Hub_AU_m                : constant Float := 1.495_978_707e11;
   Earth_Moon_Distance_m   : constant Float := 3.84e8;
   Mars_Offset_m           : constant Float := 2.25e11;  -- ~1.5 AU lean

   function Position_Of (World : World_Body) return Position_m;
   function Distance_m (A, B : Position_m) return Float
   with
     Post => Distance_m'Result >= 0.0;
   function Distance_m (A, B : World_Body) return Float
   with
     Post => Distance_m'Result >= 0.0;

   -- Terra surface hub (origin). Ambient lean ≈ Road.
   Profile_Terra_0 : constant World_Body_Profile :=
     (Altitude_m       => 0.0,
      Ext_Pressure_kPa => 101.0,
      Temp_C_Lo        => -20.0,
      Temp_C_Hi        => 40.0,
      Gravity_g        => 1.0,
      Rad_uSv_Per_h_Lo => 0.1,
      Rad_uSv_Per_h_Hi => 0.1,
      Atmos            => Earth_N2,
      Has_Spaceport    => True,
      Float_Pad        => False,
      Relay            => False);

   -- Venus cloud deck float port (~50 km): Earth-like P, warm CO2, g_eff≈0.90
   Profile_Venus_Cloud_Port : constant World_Body_Profile :=
     (Altitude_m       => 50_000.0,
      Ext_Pressure_kPa => 101.0,
      Temp_C_Lo        => 60.0,
      Temp_C_Hi        => 75.0,
      Gravity_g        => 0.90,
      Rad_uSv_Per_h_Lo => 0.1,
      Rad_uSv_Per_h_Hi => 0.2,
      Atmos            => CO2,
      Has_Spaceport    => True,
      Float_Pad        => True,
      Relay            => False);

   -- Moon polar: vacuum, low g, high rad, relay flag
   Profile_Moon_Polar : constant World_Body_Profile :=
     (Altitude_m       => 0.0,
      Ext_Pressure_kPa => 0.0,
      Temp_C_Lo        => -230.0,
      Temp_C_Hi        => -150.0,
      Gravity_g        => 0.17,
      Rad_uSv_Per_h_Lo => 50.0,
      Rad_uSv_Per_h_Hi => 200.0,
      Atmos            => Vacuum,
      Has_Spaceport    => True,
      Float_Pad        => False,
      Relay            => True);

   -- Mars surface (typical lean SI); many Spaceport_Ids share this profile
   Profile_Mars : constant World_Body_Profile :=
     (Altitude_m       => 0.0,
      Ext_Pressure_kPa => 0.6,
      Temp_C_Lo        => -60.0,
      Temp_C_Hi        => 0.0,
      Gravity_g        => 0.38,
      Rad_uSv_Per_h_Lo => 10.0,
      Rad_uSv_Per_h_Hi => 30.0,
      Atmos            => Thin_CO2,
      Has_Spaceport    => True,
      Float_Pad        => False,
      Relay            => False);

   -- Titan surface; multiple pads share this profile
   Profile_Titan : constant World_Body_Profile :=
     (Altitude_m       => 0.0,
      Ext_Pressure_kPa => 146.7,
      Temp_C_Lo        => -180.0,
      Temp_C_Hi        => -179.0,
      Gravity_g        => 0.14,
      Rad_uSv_Per_h_Lo => 0.01,
      Rad_uSv_Per_h_Hi => 0.05,
      Atmos            => N2_CH4,
      Has_Spaceport    => True,
      Float_Pad        => False,
      Relay            => False);

   function Profile_Of (World : World_Body) return World_Body_Profile
   with
     Post =>
       (case World is
          when Terra_0 =>
            Profile_Of'Result.Gravity_g = 1.0
              and then Profile_Of'Result.Ext_Pressure_kPa = 101.0,
          when Venus_Cloud_Port =>
            Profile_Of'Result.Altitude_m = 50_000.0
              and then Profile_Of'Result.Ext_Pressure_kPa = 101.0
              and then Profile_Of'Result.Float_Pad,
          when Moon_Polar =>
            Profile_Of'Result.Ext_Pressure_kPa = 0.0
              and then Profile_Of'Result.Relay,
          when Mars =>
            Profile_Of'Result.Gravity_g = 0.38,
          when Titan =>
            Profile_Of'Result.Atmos = N2_CH4);

   type Spaceport_Id is new Positive;
   type Pad_Status is (Ok, Cracked);

   Max_Spaceports : constant := 32;
   Default_Reconcrete_Hours : constant Float := 24.0;
   Default_Pad_Limit_kg     : constant Mass_Kilograms := 40_000;

   subtype Story_Text is String (1 .. 64);
   Empty_Story : constant Story_Text := [others => ' '];

   type Spaceport_Record is record
      World              : World_Body := Mars;
      Pad_Limit_kg       : Mass_Kilograms := Default_Pad_Limit_kg;
      Status             : Pad_Status := Ok;
      Repair_Hours_Left  : Float := 0.0;
      Last_Story         : Story_Text := Empty_Story;
      Last_Story_Len     : Natural := 0;
   end record;

   ------------------------------------------------------------------
   -- Hazard insurance premium bands + cover legs (clean-room).
   ------------------------------------------------------------------
   type Hazard_Premium_Band is (None, Low, Mid, High, Extreme);

   -- Fixed-point premium multiplier (1.000 = 1x). Prefer over Float.
   type Premium_Multiplier is delta 0.001 digits 9;

   type Cover_Kind is
     (Cargo_Loss, Hull_Loss, Crew_Loss, Crew_Sick, Emergency_Leave);

   type Cover_Selection is array (Cover_Kind) of Boolean;

   Empty_Cover : constant Cover_Selection := [others => False];
   Full_Cover  : constant Cover_Selection := [others => True];

   -- Optional claim event stubs (distinct literals from Cover_Kind)
   type Claim_Event is
     (Claim_Cargo_Lost, Claim_Hull_Lost, Claim_Crew_Lost,
      Claim_Crew_Sick, Claim_Emergency_Leave);

   function Band_Of (Hazard : Hazard_Class) return Hazard_Premium_Band;

   function Base_Band_Factor (Band : Hazard_Premium_Band) return Premium_Multiplier
   with
     Post =>
       (case Band is
          when None    => Base_Band_Factor'Result = 1.0,
          when Low     => Base_Band_Factor'Result = 1.2,
          when Mid     => Base_Band_Factor'Result = 2.0,
          when High    => Base_Band_Factor'Result = 4.0,
          when Extreme => Base_Band_Factor'Result = 10.0);

   -- Extreme-only mode extras: Space_Haul 1.5, Tunnel 1.2, Road 1.0
   function Extreme_Mode_Multiplier (Mode : Haul_Mode) return Premium_Multiplier
   with
     Post =>
       (case Mode is
          when Road       => Extreme_Mode_Multiplier'Result = 1.0,
          when Tunnel     => Extreme_Mode_Multiplier'Result = 1.2,
          when Space_Haul => Extreme_Mode_Multiplier'Result = 1.5);

   function Premium_Factor
     (Hazard : Hazard_Class; Mode : Haul_Mode) return Premium_Multiplier
   with
     Post =>
       (if Band_Of (Hazard) /= Extreme then
          Premium_Factor'Result = Base_Band_Factor (Band_Of (Hazard))
        else
          Premium_Factor'Result =
            Base_Band_Factor (Extreme) * Extreme_Mode_Multiplier (Mode));

   function Cover_Leg_Factor (Kind : Cover_Kind) return Premium_Multiplier
   with
     Post =>
       (case Kind is
          when Cargo_Loss       => Cover_Leg_Factor'Result = 1.0,
          when Hull_Loss        => Cover_Leg_Factor'Result = 0.6,
          when Crew_Loss        => Cover_Leg_Factor'Result = 0.8,
          when Crew_Sick        => Cover_Leg_Factor'Result = 0.25,
          when Emergency_Leave  => Cover_Leg_Factor'Result = 0.10);

   function Selected_Cover_Sum
     (Selected : Cover_Selection) return Premium_Multiplier;

   -- Total = sum(selected legs) × Premium_Factor(Hazard, Mode)
   function Total_Premium_Factor
     (Hazard   : Hazard_Class;
      Mode     : Haul_Mode;
      Selected : Cover_Selection) return Premium_Multiplier
   with
     Post =>
       Total_Premium_Factor'Result =
         Selected_Cover_Sum (Selected) * Premium_Factor (Hazard, Mode);

   -- Cargo/body/mode matrix (see README)
   --  Body × mode gate for a cargo class (does not move freight).
   --  Full IRL-inspired matrix: see Physical_Data.md § Cargo compatibility.
   --  Road|Tunnel: Equip must match the dedicated road body.
   --  Other modes: True means the *mode* can carry the class (specialized
   --  stock); Equip is ignored. Space_Haul: Container only.
   function Compatible
     (Cargo : Cargo_Class;
      Equip : Body_Kind;
      Mode  : Dispatch_Mode) return Boolean;

   function Compatible
     (Kind  : Cargo_Kind;
      Equip : Body_Kind;
      Mode  : Dispatch_Mode) return Boolean;

   function Van_Can_Carry (Cargo : Cargo_Class) return Boolean;

   function To_Cargo_Class (Kind : Cargo_Kind) return Cargo_Class;
   function Primary_Body (Kind : Cargo_Kind) return Body_Kind;
   function Allows_Body (Kind : Cargo_Kind; Equip : Body_Kind) return Boolean;
   function Default_Hazard_Band (Kind : Cargo_Kind) return Hazard_Premium_Band;
   function Hazard_Band_Allowed
     (Kind : Cargo_Kind; Band : Hazard_Premium_Band) return Boolean;
   function Density_kg_m3_Of (Kind : Cargo_Kind) return Float;
   function Temp_Band_Of (Kind : Cargo_Kind) return Temp_Band_C;

   -- M1 last-mile: Cosmetics / Food_Dry only
   function M1_Last_Mile_Ok (Kind : Cargo_Kind) return Boolean;

   -- Rejects: cold on Flatbed; Extreme hazard on M1 Car_*
   function Vehicle_Cargo_Ok
     (Phys   : Vehicle_Physical;
      Kind   : Cargo_Kind;
      Equip  : Body_Kind;
      Hazard : Hazard_Class := None) return Boolean;

   -- Air/Space_Haul: deny Explosives and Radioactive by default
   function Mode_Allows_Hazard
     (Mode : Dispatch_Mode; Hazard : Hazard_Class) return Boolean;

   -- Road: Gases and Flammable_Liquids need Tank body
   function Requires_Tank_Body (Hazard : Hazard_Class) return Boolean;

   type City_Record is record
      Has_Rail               : Boolean := True;
      Has_Airport            : Boolean := False;
      Has_Port               : Boolean := False;
      Has_Spaceport          : Boolean := False;
      Has_Tunnel             : Boolean := False;
      Tunnel_Fire_Vent_Risk  : Boolean := False;  -- lean flag
      Bound_Pad              : Spaceport_Id := 1;
      Has_Pad_Link           : Boolean := False;
      Position               : Position_m := Terra_Origin;  -- local / hub SI
   end record;

   type Staff_Role is (Dispatcher, Driver, Mechanic, Clerk, Manager);
   type Order_Status is
     (Pending, Accepted, In_Transit, En_Route, Delivered, Cancelled,
      Rejected_ATC);
   type Offer_Status is (Open, Accepted_Offer, Declined, Expired);

   type Vehicle_Record is record
      Kind                 : Vehicle_Kind := Light_Van;
      Attached_Body        : Body_Kind := Flatbed;
      Has_Body             : Boolean := True;
      Capacity_FE          : Freight_Units := 0;
      Condition            : Natural := 100;
      Available            : Boolean := True;
      Needs_Maintain       : Boolean := False;
      Vehicle_ADR_Approved : Boolean := False;
      Phys                 : Vehicle_Physical := Van_N1;
   end record;

   type Order_Record is record
      Origin            : City_Id := 1;
      Destination       : City_Id := 1;
      Cargo             : Cargo_Class := Flatbed_Cargo;
      Kind              : Cargo_Kind := Food_Dry;
      Has_Kind          : Boolean := False;
      Hazard            : Hazard_Class := None;
      Placard           : Placard_Code := Empty_Placard;
      Amount_FE         : Freight_Units := 0;
      Payment           : Money := 0.0;
      Status            : Order_Status := Pending;
      Mode              : Dispatch_Mode := Road;
      Assigned_Vehicle  : Vehicle_Id := 1;
      Distance_m        : Float := 0.0;
      ETA_s             : Float := 0.0;
      Elapsed_s         : Float := 0.0;
      Assign_Wall_Time  : Ada.Calendar.Time :=
        Ada.Calendar.Time_Of (1901, 1, 1);
   end record;

   type Staff_Record is record
      Role                : Staff_Role := Clerk;
      Salary              : Money := 0.0;
      Active              : Boolean := True;
      Driver_Has_ADR_Cert : Boolean := False;
   end record;

   type Offer_Record is record
      Order  : Order_Id := 1;
      Price  : Money := 0.0;
      Status : Offer_Status := Open;
   end record;

   type Rail_Slot_Record is record
      Origin      : City_Id := 1;
      Destination : City_Id := 1;
      Reserved    : Boolean := False;
   end record;

   Max_Vehicles   : constant := 64;
   Max_Orders     : constant := 128;
   Max_Staff      : constant := 64;
   Max_Offers     : constant := 64;
   Max_Cities     : constant := 32;
   Max_Rail_Slots : constant := 64;

   type Company is private;

   function Create_Company
     (Starting_Cash : Money;
      Starting_Rep  : Reputation_Points := 0) return Company;

   function Cash (C : Company) return Money;
   function Reputation (C : Company) return Reputation_Points;
   function Vehicle_Count (C : Company) return Natural;
   function Order_Count (C : Company) return Natural;
   function Staff_Count (C : Company) return Natural;
   function Offer_Count (C : Company) return Natural;
   function City_Count (C : Company) return Natural;
   function Spaceport_Count (C : Company) return Natural;

   procedure Add_City
     (C                      : in out Company;
      Name                   : String;
      Has_Airport            : Boolean;
      Has_Port               : Boolean;
      Has_Spaceport          : Boolean := False;
      Has_Tunnel             : Boolean := False;
      Tunnel_Fire_Vent_Risk  : Boolean := False;
      Position               : Position_m := Terra_Origin;
      Id                     : out City_Id);

   function City_Distance_m
     (C : Company; A, B : City_Id) return Float
   with
     Post => City_Distance_m'Result >= 0.0;

   function Get_City (C : Company; Id : City_Id) return City_Record;
   function City_Name (C : Company; Id : City_Id) return String;

   -- Catalog entry; many IDs may share the same World_Body profile (Mars/Titan)
   procedure Add_Spaceport
     (C            : in out Company;
      Name         : String;
      World        : World_Body;
      Pad_Limit_kg : Mass_Kilograms := Default_Pad_Limit_kg;
      Id           : out Spaceport_Id;
      Success      : out Boolean);

   function Get_Spaceport
     (C : Company; Id : Spaceport_Id) return Spaceport_Record;

   function Spaceport_Name (C : Company; Id : Spaceport_Id) return String;

   function Spaceport_Profile
     (C : Company; Id : Spaceport_Id) return World_Body_Profile;

   -- Bind city ↔ pad; sets Has_Spaceport. Space_Haul blocked while Cracked.
   procedure Bind_City_Pad
     (C       : in out Company;
      City    : City_Id;
      Pad     : Spaceport_Id;
      Success : out Boolean);

   function Pad_Open (C : Company; Pad : Spaceport_Id) return Boolean;
   -- True if pad exists and Status = Ok (not Cracked / unrepaired).

   function City_Pad_Open (C : Company; City : City_Id) return Boolean;
   -- Has_Spaceport and (no pad link or Pad_Open). Legacy cities without
   -- a bound pad stay open when Has_Spaceport.

   -- Event: if Landing_Mass_kg (Mass/GVW) > Pad_Limit_kg → Cracked;
   -- blocks Space_Haul to/from pad until Reconcrete_Hours elapse (Tick).
   -- Optional short English Story stored on the pad.
   procedure Pad_Reconcrete
     (C                : in out Company;
      Pad              : Spaceport_Id;
      Landing_Mass_kg  : Mass_Kilograms;
      Cracked_Out      : out Boolean;
      Reconcrete_Hours : Float := Default_Reconcrete_Hours;
      Story            : String := "");

   function Pad_Story (C : Company; Pad : Spaceport_Id) return String;

   procedure Add_Vehicle
     (C            : in out Company;
      Kind         : Vehicle_Kind;
      Equip        : Body_Kind;
      Has_Body     : Boolean;
      Capacity_FE  : Freight_Units;
      Cost         : Money;
      Id           : out Vehicle_Id;
      Success      : out Boolean;
      ADR_Approved : Boolean := False;
      Phys         : Vehicle_Physical :=
        (Curb_Mass => 0,
         GVW       => 0,
         Length_m  => 0.0,
         Width_m   => 0.0,
         EU_Class  => N1,
         M1_Size   => Car_Medium));
   -- When Phys.GVW = 0, Default_Physical (Kind) is applied.
   -- When Phys.GVW > 0, requires Masses_Valid; class limits enforced.

   function Get_Vehicle (C : Company; Id : Vehicle_Id) return Vehicle_Record;

   procedure Attach_Body
     (C           : in out Company;
      Id          : Vehicle_Id;
      Equip       : Body_Kind;
      Capacity_FE : Freight_Units;
      Success     : out Boolean);

   procedure Detach_Body
     (C       : in out Company;
      Id      : Vehicle_Id;
      Success : out Boolean);

   procedure Maintain_Vehicle
     (C       : in out Company;
      Id      : Vehicle_Id;
      Cost    : Money;
      Success : out Boolean);

   procedure Hire_Staff
     (C             : in out Company;
      Role          : Staff_Role;
      Salary        : Money;
      Id            : out Staff_Id;
      Success       : out Boolean;
      ADR_Certified : Boolean := False);

   function Get_Staff (C : Company; Id : Staff_Id) return Staff_Record;

   procedure Create_Order
     (C           : in out Company;
      Origin      : City_Id;
      Destination : City_Id;
      Cargo       : Cargo_Class;
      Amount_FE   : Freight_Units;
      Payment     : Money;
      Id          : out Order_Id;
      Success     : out Boolean;
      Hazard      : Hazard_Class := None;
      Placard     : Placard_Code := Empty_Placard);

   -- Product-kind order: sets Has_Kind and maps Kind → Cargo_Class
   procedure Create_Order
     (C           : in out Company;
      Origin      : City_Id;
      Destination : City_Id;
      Kind        : Cargo_Kind;
      Amount_FE   : Freight_Units;
      Payment     : Money;
      Id          : out Order_Id;
      Success     : out Boolean;
      Hazard      : Hazard_Class := None;
      Placard     : Placard_Code := Empty_Placard);

   function Get_Order (C : Company; Id : Order_Id) return Order_Record;

   procedure Make_Offer
     (C       : in out Company;
      Order   : Order_Id;
      Price   : Money;
      Id      : out Offer_Id;
      Success : out Boolean);

   function Get_Offer (C : Company; Id : Offer_Id) return Offer_Record;

   procedure Accept_Offer
     (C       : in out Company;
      Id      : Offer_Id;
      Success : out Boolean);

   procedure Reserve_Rail_Slot
     (C           : in out Company;
      Origin      : City_Id;
      Destination : City_Id;
      Slot        : out Rail_Slot_Id;
      Success     : out Boolean);

   function Rail_Slot_Reserved
     (C : Company; Origin, Destination : City_Id) return Boolean;

   -- Road anytime (body/FE/ADR rules). Rail needs slot stub.
   -- Air: both Has_Airport. Sea: both Has_Port.
   -- Space_Haul ≅ Air: both Has_Spaceport; Container cargo only (Step-1).
   -- Tunnel: both Has_Tunnel; same EU road fleet rules; fire/vent lean.
   procedure Dispatch_Order
     (C       : in out Company;
      Order   : Order_Id;
      Mode    : Dispatch_Mode;
      Vehicle : Vehicle_Id := 1;
      Success : out Boolean);

   procedure Complete_Delivery
     (C       : in out Company;
      Order   : Order_Id;
      Success : out Boolean);


   ------------------------------------------------------------------
   -- MVP play: haul speeds, ETA, assign → En_Route, tick → Delivered
   ------------------------------------------------------------------
   Speed_Road_m_s       : constant Float := 22.0;
   Speed_Tunnel_m_s     : constant Float := 30.0;
   Speed_Space_Haul_m_s : constant Float := 3_000.0;

   function Speed_Of (Mode : Haul_Mode) return Float
   with
     Post =>
       (case Mode is
          when Road       => Speed_Of'Result = Speed_Road_m_s,
          when Tunnel     => Speed_Of'Result = Speed_Tunnel_m_s,
          when Space_Haul => Speed_Of'Result = Speed_Space_Haul_m_s);

   -- ETA_s = Distance_m / Speed_m_s
   function Compute_ETA_s
     (Distance_m : Float; Mode : Haul_Mode) return Float
   with
     Pre  => Distance_m >= 0.0,
     Post => Compute_ETA_s'Result = Distance_m / Speed_Of (Mode);

   procedure Set_Time_Rate (C : in out Company; Rate : Float)
   with
     Pre => Rate > 0.0;

   function Time_Rate_Of (C : Company) return Float;

   -- Pending/Accepted → En_Route; records Assign_Wall_Time + ETA_s
   procedure Assign_Vehicle
     (C          : in out Company;
      Order      : Order_Id;
      Vehicle    : Vehicle_Id;
      Distance_m : Float;
      Mode       : Haul_Mode := Road;
      Success    : out Boolean;
      Now        : Ada.Calendar.Time := Ada.Calendar.Clock)
   with
     Pre => Distance_m >= 0.0;

   -- ATC capacity reject: Pending/Accepted → Rejected_ATC (not Fitness)
   procedure Mark_Rejected_ATC (C : in out Company; Order : Order_Id);

   -- Wall Δt * Time_Rate → Elapsed_s; deliver when Elapsed_s >= ETA_s
   procedure Tick
     (C   : in out Company;
      Now : Ada.Calendar.Time := Ada.Calendar.Clock);

   -- Inject wall seconds (tests / demos; no long sleep)
   procedure Tick_Delta
     (C            : in out Company;
      Delta_Wall_s : Float);

   Company_Error : exception;

private

   type Vehicle_Array is array (Vehicle_Id range 1 .. Vehicle_Id (Max_Vehicles))
     of Vehicle_Record;
   type Order_Array is array (Order_Id range 1 .. Order_Id (Max_Orders))
     of Order_Record;
   type Staff_Array is array (Staff_Id range 1 .. Staff_Id (Max_Staff))
     of Staff_Record;
   type Offer_Array is array (Offer_Id range 1 .. Offer_Id (Max_Offers))
     of Offer_Record;
   type City_Array is array (City_Id range 1 .. City_Id (Max_Cities))
     of City_Record;
   type Rail_Slot_Array is array
     (Rail_Slot_Id range 1 .. Rail_Slot_Id (Max_Rail_Slots))
     of Rail_Slot_Record;
   type Spaceport_Array is array
     (Spaceport_Id range 1 .. Spaceport_Id (Max_Spaceports))
     of Spaceport_Record;

   subtype Loc_Name is String (1 .. 32);
   type City_Names is array (City_Id range 1 .. City_Id (Max_Cities)) of Loc_Name;
   type City_Name_Lens is array (City_Id range 1 .. City_Id (Max_Cities))
     of Natural;
   type Spaceport_Names is array
     (Spaceport_Id range 1 .. Spaceport_Id (Max_Spaceports)) of Loc_Name;
   type Spaceport_Name_Lens is array
     (Spaceport_Id range 1 .. Spaceport_Id (Max_Spaceports)) of Natural;

   type Company is record
      Cash_Balance   : Money := 0.0;
      Rep            : Reputation_Points := 0;
      Vehicles       : Vehicle_Array;
      V_Count        : Natural := 0;
      Orders         : Order_Array;
      O_Count        : Natural := 0;
      Staff_Members  : Staff_Array;
      S_Count        : Natural := 0;
      Offers         : Offer_Array;
      Off_Count      : Natural := 0;
      Cities         : City_Array;
      City_Names_A   : City_Names := [others => [others => ' ']];
      City_Lens      : City_Name_Lens := [others => 0];
      L_Count        : Natural := 0;
      Spaceports     : Spaceport_Array;
      Sp_Names       : Spaceport_Names := [others => [others => ' ']];
      Sp_Lens        : Spaceport_Name_Lens := [others => 0];
      Sp_Count       : Natural := 0;
      Rail_Slots     : Rail_Slot_Array;
      R_Count        : Natural := 0;
      Time_Rate      : Float := 1.0;
      Last_Tick_Wall : Ada.Calendar.Time :=
        Ada.Calendar.Time_Of (1901, 1, 1);
      Has_Last_Tick  : Boolean := False;
   end record;

end Logistics_Module;
