--  Clean-room Ada 2022 logistics / forwarding simulation (Step 1).
--  Inspired by the public logistics-sim genre only.
--  Our types: fleet, bodies, cargo matrix, cities/facilities, FE,
--  ADR-inspired hazard classes (not legal text). No proprietary assets.

pragma Ada_2022;

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
   type Body_Kind is (Silo, Tank, Reefer, Flatbed, Container, Lowboy);

   type Cargo_Class is
     (Silo_Cargo, Tank_Cargo, Lowboy_Cargo, Reefer_Cargo,
      Flatbed_Cargo, Container_Cargo);

   type Dispatch_Mode is (Road, Rail, Sea, Air, Space);

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

   -- Space ≅ Air (facility gate); higher cost/time multipliers
   Space_Cost_Factor : constant := 3;
   Space_Time_Factor : constant := 2;

   -- Cargo/body/mode matrix (see README)
   function Compatible
     (Cargo : Cargo_Class;
      Equip : Body_Kind;
      Mode  : Dispatch_Mode) return Boolean;

   function Van_Can_Carry (Cargo : Cargo_Class) return Boolean;

   -- Air/Space: deny Explosives and Radioactive by default
   function Mode_Allows_Hazard
     (Mode : Dispatch_Mode; Hazard : Hazard_Class) return Boolean;

   -- Road: Gases and Flammable_Liquids need Tank body
   function Requires_Tank_Body (Hazard : Hazard_Class) return Boolean;

   type City_Record is record
      Has_Rail      : Boolean := True;
      Has_Airport   : Boolean := False;
      Has_Port      : Boolean := False;
      Has_Spaceport : Boolean := False;
   end record;

   type Staff_Role is (Dispatcher, Driver, Mechanic, Clerk, Manager);
   type Order_Status is (Pending, Accepted, In_Transit, Delivered, Cancelled);
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
   end record;

   type Order_Record is record
      Origin      : City_Id := 1;
      Destination : City_Id := 1;
      Cargo       : Cargo_Class := Flatbed_Cargo;
      Hazard      : Hazard_Class := None;
      Placard     : Placard_Code := Empty_Placard;
      Amount_FE   : Freight_Units := 0;
      Payment     : Money := 0.0;
      Status      : Order_Status := Pending;
      Mode        : Dispatch_Mode := Road;
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

   procedure Add_City
     (C             : in out Company;
      Name          : String;
      Has_Airport   : Boolean;
      Has_Port      : Boolean;
      Has_Spaceport : Boolean := False;
      Id            : out City_Id);

   function Get_City (C : Company; Id : City_Id) return City_Record;
   function City_Name (C : Company; Id : City_Id) return String;

   procedure Add_Vehicle
     (C            : in out Company;
      Kind         : Vehicle_Kind;
      Equip        : Body_Kind;
      Has_Body     : Boolean;
      Capacity_FE  : Freight_Units;
      Cost         : Money;
      Id           : out Vehicle_Id;
      Success      : out Boolean;
      ADR_Approved : Boolean := False);

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
   -- Space ≅ Air: both Has_Spaceport; Container cargo only (Step-1).
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

   subtype Loc_Name is String (1 .. 32);
   type City_Names is array (City_Id range 1 .. City_Id (Max_Cities)) of Loc_Name;
   type City_Name_Lens is array (City_Id range 1 .. City_Id (Max_Cities))
     of Natural;

   type Company is record
      Cash_Balance  : Money := 0.0;
      Rep           : Reputation_Points := 0;
      Vehicles      : Vehicle_Array;
      V_Count       : Natural := 0;
      Orders        : Order_Array;
      O_Count       : Natural := 0;
      Staff_Members : Staff_Array;
      S_Count       : Natural := 0;
      Offers        : Offer_Array;
      Off_Count     : Natural := 0;
      Cities        : City_Array;
      City_Names_A  : City_Names := [others => [others => ' ']];
      City_Lens     : City_Name_Lens := [others => 0];
      L_Count       : Natural := 0;
      Rail_Slots    : Rail_Slot_Array;
      R_Count       : Natural := 0;
   end record;

end Logistics_Module;
