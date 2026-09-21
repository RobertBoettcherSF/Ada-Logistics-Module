--  Thin educational hub warehouse and multi-SKU stock.
--  Mass values are SI kilograms; this is not an inventory/ERP model.

pragma Ada_2022;

with Logistics_Module;

package Logistics_Module.Warehouses is

   Max_Warehouses     : constant := 16;
   Max_Warehouse_Slots : constant := 16;

   type Warehouse_Id is range 1 .. Max_Warehouses;
   subtype Mass_kg is Float range 0.0 .. 1.0E9;

   type Warehouse_Location is record
      World     : World_Body := Terra_0;
      City      : City_Id := City_Id'First;
      Spaceport : Spaceport_Id := Spaceport_Id'First;
   end record;

   type Warehouse_Registry is private;
   subtype Warehouse_Store is Warehouse_Registry;

   function Create_Registry return Warehouse_Registry;
   function Create_Warehouse_Store return Warehouse_Registry
     renames Create_Registry;

   -- Registry-backed API: creation is bounded at Max_Warehouses.
   procedure Create_Warehouse
     (Registry   : in out Warehouse_Registry;
      Location   : Warehouse_Location;
      Capacity   : Mass_kg;
      Id         : out Warehouse_Id;
      Success    : out Boolean);

   procedure Create_Warehouse
     (Registry   : in out Warehouse_Registry;
      World      : World_Body;
      Capacity   : Mass_kg;
      Id         : out Warehouse_Id;
      Success    : out Boolean);

   procedure Create_Warehouse
     (Registry   : in out Warehouse_Registry;
      City       : City_Id;
      Capacity   : Mass_kg;
      Id         : out Warehouse_Id;
      Success    : out Boolean);

   procedure Deposit
     (Registry    : in out Warehouse_Registry;
      Id          : Warehouse_Id;
      Cargo       : Cargo_Class;
      Mass        : Mass_kg;
      Success     : out Boolean;
      Hold_Temp_C : Float := 0.0);

   procedure Withdraw
     (Registry    : in out Warehouse_Registry;
      Id          : Warehouse_Id;
      Cargo       : Cargo_Class;
      Mass        : Mass_kg;
      Success     : out Boolean);

   function Stock_Of
     (Registry : Warehouse_Registry;
      Id       : Warehouse_Id;
      Cargo    : Cargo_Class) return Mass_kg;

   function Stock_Of
     (Registry : Warehouse_Registry;
      Id       : Warehouse_Id) return Mass_kg;

   function Capacity_kg
     (Registry : Warehouse_Registry;
      Id       : Warehouse_Id) return Mass_kg;

   function Remaining_Capacity_kg
     (Registry : Warehouse_Registry;
      Id       : Warehouse_Id) return Mass_kg;

   function Location_Of
     (Registry : Warehouse_Registry;
      Id       : Warehouse_Id) return Warehouse_Location;

   -- Convenience overloads for the existing Body_Kind / Cargo_Kind vocabulary.
   procedure Deposit
     (Registry    : in out Warehouse_Registry;
      Id          : Warehouse_Id;
      Cargo       : Body_Kind;
      Mass        : Mass_kg;
      Success     : out Boolean;
      Hold_Temp_C : Float := 0.0);

   procedure Deposit
     (Registry    : in out Warehouse_Registry;
      Id          : Warehouse_Id;
      Cargo       : Cargo_Kind;
      Mass        : Mass_kg;
      Success     : out Boolean;
      Hold_Temp_C : Float := 0.0);

   function Stock_Of
     (Registry : Warehouse_Registry;
      Id       : Warehouse_Id;
      Cargo    : Body_Kind) return Mass_kg;

   function Stock_Of
     (Registry : Warehouse_Registry;
      Id       : Warehouse_Id;
      Cargo    : Cargo_Kind) return Mass_kg;

   -- A small process-local default registry makes the four operations easy
   -- to demonstrate without a larger Company object.
   procedure Reset_Default_Registry;

   procedure Create_Warehouse
     (Location : Warehouse_Location;
      Capacity : Mass_kg;
      Id       : out Warehouse_Id;
      Success  : out Boolean);

   procedure Create_Warehouse
     (World    : World_Body;
      Capacity : Mass_kg;
      Id       : out Warehouse_Id;
      Success  : out Boolean);

   procedure Deposit
     (Id          : Warehouse_Id;
      Cargo       : Cargo_Class;
      Mass        : Mass_kg;
      Success     : out Boolean;
      Hold_Temp_C : Float := 0.0);

   procedure Withdraw
     (Id       : Warehouse_Id;
      Cargo    : Cargo_Class;
      Mass     : Mass_kg;
      Success  : out Boolean);

   function Stock_Of
     (Id    : Warehouse_Id;
      Cargo : Cargo_Class) return Mass_kg;

   function Capacity_kg (Id : Warehouse_Id) return Mass_kg;

private

   type Slot_Id is range 1 .. Max_Warehouse_Slots;

   type Stock_Slot is record
      Cargo       : Cargo_Class := Silo_Cargo;
      Mass        : Mass_kg := 0.0;
      Hold_Temp_C : Float := 0.0;
      Occupied    : Boolean := False;
   end record;

   type Stock_Slots is array (Slot_Id) of Stock_Slot;

   type Warehouse_Record is record
      Id           : Warehouse_Id := Warehouse_Id'First;
      Location     : Warehouse_Location := (others => <>);
      Capacity     : Mass_kg := 0.0;
      Used         : Mass_kg := 0.0;
      Slots        : Stock_Slots := (others => (others => <>));
      Active       : Boolean := False;
   end record;

   type Warehouse_Array is array (Warehouse_Id) of Warehouse_Record;

   type Warehouse_Registry is record
      Warehouses : Warehouse_Array := (others => (others => <>));
      Count      : Natural := 0;
   end record;

end Logistics_Module.Warehouses;
