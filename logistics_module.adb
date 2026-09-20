--  Clean-room Step-1 body. Public logistics-sim genre inspiration only.

pragma Ada_2022;

package body Logistics_Module is

   function Compatible
     (Cargo : Cargo_Class;
      Equip : Body_Kind;
      Mode  : Dispatch_Mode) return Boolean
   is
   begin
      case Cargo is
         when Silo_Cargo =>
            case Mode is
               when Road =>
                  return Equip = Silo;
               when Rail | Sea =>
                  return True;
               when Air | Space =>
                  return False;
            end case;
         when Tank_Cargo =>
            case Mode is
               when Road =>
                  return Equip = Tank;
               when Rail | Sea =>
                  return True;
               when Air | Space =>
                  return False;
            end case;
         when Lowboy_Cargo =>
            case Mode is
               when Road =>
                  return Equip = Lowboy;
               when Rail | Sea =>
                  return True;
               when Air | Space =>
                  return False;
            end case;
         when Reefer_Cargo =>
            return Mode = Road and then Equip = Reefer;
         when Flatbed_Cargo =>
            case Mode is
               when Road =>
                  return Equip = Flatbed;
               when Rail | Air =>
                  return True;
               when Sea | Space =>
                  return False;
            end case;
         when Container_Cargo =>
            case Mode is
               when Road =>
                  return Equip = Container;
               when Rail | Air | Sea | Space =>
                  return True;
            end case;
      end case;
   end Compatible;

   function Van_Can_Carry (Cargo : Cargo_Class) return Boolean is
   begin
      return Cargo = Flatbed_Cargo or else Cargo = Container_Cargo;
   end Van_Can_Carry;

   function Mode_Allows_Hazard
     (Mode : Dispatch_Mode; Hazard : Hazard_Class) return Boolean
   is
   begin
      if Hazard = None then
         return True;
      end if;
      case Mode is
         when Road | Rail | Sea =>
            return True;  -- Step-1: surface modes accept all classes (ops rules apply)
         when Air | Space =>
            -- Allow-list subset: ban Explosives and Radioactive by default
            return Hazard /= Explosives and then Hazard /= Radioactive;
      end case;
   end Mode_Allows_Hazard;

   function Requires_Tank_Body (Hazard : Hazard_Class) return Boolean is
   begin
      return Hazard = Gases or else Hazard = Flammable_Liquids;
   end Requires_Tank_Body;

   function Create_Company
     (Starting_Cash : Money;
      Starting_Rep  : Reputation_Points := 0) return Company
   is
      C : Company;
   begin
      C.Cash_Balance := Starting_Cash;
      C.Rep := Starting_Rep;
      return C;
   end Create_Company;

   function Cash (C : Company) return Money is (C.Cash_Balance);
   function Reputation (C : Company) return Reputation_Points is (C.Rep);
   function Vehicle_Count (C : Company) return Natural is (C.V_Count);
   function Order_Count (C : Company) return Natural is (C.O_Count);
   function Staff_Count (C : Company) return Natural is (C.S_Count);
   function Offer_Count (C : Company) return Natural is (C.Off_Count);
   function City_Count (C : Company) return Natural is (C.L_Count);

   procedure Add_City
     (C             : in out Company;
      Name          : String;
      Has_Airport   : Boolean;
      Has_Port      : Boolean;
      Has_Spaceport : Boolean := False;
      Id            : out City_Id)
   is
      N : Natural;
   begin
      if C.L_Count >= Max_Cities then
         raise Company_Error with "city capacity exceeded";
      end if;
      C.L_Count := C.L_Count + 1;
      Id := City_Id (C.L_Count);
      C.Cities (Id) :=
        (Has_Rail      => True,
         Has_Airport   => Has_Airport,
         Has_Port      => Has_Port,
         Has_Spaceport => Has_Spaceport);
      N := Natural'Min (Name'Length, Loc_Name'Length);
      C.City_Names_A (Id) := [others => ' '];
      C.City_Names_A (Id) (1 .. N) :=
        Name (Name'First .. Name'First + N - 1);
      C.City_Lens (Id) := N;
   end Add_City;

   function Get_City (C : Company; Id : City_Id) return City_Record is
   begin
      if Natural (Id) > C.L_Count then
         raise Company_Error with "invalid city";
      end if;
      return C.Cities (Id);
   end Get_City;

   function City_Name (C : Company; Id : City_Id) return String is
   begin
      if Natural (Id) > C.L_Count then
         raise Company_Error with "invalid city";
      end if;
      return C.City_Names_A (Id) (1 .. C.City_Lens (Id));
   end City_Name;

   procedure Add_Vehicle
     (C            : in out Company;
      Kind         : Vehicle_Kind;
      Equip        : Body_Kind;
      Has_Body     : Boolean;
      Capacity_FE  : Freight_Units;
      Cost         : Money;
      Id           : out Vehicle_Id;
      Success      : out Boolean;
      ADR_Approved : Boolean := False)
   is
      Cap : Freight_Units := Capacity_FE;
      HB  : Boolean := Has_Body;
   begin
      Success := False;
      Id := 1;
      if C.V_Count >= Max_Vehicles then
         return;
      end if;
      if Cost > C.Cash_Balance then
         return;
      end if;
      if Kind = Artic_Tractor and then not HB then
         Cap := 0;
      elsif Kind = Light_Van then
         HB := True;
      end if;
      C.Cash_Balance := C.Cash_Balance - Cost;
      C.V_Count := C.V_Count + 1;
      Id := Vehicle_Id (C.V_Count);
      C.Vehicles (Id) :=
        (Kind                 => Kind,
         Attached_Body        => Equip,
         Has_Body             => HB,
         Capacity_FE          => Cap,
         Condition            => 100,
         Available            => True,
         Needs_Maintain       => False,
         Vehicle_ADR_Approved => ADR_Approved);
      Success := True;
   end Add_Vehicle;

   function Get_Vehicle (C : Company; Id : Vehicle_Id) return Vehicle_Record is
   begin
      if Natural (Id) > C.V_Count then
         raise Company_Error with "invalid vehicle";
      end if;
      return C.Vehicles (Id);
   end Get_Vehicle;

   procedure Attach_Body
     (C           : in out Company;
      Id          : Vehicle_Id;
      Equip       : Body_Kind;
      Capacity_FE : Freight_Units;
      Success     : out Boolean)
   is
   begin
      Success := False;
      if Natural (Id) > C.V_Count then
         return;
      end if;
      if C.Vehicles (Id).Kind /= Artic_Tractor then
         return;
      end if;
      C.Vehicles (Id).Attached_Body := Equip;
      C.Vehicles (Id).Has_Body := True;
      C.Vehicles (Id).Capacity_FE := Capacity_FE;
      Success := True;
   end Attach_Body;

   procedure Detach_Body
     (C       : in out Company;
      Id      : Vehicle_Id;
      Success : out Boolean)
   is
   begin
      Success := False;
      if Natural (Id) > C.V_Count then
         return;
      end if;
      if C.Vehicles (Id).Kind /= Artic_Tractor then
         return;
      end if;
      C.Vehicles (Id).Has_Body := False;
      C.Vehicles (Id).Capacity_FE := 0;
      Success := True;
   end Detach_Body;

   procedure Maintain_Vehicle
     (C       : in out Company;
      Id      : Vehicle_Id;
      Cost    : Money;
      Success : out Boolean)
   is
   begin
      Success := False;
      if Natural (Id) > C.V_Count then
         return;
      end if;
      if Cost > C.Cash_Balance then
         return;
      end if;
      C.Cash_Balance := C.Cash_Balance - Cost;
      C.Vehicles (Id).Condition := 100;
      C.Vehicles (Id).Needs_Maintain := False;
      C.Vehicles (Id).Available := True;
      Success := True;
   end Maintain_Vehicle;

   procedure Hire_Staff
     (C             : in out Company;
      Role          : Staff_Role;
      Salary        : Money;
      Id            : out Staff_Id;
      Success       : out Boolean;
      ADR_Certified : Boolean := False)
   is
   begin
      Success := False;
      Id := 1;
      if C.S_Count >= Max_Staff then
         return;
      end if;
      if Salary > C.Cash_Balance then
         return;
      end if;
      C.Cash_Balance := C.Cash_Balance - Salary;
      C.S_Count := C.S_Count + 1;
      Id := Staff_Id (C.S_Count);
      C.Staff_Members (Id) :=
        (Role                => Role,
         Salary              => Salary,
         Active              => True,
         Driver_Has_ADR_Cert =>
           (Role = Driver and then ADR_Certified));
      Success := True;
   end Hire_Staff;

   function Get_Staff (C : Company; Id : Staff_Id) return Staff_Record is
   begin
      if Natural (Id) > C.S_Count then
         raise Company_Error with "invalid staff";
      end if;
      return C.Staff_Members (Id);
   end Get_Staff;

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
      Placard     : Placard_Code := Empty_Placard)
   is
      P : Placard_Code := Placard;
   begin
      Success := False;
      Id := 1;
      if C.O_Count >= Max_Orders then
         return;
      end if;
      if Natural (Origin) > C.L_Count
        or else Natural (Destination) > C.L_Count
      then
         return;
      end if;
      if Hazard = None then
         P := Empty_Placard;
      end if;
      C.O_Count := C.O_Count + 1;
      Id := Order_Id (C.O_Count);
      C.Orders (Id) :=
        (Origin      => Origin,
         Destination => Destination,
         Cargo       => Cargo,
         Hazard      => Hazard,
         Placard     => P,
         Amount_FE   => Amount_FE,
         Payment     => Payment,
         Status      => Pending,
         Mode        => Road);
      Success := True;
   end Create_Order;

   function Get_Order (C : Company; Id : Order_Id) return Order_Record is
   begin
      if Natural (Id) > C.O_Count then
         raise Company_Error with "invalid order";
      end if;
      return C.Orders (Id);
   end Get_Order;

   procedure Make_Offer
     (C       : in out Company;
      Order   : Order_Id;
      Price   : Money;
      Id      : out Offer_Id;
      Success : out Boolean)
   is
   begin
      Success := False;
      Id := 1;
      if C.Off_Count >= Max_Offers then
         return;
      end if;
      if Natural (Order) > C.O_Count then
         return;
      end if;
      if C.Orders (Order).Status /= Pending then
         return;
      end if;
      C.Off_Count := C.Off_Count + 1;
      Id := Offer_Id (C.Off_Count);
      C.Offers (Id) :=
        (Order => Order, Price => Price, Status => Open);
      Success := True;
   end Make_Offer;

   function Get_Offer (C : Company; Id : Offer_Id) return Offer_Record is
   begin
      if Natural (Id) > C.Off_Count then
         raise Company_Error with "invalid offer";
      end if;
      return C.Offers (Id);
   end Get_Offer;

   procedure Accept_Offer
     (C       : in out Company;
      Id      : Offer_Id;
      Success : out Boolean)
   is
      Ord : Order_Id;
   begin
      Success := False;
      if Natural (Id) > C.Off_Count then
         return;
      end if;
      if C.Offers (Id).Status /= Open then
         return;
      end if;
      Ord := C.Offers (Id).Order;
      if C.Orders (Ord).Status /= Pending then
         return;
      end if;
      C.Offers (Id).Status := Accepted_Offer;
      C.Orders (Ord).Status := Accepted;
      C.Orders (Ord).Payment := C.Offers (Id).Price;
      Success := True;
   end Accept_Offer;

   procedure Reserve_Rail_Slot
     (C           : in out Company;
      Origin      : City_Id;
      Destination : City_Id;
      Slot        : out Rail_Slot_Id;
      Success     : out Boolean)
   is
   begin
      Success := False;
      Slot := 1;
      if C.R_Count >= Max_Rail_Slots then
         return;
      end if;
      if Natural (Origin) > C.L_Count
        or else Natural (Destination) > C.L_Count
      then
         return;
      end if;
      C.R_Count := C.R_Count + 1;
      Slot := Rail_Slot_Id (C.R_Count);
      C.Rail_Slots (Slot) :=
        (Origin => Origin, Destination => Destination, Reserved => True);
      Success := True;
   end Reserve_Rail_Slot;

   function Rail_Slot_Reserved
     (C : Company; Origin, Destination : City_Id) return Boolean
   is
   begin
      if C.R_Count = 0 then
         return False;
      end if;
      for I in Rail_Slot_Id range 1 .. Rail_Slot_Id (C.R_Count) loop
         if C.Rail_Slots (I).Reserved
           and then C.Rail_Slots (I).Origin = Origin
           and then C.Rail_Slots (I).Destination = Destination
         then
            return True;
         end if;
      end loop;
      return False;
   end Rail_Slot_Reserved;

   function Has_Dispatcher (C : Company) return Boolean is
   begin
      if C.S_Count = 0 then
         return False;
      end if;
      for I in Staff_Id range 1 .. Staff_Id (C.S_Count) loop
         if C.Staff_Members (I).Active
           and then (C.Staff_Members (I).Role = Dispatcher
                     or else C.Staff_Members (I).Role = Manager)
         then
            return True;
         end if;
      end loop;
      return False;
   end Has_Dispatcher;

   function Has_ADR_Driver (C : Company) return Boolean is
   begin
      if C.S_Count = 0 then
         return False;
      end if;
      for I in Staff_Id range 1 .. Staff_Id (C.S_Count) loop
         if C.Staff_Members (I).Active
           and then C.Staff_Members (I).Role = Driver
           and then C.Staff_Members (I).Driver_Has_ADR_Cert
         then
            return True;
         end if;
      end loop;
      return False;
   end Has_ADR_Driver;

   function Cargo_Allows_Mode (Cargo : Cargo_Class; Mode : Dispatch_Mode)
     return Boolean
   is
   begin
      for B in Body_Kind loop
         if Compatible (Cargo, B, Mode) then
            return True;
         end if;
      end loop;
      return False;
   end Cargo_Allows_Mode;

   function Road_Vehicle_Ok
     (C : Company; V : Vehicle_Record; O : Order_Record) return Boolean
   is
      Equip_Ok : Boolean;
   begin
      if not V.Available or else V.Needs_Maintain or else V.Condition < 20 then
         return False;
      end if;
      if O.Amount_FE > V.Capacity_FE then
         return False;
      end if;

      case V.Kind is
         when Light_Van =>
            Equip_Ok := Van_Can_Carry (O.Cargo);
         when Rigid =>
            Equip_Ok := Compatible (O.Cargo, V.Attached_Body, Road);
         when Artic_Tractor =>
            if not V.Has_Body then
               return False;
            end if;
            Equip_Ok := Compatible (O.Cargo, V.Attached_Body, Road);
      end case;
      if not Equip_Ok then
         return False;
      end if;

      if O.Hazard /= None then
         if not V.Vehicle_ADR_Approved then
            return False;
         end if;
         if not Has_ADR_Driver (C) then
            return False;
         end if;
         if Requires_Tank_Body (O.Hazard) then
            if V.Kind = Light_Van then
               return False;
            end if;
            if not V.Has_Body or else V.Attached_Body /= Tank then
               return False;
            end if;
         end if;
      end if;
      return True;
   end Road_Vehicle_Ok;

   procedure Dispatch_Order
     (C       : in out Company;
      Order   : Order_Id;
      Mode    : Dispatch_Mode;
      Vehicle : Vehicle_Id := 1;
      Success : out Boolean)
   is
      O    : Order_Record;
      Orig : City_Record;
      Dest : City_Record;
      V    : Vehicle_Record;
   begin
      Success := False;
      if Natural (Order) > C.O_Count then
         return;
      end if;
      O := C.Orders (Order);
      if O.Status /= Accepted then
         return;
      end if;
      if not Has_Dispatcher (C) then
         return;
      end if;
      if not Mode_Allows_Hazard (Mode, O.Hazard) then
         return;
      end if;
      Orig := C.Cities (O.Origin);
      Dest := C.Cities (O.Destination);

      case Mode is
         when Road =>
            if Natural (Vehicle) > C.V_Count then
               return;
            end if;
            V := C.Vehicles (Vehicle);
            if not Road_Vehicle_Ok (C, V, O) then
               return;
            end if;
            C.Vehicles (Vehicle).Available := False;
            if C.Vehicles (Vehicle).Condition >= 5 then
               C.Vehicles (Vehicle).Condition :=
                 C.Vehicles (Vehicle).Condition - 5;
            end if;
            if C.Vehicles (Vehicle).Condition < 40 then
               C.Vehicles (Vehicle).Needs_Maintain := True;
            end if;

         when Rail =>
            if not Rail_Slot_Reserved (C, O.Origin, O.Destination) then
               return;
            end if;
            if not Cargo_Allows_Mode (O.Cargo, Rail) then
               return;
            end if;

         when Sea =>
            if not Orig.Has_Port or else not Dest.Has_Port then
               return;
            end if;
            if not Cargo_Allows_Mode (O.Cargo, Sea) then
               return;
            end if;

         when Air =>
            if not Orig.Has_Airport or else not Dest.Has_Airport then
               return;
            end if;
            if not Cargo_Allows_Mode (O.Cargo, Air) then
               return;
            end if;

         when Space =>
            -- Spacecraft ≅ airplane: spaceport gate like airport
            if not Orig.Has_Spaceport or else not Dest.Has_Spaceport then
               return;
            end if;
            if not Cargo_Allows_Mode (O.Cargo, Space) then
               return;
            end if;
      end case;

      C.Orders (Order).Status := In_Transit;
      C.Orders (Order).Mode := Mode;
      Success := True;
   end Dispatch_Order;

   procedure Complete_Delivery
     (C       : in out Company;
      Order   : Order_Id;
      Success : out Boolean)
   is
      O     : Order_Record;
      Bonus : Reputation_Points;
   begin
      Success := False;
      if Natural (Order) > C.O_Count then
         return;
      end if;
      O := C.Orders (Order);
      if O.Status /= In_Transit then
         return;
      end if;
      C.Orders (Order).Status := Delivered;
      C.Cash_Balance := C.Cash_Balance + O.Payment;
      Bonus := 1;
      if C.Rep <= Reputation_Points'Last - Bonus then
         C.Rep := C.Rep + Bonus;
      end if;
      if O.Mode = Road and then C.V_Count > 0 then
         for I in Vehicle_Id range 1 .. Vehicle_Id (C.V_Count) loop
            if not C.Vehicles (I).Available then
               C.Vehicles (I).Available := True;
               exit;
            end if;
         end loop;
      end if;
      Success := True;
   end Complete_Delivery;

end Logistics_Module;
