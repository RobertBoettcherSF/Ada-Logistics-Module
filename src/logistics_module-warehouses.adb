--  Warehouse stock implementation.

pragma Ada_2022;

package body Logistics_Module.Warehouses is

   function Create_Registry return Warehouse_Registry is
      Result : Warehouse_Registry;
   begin
      return Result;
   end Create_Registry;

   Default_Registry : Warehouse_Registry := Create_Registry;

   procedure Create_Warehouse
     (Registry   : in out Warehouse_Registry;
      Location   : Warehouse_Location;
      Capacity   : Mass_kg;
      Id         : out Warehouse_Id;
      Success    : out Boolean)
   is
   begin
      Id := Warehouse_Id'First;
      Success := False;
      if Capacity <= 0.0 or else Registry.Count >= Max_Warehouses then
         return;
      end if;
      Registry.Count := Registry.Count + 1;
      Id := Warehouse_Id (Registry.Count);
      Registry.Warehouses (Id) :=
        (Id       => Id,
         Location => Location,
         Capacity => Capacity,
         Used     => 0.0,
         Slots    => [others => <>],
         Active   => True);
      Success := True;
   end Create_Warehouse;

   procedure Create_Warehouse
     (Registry   : in out Warehouse_Registry;
      World      : World_Body;
      Capacity   : Mass_kg;
      Id         : out Warehouse_Id;
      Success    : out Boolean)
   is
   begin
      Create_Warehouse
        (Registry,
         (World => World, City => City_Id'First,
          Spaceport => Spaceport_Id'First),
         Capacity, Id, Success);
   end Create_Warehouse;

   procedure Create_Warehouse
     (Registry   : in out Warehouse_Registry;
      City       : City_Id;
      Capacity   : Mass_kg;
      Id         : out Warehouse_Id;
      Success    : out Boolean)
   is
   begin
      Create_Warehouse
        (Registry,
         (World => Terra_0, City => City, Spaceport => Spaceport_Id'First),
         Capacity, Id, Success);
   end Create_Warehouse;

   function Find_Slot
     (W : Warehouse_Record; Cargo : Cargo_Class) return Slot_Id
   is
   begin
      for Slot in Slot_Id loop
         if W.Slots (Slot).Occupied and then W.Slots (Slot).Cargo = Cargo then
            return Slot;
         end if;
      end loop;
      return Slot_Id'First;
   end Find_Slot;

   function Find_Free_Slot (W : Warehouse_Record) return Slot_Id is
   begin
      for Slot in Slot_Id loop
         if not W.Slots (Slot).Occupied then
            return Slot;
         end if;
      end loop;
      return Slot_Id'First;
   end Find_Free_Slot;

   procedure Deposit
     (Registry    : in out Warehouse_Registry;
      Id          : Warehouse_Id;
      Cargo       : Cargo_Class;
      Mass        : Mass_kg;
      Success     : out Boolean;
      Hold_Temp_C : Float := 0.0)
   is
      Slot : Slot_Id;
   begin
      Success := False;
      if not Registry.Warehouses (Id).Active or else Mass <= 0.0 then
         return;
      end if;
      if Registry.Warehouses (Id).Used + Mass > Registry.Warehouses (Id).Capacity then
         return;
      end if;
      Slot := Find_Slot (Registry.Warehouses (Id), Cargo);
      if not Registry.Warehouses (Id).Slots (Slot).Occupied then
         Slot := Find_Free_Slot (Registry.Warehouses (Id));
         if Registry.Warehouses (Id).Slots (Slot).Occupied then
            return;
         end if;
         Registry.Warehouses (Id).Slots (Slot).Cargo := Cargo;
         Registry.Warehouses (Id).Slots (Slot).Occupied := True;
      end if;
      Registry.Warehouses (Id).Slots (Slot).Mass :=
        Registry.Warehouses (Id).Slots (Slot).Mass + Mass;
      Registry.Warehouses (Id).Slots (Slot).Hold_Temp_C := Hold_Temp_C;
      Registry.Warehouses (Id).Used := Registry.Warehouses (Id).Used + Mass;
      Success := True;
   end Deposit;

   procedure Withdraw
     (Registry    : in out Warehouse_Registry;
      Id          : Warehouse_Id;
      Cargo       : Cargo_Class;
      Mass        : Mass_kg;
      Success     : out Boolean)
   is
      Slot : constant Slot_Id := Find_Slot (Registry.Warehouses (Id), Cargo);
   begin
      Success := False;
      if not Registry.Warehouses (Id).Active or else Mass <= 0.0
        or else not Registry.Warehouses (Id).Slots (Slot).Occupied
        or else Registry.Warehouses (Id).Slots (Slot).Mass < Mass
      then
         return;
      end if;
      Registry.Warehouses (Id).Slots (Slot).Mass :=
        Registry.Warehouses (Id).Slots (Slot).Mass - Mass;
      Registry.Warehouses (Id).Used := Registry.Warehouses (Id).Used - Mass;
      if Registry.Warehouses (Id).Slots (Slot).Mass = 0.0 then
         Registry.Warehouses (Id).Slots (Slot).Occupied := False;
      end if;
      Success := True;
   end Withdraw;

   function Stock_Of
     (Registry : Warehouse_Registry;
      Id       : Warehouse_Id;
      Cargo    : Cargo_Class) return Mass_kg
   is
      Slot : constant Slot_Id := Find_Slot (Registry.Warehouses (Id), Cargo);
   begin
      if not Registry.Warehouses (Id).Active
        or else not Registry.Warehouses (Id).Slots (Slot).Occupied
      then
         return 0.0;
      end if;
      return Registry.Warehouses (Id).Slots (Slot).Mass;
   end Stock_Of;

   function Stock_Of
     (Registry : Warehouse_Registry;
      Id       : Warehouse_Id) return Mass_kg
   is
   begin
      if Registry.Warehouses (Id).Active then
         return Registry.Warehouses (Id).Used;
      else
         return 0.0;
      end if;
   end Stock_Of;

   function Capacity_kg
     (Registry : Warehouse_Registry;
      Id       : Warehouse_Id) return Mass_kg
   is
   begin
      if Registry.Warehouses (Id).Active then
         return Registry.Warehouses (Id).Capacity;
      else
         return 0.0;
      end if;
   end Capacity_kg;

   function Remaining_Capacity_kg
     (Registry : Warehouse_Registry;
      Id       : Warehouse_Id) return Mass_kg
   is
   begin
      if Registry.Warehouses (Id).Active then
         return Registry.Warehouses (Id).Capacity - Registry.Warehouses (Id).Used;
      else
         return 0.0;
      end if;
   end Remaining_Capacity_kg;

   function Location_Of
     (Registry : Warehouse_Registry;
      Id       : Warehouse_Id) return Warehouse_Location
   is
   begin
      return Registry.Warehouses (Id).Location;
   end Location_Of;

   function To_Class (Kind : Body_Kind) return Cargo_Class is
   begin
      case Kind is
         when Silo      => return Silo_Cargo;
         when Tank      => return Tank_Cargo;
         when Reefer    => return Reefer_Cargo;
         when Flatbed   => return Flatbed_Cargo;
         when Container => return Container_Cargo;
         when Lowboy    => return Lowboy_Cargo;
         when Dry_Box   => return Dry_Box_Cargo;
      end case;
   end To_Class;

   procedure Deposit
     (Registry    : in out Warehouse_Registry;
      Id          : Warehouse_Id;
      Cargo       : Body_Kind;
      Mass        : Mass_kg;
      Success     : out Boolean;
      Hold_Temp_C : Float := 0.0)
   is
   begin
      Deposit (Registry, Id, To_Class (Cargo), Mass, Success, Hold_Temp_C);
   end Deposit;

   procedure Deposit
     (Registry    : in out Warehouse_Registry;
      Id          : Warehouse_Id;
      Cargo       : Cargo_Kind;
      Mass        : Mass_kg;
      Success     : out Boolean;
      Hold_Temp_C : Float := 0.0)
   is
   begin
      Deposit (Registry, Id, To_Cargo_Class (Cargo), Mass, Success, Hold_Temp_C);
   end Deposit;

   function Stock_Of
     (Registry : Warehouse_Registry; Id : Warehouse_Id; Cargo : Body_Kind)
      return Mass_kg
   is
   begin
      return Stock_Of (Registry, Id, To_Class (Cargo));
   end Stock_Of;

   function Stock_Of
     (Registry : Warehouse_Registry; Id : Warehouse_Id; Cargo : Cargo_Kind)
      return Mass_kg
   is
   begin
      return Stock_Of (Registry, Id, To_Cargo_Class (Cargo));
   end Stock_Of;

   procedure Reset_Default_Registry is
   begin
      Default_Registry := Create_Registry;
   end Reset_Default_Registry;

   procedure Create_Warehouse
     (Location : Warehouse_Location; Capacity : Mass_kg;
      Id : out Warehouse_Id; Success : out Boolean)
   is
   begin
      Create_Warehouse (Default_Registry, Location, Capacity, Id, Success);
   end Create_Warehouse;

   procedure Create_Warehouse
     (World : World_Body; Capacity : Mass_kg;
      Id : out Warehouse_Id; Success : out Boolean)
   is
   begin
      Create_Warehouse (Default_Registry, World, Capacity, Id, Success);
   end Create_Warehouse;

   procedure Deposit
     (Id : Warehouse_Id; Cargo : Cargo_Class; Mass : Mass_kg;
      Success : out Boolean; Hold_Temp_C : Float := 0.0)
   is
   begin
      Deposit (Default_Registry, Id, Cargo, Mass, Success, Hold_Temp_C);
   end Deposit;

   procedure Withdraw
     (Id : Warehouse_Id; Cargo : Cargo_Class; Mass : Mass_kg;
      Success : out Boolean)
   is
   begin
      Withdraw (Default_Registry, Id, Cargo, Mass, Success);
   end Withdraw;

   function Stock_Of (Id : Warehouse_Id; Cargo : Cargo_Class) return Mass_kg is
   begin
      return Stock_Of (Default_Registry, Id, Cargo);
   end Stock_Of;

   function Capacity_kg (Id : Warehouse_Id) return Mass_kg is
   begin
      return Capacity_kg (Default_Registry, Id);
   end Capacity_kg;

end Logistics_Module.Warehouses;
