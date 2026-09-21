--  Clean-room Step-1 body. Public logistics-sim genre inspiration only.

pragma Ada_2022;

with Ada.Numerics.Elementary_Functions;

package body Logistics_Module is

   use type Ada.Calendar.Time;

   function Compatible
     (Cargo  : Cargo_Class;
      Equip  : Body_Kind;
      Mode   : Dispatch_Mode;
      Hazard : Hazard_Class) return Boolean
   is
      Base_Compatible : Boolean;
   begin
      --  The matrix remains the first gate.  Hazard handling is a second,
      --  deliberately small educational gate (not ADR/IATA compliance).
      case Cargo is
         when Silo_Cargo =>
            case Mode is
               when Road | Tunnel =>
                  Base_Compatible := Equip = Silo;
               when Rail | Sea =>
                  Base_Compatible := True;
               when Air | Space_Haul =>
                  Base_Compatible := False;
            end case;
         when Tank_Cargo =>
            --  Tank stock exists in every mode in this lean model, but air
            -- and space only accept a non-DG tank product.
            case Mode is
               when Road | Tunnel =>
                  Base_Compatible := Equip = Tank;
               when Rail | Sea =>
                  Base_Compatible := True;
               when Air | Space_Haul =>
                  Base_Compatible := Hazard = None;
            end case;
         when Lowboy_Cargo =>
            case Mode is
               when Road | Tunnel =>
                  Base_Compatible := Equip = Lowboy;
               when Rail | Sea =>
                  Base_Compatible := True;
               when Air | Space_Haul =>
                  Base_Compatible := False;
            end case;
         when Reefer_Cargo =>
            case Mode is
               when Road | Tunnel =>
                  Base_Compatible := Equip = Reefer;
               when Rail | Sea | Air =>
                  Base_Compatible := True;
               when Space_Haul =>
                  Base_Compatible := False;
            end case;
         when Flatbed_Cargo =>
            case Mode is
               when Road | Tunnel =>
                  Base_Compatible := Equip = Flatbed;
               when Rail | Sea | Air =>
                  Base_Compatible := True;
               when Space_Haul =>
                  Base_Compatible := False;
            end case;
         when Container_Cargo =>
            case Mode is
               when Road | Tunnel =>
                  Base_Compatible := Equip = Container;
               when Rail | Air | Sea | Space_Haul =>
                  Base_Compatible := True;
            end case;
         when Dry_Box_Cargo =>
            case Mode is
               when Road | Tunnel =>
                  Base_Compatible := Equip = Dry_Box;
               when Rail | Air | Sea =>
                  Base_Compatible := True;
               when Space_Haul =>
                  Base_Compatible := False;
            end case;
      end case;

      return Base_Compatible and then Mode_Allows_Hazard (Mode, Hazard);
   end Compatible;

   function Compatible
     (Cargo : Cargo_Class;
      Equip : Body_Kind;
      Mode  : Dispatch_Mode) return Boolean
   is
   begin
      return Compatible (Cargo, Equip, Mode, Hazard => None);
   end Compatible;

   function Van_Can_Carry (Cargo : Cargo_Class) return Boolean is
   begin
      return Cargo = Flatbed_Cargo
        or else Cargo = Container_Cargo
        or else Cargo = Dry_Box_Cargo;
   end Van_Can_Carry;

   function To_Cargo_Class (Kind : Cargo_Kind) return Cargo_Class is
   begin
      case Kind is
         when Food_Dry =>
            return Dry_Box_Cargo;
         when Food_Cold | Pharma_Cold =>
            return Reefer_Cargo;
         when Cosmetics =>
            return Dry_Box_Cargo;
      end case;
   end To_Cargo_Class;

   function Primary_Body (Kind : Cargo_Kind) return Body_Kind is
   begin
      case Kind is
         when Food_Dry | Cosmetics =>
            return Dry_Box;
         when Food_Cold | Pharma_Cold =>
            return Reefer;
      end case;
   end Primary_Body;

   function Allows_Body (Kind : Cargo_Kind; Equip : Body_Kind) return Boolean is
   begin
      case Kind is
         when Food_Dry =>
            return Equip = Dry_Box or else Equip = Container;
         when Cosmetics =>
            return Equip = Dry_Box;
         when Food_Cold | Pharma_Cold =>
            return Equip = Reefer;
      end case;
   end Allows_Body;

   function Default_Hazard_Band (Kind : Cargo_Kind) return Hazard_Premium_Band is
   begin
      case Kind is
         when Food_Dry =>
            return None;  -- also allows Low via Hazard_Band_Allowed
         when Food_Cold | Cosmetics =>
            return Low;
         when Pharma_Cold =>
            return Mid;
      end case;
   end Default_Hazard_Band;

   function Hazard_Band_Allowed
     (Kind : Cargo_Kind; Band : Hazard_Premium_Band) return Boolean
   is
   begin
      case Kind is
         when Food_Dry =>
            return Band in None | Low;
         when Food_Cold | Cosmetics =>
            return Band = Low;
         when Pharma_Cold =>
            return Band = Mid;
      end case;
   end Hazard_Band_Allowed;

   function Density_kg_m3_Of (Kind : Cargo_Kind) return Float is
   begin
      case Kind is
         when Food_Dry =>
            return Density_Food_Dry_kg_m3;
         when Cosmetics =>
            return Density_Cosmetics_kg_m3;
         when Food_Cold | Pharma_Cold =>
            return 0.0;  -- reefer lean; density not primary DS
      end case;
   end Density_kg_m3_Of;

   function Temp_Band_Of (Kind : Cargo_Kind) return Temp_Band_C is
   begin
      case Kind is
         when Food_Cold =>
            return Food_Cold_Temp;
         when Pharma_Cold =>
            return Pharma_Cold_Temp;
         when Food_Dry | Cosmetics =>
            return (Lo_C => 0.0, Hi_C => 0.0, Controlled => False);
      end case;
   end Temp_Band_Of;

   function M1_Last_Mile_Ok (Kind : Cargo_Kind) return Boolean is
   begin
      return Kind = Food_Dry or else Kind = Cosmetics;
   end M1_Last_Mile_Ok;

   function Compatible
     (Kind   : Cargo_Kind;
      Equip  : Body_Kind;
      Mode   : Dispatch_Mode;
      Hazard : Hazard_Class) return Boolean
   is
   begin
      if not Allows_Body (Kind, Equip) then
         return False;
      end if;
      -- Food_Dry may ride Container (class rules) or Dry_Box.
      if Kind = Food_Dry and then Equip = Container then
         return Compatible (Container_Cargo, Container, Mode, Hazard);
      end if;
      return Compatible (To_Cargo_Class (Kind), Equip, Mode, Hazard);
   end Compatible;

   function Compatible
     (Kind  : Cargo_Kind;
      Equip : Body_Kind;
      Mode  : Dispatch_Mode) return Boolean
   is
   begin
      return Compatible (Kind, Equip, Mode, Hazard => None);
   end Compatible;

   function Vehicle_Cargo_Ok
     (Phys   : Vehicle_Physical;
      Kind   : Cargo_Kind;
      Equip  : Body_Kind;
      Hazard : Hazard_Class := None) return Boolean
   is
      Band : constant Hazard_Premium_Band := Band_Of (Hazard);
   begin
      -- Reject cold cargo on Flatbed (and any non-allowed body)
      if not Allows_Body (Kind, Equip) then
         return False;
      end if;

      if Phys.EU_Class = M1 then
         -- Extreme hazard banned on M1 Car_*
         if Band = Extreme then
            return False;
         end if;
         if not M1_Last_Mile_Ok (Kind) then
            return False;
         end if;
         return True;
      end if;

      -- N1 van / N2-N3 bulk: body must match; hazard band advisory for kind
      return True;
   end Vehicle_Cargo_Ok;

   function Mode_Allows_Hazard
     (Mode : Dispatch_Mode; Hazard : Hazard_Class) return Boolean
   is
   begin
      if Hazard = None then
         return True;
      end if;
      case Mode is
         when Road | Rail | Sea | Tunnel =>
            return True;  -- surface / tunnel: all classes (ops rules apply)
         when Air | Space_Haul =>
            -- Allow-list subset: ban Explosives and Radioactive by default
            return Hazard /= Explosives and then Hazard /= Radioactive;
      end case;
   end Mode_Allows_Hazard;

   function Requires_Tank_Body (Hazard : Hazard_Class) return Boolean is
   begin
      return Hazard = Gases or else Hazard = Flammable_Liquids;
   end Requires_Tank_Body;

   function Profile_M1 (Size : EU_Class_M1) return Vehicle_Physical is
   begin
      case Size is
         when Car_Small  => return M1_Car_Small;
         when Car_Medium => return M1_Car_Medium;
         when Car_Large  => return M1_Car_Large;
      end case;
   end Profile_M1;

   function Footprint_Area_M2
     (Length : Footprint_Length_m;
      Width  : Footprint_Width_m) return Float
   is
   begin
      return Float (Length) * Float (Width);
   end Footprint_Area_M2;

   function Masses_Valid
     (Curb : Mass_Kilograms; GVW : GVW_Kilograms) return Boolean
   is
   begin
      return GVW >= GVW_Kilograms (Curb);
   end Masses_Valid;

   function Class_GVW_Limit (Class : EU_Vehicle_Class) return GVW_Kilograms is
   begin
      case Class is
         when N1 =>
            return N1_GVW_Max;
         when N2 =>
            return N2_GVW_Max;
         when N3 =>
            return N3_GVW_Check_Cap;
         when O2 =>
            return O2_GVW_Stub_Max;
         when O4 =>
            return O4_GVW_Stub_Max;
         when M1 =>
            -- No N-style goods band; caller uses M1 size-tag GVW
            return 0;
         when M2 | M3 | O1 | O3 =>
            return 0;  -- stubs
      end case;
   end Class_GVW_Limit;

   function Within_GVW_Class_Limit
     (Class : EU_Vehicle_Class; GVW : GVW_Kilograms) return Boolean
   is
      Limit : constant GVW_Kilograms := Class_GVW_Limit (Class);
   begin
      case Class is
         when M1 =>
            -- Passenger: accept if matches a size-tag profile GVW band
            return GVW <= M1_Car_Large.GVW;
         when M2 | M3 | O1 | O3 =>
            return True;  -- stub: no enforced band yet
         when N1 | N2 | N3 | O2 | O4 =>
            return GVW <= Limit;
      end case;
   end Within_GVW_Class_Limit;

   function Map_Kind_To_EU_Class
     (Kind : Vehicle_Kind; GVW : GVW_Kilograms) return EU_Vehicle_Class
   is
   begin
      case Kind is
         when Light_Van =>
            return N1;
         when Rigid =>
            if GVW <= N2_GVW_Max then
               return N2;
            else
               return N3;
            end if;
         when Artic_Tractor =>
            return N3;
      end case;
   end Map_Kind_To_EU_Class;

   function Map_Trailer_To_EU_Class
     (GVW : GVW_Kilograms) return EU_Vehicle_Class
   is
   begin
      if GVW <= O2_GVW_Stub_Max then
         return O2;
      else
         return O4;
      end if;
   end Map_Trailer_To_EU_Class;

   function Default_Physical (Kind : Vehicle_Kind) return Vehicle_Physical is
      P : Vehicle_Physical;
   begin
      case Kind is
         when Light_Van =>
            P := Van_N1;
         when Rigid =>
            P := Lorry_Rigid;
            P.EU_Class := Map_Kind_To_EU_Class (Rigid, P.GVW);
         when Artic_Tractor =>
            P := Lorry_Artic;
      end case;
      return P;
   end Default_Physical;

   function Make_Physical
     (Curb    : Mass_Kilograms;
      GVW     : GVW_Kilograms;
      Length  : Footprint_Length_m;
      Width   : Footprint_Width_m;
      Class   : EU_Vehicle_Class;
      M1_Size : EU_Class_M1 := Car_Medium) return Vehicle_Physical
   is
   begin
      return
        (Curb_Mass => Curb,
         GVW       => GVW,
         Length_m  => Length,
         Width_m   => Width,
         EU_Class  => Class,
         M1_Size   => M1_Size);
   end Make_Physical;

   function Ambient_For (Mode : Haul_Mode) return Ambient_Lean is
   begin
      case Mode is
         when Road       => return Ambient_Road;
         when Tunnel     => return Ambient_Tunnel;
         when Space_Haul => return Ambient_Space_Haul;
      end case;
   end Ambient_For;

   function To_Haul_Mode (Mode : Dispatch_Mode) return Haul_Mode is
   begin
      case Mode is
         when Road =>
            return Haul_Mode'(Road);
         when Tunnel =>
            return Haul_Mode'(Tunnel);
         when Space_Haul =>
            return Haul_Mode'(Space_Haul);
         when Rail | Sea | Air =>
            raise Program_Error with "Dispatch_Mode is not a Haul_Mode";
      end case;
   end To_Haul_Mode;

   function Band_Of (Hazard : Hazard_Class) return Hazard_Premium_Band is
   begin
      case Hazard is
         when None =>
            return Hazard_Premium_Band'(None);
         when Misc_Dangerous =>
            return Low;
         when Flammable_Liquids | Flammable_Solids | Oxidizers =>
            return Mid;
         when Gases | Toxic_Infectious | Corrosive =>
            return High;
         when Explosives | Radioactive =>
            return Extreme;
      end case;
   end Band_Of;

   function Base_Band_Factor (Band : Hazard_Premium_Band) return Premium_Multiplier is
   begin
      case Band is
         when None    => return 1.0;
         when Low     => return 1.2;
         when Mid     => return 2.0;
         when High    => return 4.0;
         when Extreme => return 10.0;
      end case;
   end Base_Band_Factor;

   function Extreme_Mode_Multiplier (Mode : Haul_Mode) return Premium_Multiplier is
   begin
      case Mode is
         when Road       => return 1.0;
         when Tunnel     => return 1.2;
         when Space_Haul => return 1.5;
      end case;
   end Extreme_Mode_Multiplier;

   function Premium_Factor
     (Hazard : Hazard_Class; Mode : Haul_Mode) return Premium_Multiplier
   is
      Band : constant Hazard_Premium_Band := Band_Of (Hazard);
   begin
      if Band /= Extreme then
         return Base_Band_Factor (Band);
      else
         return Base_Band_Factor (Extreme) * Extreme_Mode_Multiplier (Mode);
      end if;
   end Premium_Factor;

   function Cover_Leg_Factor (Kind : Cover_Kind) return Premium_Multiplier is
   begin
      case Kind is
         when Cargo_Loss      => return 1.0;
         when Hull_Loss       => return 0.6;
         when Crew_Loss       => return 0.8;
         when Crew_Sick       => return 0.25;
         when Emergency_Leave => return 0.10;
      end case;
   end Cover_Leg_Factor;

   function Selected_Cover_Sum
     (Selected : Cover_Selection) return Premium_Multiplier
   is
      Sum : Premium_Multiplier := 0.0;
   begin
      for K in Cover_Kind loop
         if Selected (K) then
            Sum := Sum + Cover_Leg_Factor (K);
         end if;
      end loop;
      return Sum;
   end Selected_Cover_Sum;

   function Total_Premium_Factor
     (Hazard   : Hazard_Class;
      Mode     : Haul_Mode;
      Selected : Cover_Selection) return Premium_Multiplier
   is
   begin
      return Selected_Cover_Sum (Selected) * Premium_Factor (Hazard, Mode);
   end Total_Premium_Factor;

   function Profile_Of (World : World_Body) return World_Body_Profile is
   begin
      case World is
         when Terra_0 =>
            return Profile_Terra_0;
         when Venus_Cloud_Port =>
            return Profile_Venus_Cloud_Port;
         when Moon_Polar =>
            return Profile_Moon_Polar;
         when Mars =>
            return Profile_Mars;
         when Titan =>
            return Profile_Titan;
      end case;
   end Profile_Of;

   function Position_Of (World : World_Body) return Position_m is
   begin
      case World is
         when Terra_0 =>
            return Terra_Origin;
         when Moon_Polar =>
            return (X => Earth_Moon_Distance_m, Y => 0.0, Z => 0.0);
         when Venus_Cloud_Port =>
            return (X => 0.72 * Hub_AU_m, Y => 0.0, Z => 0.0);
         when Mars =>
            return (X => Mars_Offset_m, Y => 0.0, Z => 0.0);
         when Titan =>
            return (X => 9.5 * Hub_AU_m, Y => 0.0, Z => 0.0);
      end case;
   end Position_Of;

   function Lerp (A, B : Position_m; T : Float) return Position_m is
      U : constant Float := Float'Max (0.0, Float'Min (1.0, T));
   begin
      return
        (X => A.X + (B.X - A.X) * U,
         Y => A.Y + (B.Y - A.Y) * U,
         Z => A.Z + (B.Z - A.Z) * U);
   end Lerp;

   function Distance_m (A, B : Position_m) return Float is
      DX : constant Float := A.X - B.X;
      DY : constant Float := A.Y - B.Y;
      DZ : constant Float := A.Z - B.Z;
   begin
      return Ada.Numerics.Elementary_Functions.Sqrt
        (DX * DX + DY * DY + DZ * DZ);
   end Distance_m;

   function Distance_m (A, B : World_Body) return Float is
   begin
      return Distance_m (Position_Of (A), Position_Of (B));
   end Distance_m;

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
   function Spaceport_Count (C : Company) return Natural is (C.Sp_Count);

   procedure Add_City
     (C                      : in out Company;
      Name                   : String;
      Has_Airport            : Boolean;
      Has_Port               : Boolean;
      Has_Spaceport          : Boolean := False;
      Has_Tunnel             : Boolean := False;
      Tunnel_Fire_Vent_Risk  : Boolean := False;
      Position               : Position_m := Terra_Origin;
      Id                     : out City_Id)
   is
      N : Natural;
   begin
      if C.L_Count >= Max_Cities then
         raise Company_Error with "city capacity exceeded";
      end if;
      C.L_Count := C.L_Count + 1;
      Id := City_Id (C.L_Count);
      C.Cities (Id) :=
        (Has_Rail              => True,
         Has_Airport           => Has_Airport,
         Has_Port              => Has_Port,
         Has_Spaceport         => Has_Spaceport,
         Has_Tunnel            => Has_Tunnel,
         Tunnel_Fire_Vent_Risk => Tunnel_Fire_Vent_Risk,
         Bound_Pad             => 1,
         Has_Pad_Link          => False,
         Position              => Position);
      N := Natural'Min (Name'Length, Loc_Name'Length);
      C.City_Names_A (Id) := [others => ' '];
      C.City_Names_A (Id) (1 .. N) :=
        Name (Name'First .. Name'First + N - 1);
      C.City_Lens (Id) := N;
   end Add_City;

   function City_Distance_m
     (C : Company; A, B : City_Id) return Float
   is
   begin
      if Natural (A) > C.L_Count or else Natural (B) > C.L_Count then
         raise Company_Error with "invalid city";
      end if;
      return Distance_m (C.Cities (A).Position, C.Cities (B).Position);
   end City_Distance_m;

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

   procedure Add_Spaceport
     (C            : in out Company;
      Name         : String;
      World        : World_Body;
      Pad_Limit_kg : Mass_Kilograms := Default_Pad_Limit_kg;
      Id           : out Spaceport_Id;
      Success      : out Boolean)
   is
      N : Natural;
   begin
      Success := False;
      Id := 1;
      if C.Sp_Count >= Max_Spaceports then
         return;
      end if;
      C.Sp_Count := C.Sp_Count + 1;
      Id := Spaceport_Id (C.Sp_Count);
      C.Spaceports (Id) :=
        (World             => World,
         Pad_Limit_kg      => Pad_Limit_kg,
         Status            => Ok,
         Repair_Hours_Left => 0.0,
         Last_Story        => Empty_Story,
         Last_Story_Len    => 0);
      N := Natural'Min (Name'Length, Loc_Name'Length);
      C.Sp_Names (Id) := [others => ' '];
      if N > 0 then
         C.Sp_Names (Id) (1 .. N) :=
           Name (Name'First .. Name'First + N - 1);
      end if;
      C.Sp_Lens (Id) := N;
      Success := True;
   end Add_Spaceport;

   function Get_Spaceport
     (C : Company; Id : Spaceport_Id) return Spaceport_Record
   is
   begin
      if Natural (Id) > C.Sp_Count then
         raise Company_Error with "invalid spaceport";
      end if;
      return C.Spaceports (Id);
   end Get_Spaceport;

   function Spaceport_Name (C : Company; Id : Spaceport_Id) return String is
   begin
      if Natural (Id) > C.Sp_Count then
         raise Company_Error with "invalid spaceport";
      end if;
      return C.Sp_Names (Id) (1 .. C.Sp_Lens (Id));
   end Spaceport_Name;

   function Spaceport_Profile
     (C : Company; Id : Spaceport_Id) return World_Body_Profile
   is
   begin
      if Natural (Id) > C.Sp_Count then
         raise Company_Error with "invalid spaceport";
      end if;
      return Profile_Of (C.Spaceports (Id).World);
   end Spaceport_Profile;

   procedure Bind_City_Pad
     (C       : in out Company;
      City    : City_Id;
      Pad     : Spaceport_Id;
      Success : out Boolean)
   is
   begin
      Success := False;
      if Natural (City) > C.L_Count then
         return;
      end if;
      if Natural (Pad) > C.Sp_Count then
         return;
      end if;
      C.Cities (City).Has_Spaceport := True;
      C.Cities (City).Bound_Pad := Pad;
      C.Cities (City).Has_Pad_Link := True;
      Success := True;
   end Bind_City_Pad;

   function Pad_Open (C : Company; Pad : Spaceport_Id) return Boolean is
   begin
      if Natural (Pad) > C.Sp_Count then
         return False;
      end if;
      return C.Spaceports (Pad).Status = Ok;
   end Pad_Open;

   function City_Pad_Open (C : Company; City : City_Id) return Boolean is
      Loc : City_Record;
   begin
      if Natural (City) > C.L_Count then
         return False;
      end if;
      Loc := C.Cities (City);
      if not Loc.Has_Spaceport then
         return False;
      end if;
      if not Loc.Has_Pad_Link then
         return True;  -- legacy Has_Spaceport without bound pad
      end if;
      return Pad_Open (C, Loc.Bound_Pad);
   end City_Pad_Open;

   procedure Pad_Reconcrete
     (C                : in out Company;
      Pad              : Spaceport_Id;
      Landing_Mass_kg  : Mass_Kilograms;
      Cracked_Out      : out Boolean;
      Reconcrete_Hours : Float := Default_Reconcrete_Hours;
      Story            : String := "")
   is
      N : Natural;
   begin
      Cracked_Out := False;
      if Natural (Pad) > C.Sp_Count then
         return;
      end if;
      N := Natural'Min (Story'Length, Story_Text'Length);
      C.Spaceports (Pad).Last_Story := Empty_Story;
      if N > 0 then
         C.Spaceports (Pad).Last_Story (1 .. N) :=
           Story (Story'First .. Story'First + N - 1);
      end if;
      C.Spaceports (Pad).Last_Story_Len := N;

      if Landing_Mass_kg > C.Spaceports (Pad).Pad_Limit_kg then
         C.Spaceports (Pad).Status := Cracked;
         if Reconcrete_Hours > 0.0 then
            C.Spaceports (Pad).Repair_Hours_Left := Reconcrete_Hours;
         else
            C.Spaceports (Pad).Repair_Hours_Left := Default_Reconcrete_Hours;
         end if;
         Cracked_Out := True;
      end if;
   end Pad_Reconcrete;

   function Pad_Story (C : Company; Pad : Spaceport_Id) return String is
   begin
      if Natural (Pad) > C.Sp_Count then
         raise Company_Error with "invalid spaceport";
      end if;
      return C.Spaceports (Pad).Last_Story
        (1 .. C.Spaceports (Pad).Last_Story_Len);
   end Pad_Story;

   procedure Advance_Pad_Repairs (C : in out Company; Sim_Delta_s : Float) is
      Hours : Float;
   begin
      if Sim_Delta_s <= 0.0 or else C.Sp_Count = 0 then
         return;
      end if;
      Hours := Sim_Delta_s / 3600.0;
      for I in Spaceport_Id range 1 .. Spaceport_Id (C.Sp_Count) loop
         if C.Spaceports (I).Status = Cracked then
            if C.Spaceports (I).Repair_Hours_Left > Hours then
               C.Spaceports (I).Repair_Hours_Left :=
                 C.Spaceports (I).Repair_Hours_Left - Hours;
            else
               C.Spaceports (I).Repair_Hours_Left := 0.0;
               C.Spaceports (I).Status := Ok;
            end if;
         end if;
      end loop;
   end Advance_Pad_Repairs;

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
         M1_Size   => Car_Medium))
   is
      Cap  : Freight_Units := Capacity_FE;
      HB   : Boolean := Has_Body;
      P    : Vehicle_Physical := Phys;
      Cls  : EU_Vehicle_Class;
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

      -- Physical_Data defaults when GVW left at 0
      if P.GVW = 0 then
         P := Default_Physical (Kind);
      else
         if not Masses_Valid (P.Curb_Mass, P.GVW) then
            return;
         end if;
         -- Map Kind→EU class unless caller set M1 (passenger) or O* trailer
         if P.EU_Class not in M1 | O1 | O2 | O3 | O4 then
            P.EU_Class := Map_Kind_To_EU_Class (Kind, P.GVW);
         elsif P.EU_Class = M1 then
            null;  -- keep M1 + size tag
         end if;
         if not Within_GVW_Class_Limit (P.EU_Class, P.GVW) then
            return;
         end if;
      end if;

      -- Capacity checks use GVW class limits (goods classes)
      Cls := P.EU_Class;
      if Cls in N1 | N2 | N3 | O2 | O4 then
         if not Within_GVW_Class_Limit (Cls, P.GVW) then
            return;
         end if;
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
         Vehicle_ADR_Approved => ADR_Approved,
         Phys                 => P,
         Position             => Terra_Origin,
         Phase                => Docked,
         Dock_World           => Terra_0,
         Dwell_Remaining_s    => 0.0,
         Route_From           => Terra_Origin,
         Route_To             => Terra_Origin,
         Trip_Elapsed_s       => 0.0,
         Trip_ETA_s           => 0.0,
         Bound_Order          => 1,
         Has_Bound            => False);
      Success := True;
   end Add_Vehicle;

   function Get_Vehicle (C : Company; Id : Vehicle_Id) return Vehicle_Record is
   begin
      if Natural (Id) > C.V_Count then
         raise Company_Error with "invalid vehicle";
      end if;
      return C.Vehicles (Id);
   end Get_Vehicle;

   function Vehicle_Position (C : Company; Id : Vehicle_Id) return Position_m is
   begin
      return Get_Vehicle (C, Id).Position;
   end Vehicle_Position;

   function Vehicle_Phase_Of (C : Company; Id : Vehicle_Id) return Vehicle_Phase is
   begin
      return Get_Vehicle (C, Id).Phase;
   end Vehicle_Phase_Of;

   procedure Set_Default_Turnaround (C : in out Company; Seconds : Float) is
   begin
      C.Turnaround_s := Seconds;
   end Set_Default_Turnaround;

   procedure Force_Dock
     (C        : in out Company;
      Id       : Vehicle_Id;
      World    : World_Body;
      Position : Position_m;
      Dwell_s  : Float := 0.0)
   is
   begin
      if Natural (Id) > C.V_Count then
         return;
      end if;
      C.Vehicles (Id).Position := Position;
      C.Vehicles (Id).Route_From := Position;
      C.Vehicles (Id).Route_To := Position;
      C.Vehicles (Id).Phase := Docked;
      C.Vehicles (Id).Dock_World := World;
      C.Vehicles (Id).Dwell_Remaining_s := Dwell_s;
      C.Vehicles (Id).Trip_Elapsed_s := 0.0;
      C.Vehicles (Id).Trip_ETA_s := 0.0;
      C.Vehicles (Id).Available := Dwell_s <= 0.0;
      C.Vehicles (Id).Has_Bound := False;
   end Force_Dock;

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
         Kind        => Food_Dry,
         Has_Kind    => False,
         Hazard      => Hazard,
         Placard     => P,
         Amount_FE   => Amount_FE,
         Payment     => Payment,
         Status      => Pending,
         Mode        => Road,
         others      => <>);
      Success := True;
   end Create_Order;

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
         Cargo       => To_Cargo_Class (Kind),
         Kind        => Kind,
         Has_Kind    => True,
         Hazard      => Hazard,
         Placard     => P,
         Amount_FE   => Amount_FE,
         Payment     => Payment,
         Status      => Pending,
         Mode        => Road,
         others      => <>);
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

   function Cargo_Allows_Mode
     (Cargo : Cargo_Class; Mode : Dispatch_Mode; Hazard : Hazard_Class)
     return Boolean
   is
   begin
      for B in Body_Kind loop
         if Compatible (Cargo, B, Mode, Hazard) then
            return True;
         end if;
      end loop;
      return False;
   end Cargo_Allows_Mode;

   function Road_Vehicle_Ok
     (C : Company; V : Vehicle_Record; O : Order_Record) return Boolean
   is
      Equip_Ok : Boolean;
      Equip    : Body_Kind;
   begin
      if not V.Available or else V.Needs_Maintain or else V.Condition < 20 then
         return False;
      end if;
      if O.Amount_FE > V.Capacity_FE then
         return False;
      end if;

      Equip := V.Attached_Body;

      -- Product-kind orders: matrix + M1 last-mile / Extreme reject
      if O.Has_Kind then
         if not Vehicle_Cargo_Ok (V.Phys, O.Kind, Equip, O.Hazard) then
            return False;
         end if;
         -- M1 cars are Light_Van + M1 phys; N1 van / N2-N3 still via Kind body
         if V.Phys.EU_Class = M1 then
            null;  -- Vehicle_Cargo_Ok already enforced last-mile
         elsif V.Kind = Light_Van then
            if not Van_Can_Carry (O.Cargo) then
               return False;
            end if;
         elsif V.Kind = Artic_Tractor and then not V.Has_Body then
            return False;
         elsif not Compatible (O.Kind, Equip, Road, O.Hazard) then
            return False;
         end if;
      else
         case V.Kind is
            when Light_Van =>
               -- M1 without Kind: no last-mile goods assign
               if V.Phys.EU_Class = M1 then
                  return False;
               end if;
               Equip_Ok := Van_Can_Carry (O.Cargo);
            when Rigid =>
               Equip_Ok := Compatible (O.Cargo, V.Attached_Body, Road, O.Hazard);
            when Artic_Tractor =>
               if not V.Has_Body then
                  return False;
               end if;
               Equip_Ok := Compatible (O.Cargo, V.Attached_Body, Road, O.Hazard);
         end case;
         if not Equip_Ok then
            return False;
         end if;
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
            if not Cargo_Allows_Mode (O.Cargo, Rail, O.Hazard) then
               return;
            end if;

         when Sea =>
            if not Orig.Has_Port or else not Dest.Has_Port then
               return;
            end if;
            if not Cargo_Allows_Mode (O.Cargo, Sea, O.Hazard) then
               return;
            end if;

         when Air =>
            if not Orig.Has_Airport or else not Dest.Has_Airport then
               return;
            end if;
            if not Cargo_Allows_Mode (O.Cargo, Air, O.Hazard) then
               return;
            end if;

         when Space_Haul =>
            -- Spacecraft ≅ airplane: spaceport gate like airport
            if not Orig.Has_Spaceport or else not Dest.Has_Spaceport then
               return;
            end if;
            -- Bound cracked pads block Space_Haul to/from that pad
            if not City_Pad_Open (C, O.Origin)
              or else not City_Pad_Open (C, O.Destination)
            then
               return;
            end if;
            if not Cargo_Allows_Mode (O.Cargo, Space_Haul, O.Hazard) then
               return;
            end if;

         when Tunnel =>
            -- Underground link: both ends Has_Tunnel; same EU road fleet
            if not Orig.Has_Tunnel or else not Dest.Has_Tunnel then
               return;
            end if;
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
      O           : Order_Record;
      Bonus       : Reputation_Points;
      Was_En_Route : Boolean;
   begin
      Success := False;
      if Natural (Order) > C.O_Count then
         return;
      end if;
      O := C.Orders (Order);
      if O.Status not in In_Transit | En_Route then
         return;
      end if;
      Was_En_Route := O.Status = En_Route;
      C.Orders (Order).Status := Delivered;
      C.Cash_Balance := C.Cash_Balance + O.Payment;
      Bonus := 1;
      if C.Rep <= Reputation_Points'Last - Bonus then
         C.Rep := C.Rep + Bonus;
      end if;
      if Was_En_Route then
         if Natural (O.Assigned_Vehicle) <= C.V_Count then
            --  An assigned vehicle remains unavailable while it is underway
            --  or during its configured turnaround dwell.
            if C.Vehicles (O.Assigned_Vehicle).Has_Bound
              and then C.Vehicles (O.Assigned_Vehicle).Bound_Order = Order
            then
               C.Vehicles (O.Assigned_Vehicle).Available :=
                 C.Vehicles (O.Assigned_Vehicle).Phase = Docked
                   and then C.Vehicles (O.Assigned_Vehicle).Dwell_Remaining_s <= 0.0;
            else
               C.Vehicles (O.Assigned_Vehicle).Available := True;
            end if;
         end if;
      elsif O.Mode in Road | Tunnel and then C.V_Count > 0 then
         for I in Vehicle_Id range 1 .. Vehicle_Id (C.V_Count) loop
            if not C.Vehicles (I).Available then
               C.Vehicles (I).Available := True;
               exit;
            end if;
         end loop;
      end if;
      Success := True;
   end Complete_Delivery;

   function Speed_Of (Mode : Haul_Mode) return Float is
   begin
      case Mode is
         when Road =>
            return Speed_Road_m_s;
         when Tunnel =>
            return Speed_Tunnel_m_s;
         when Space_Haul =>
            return Speed_Space_Haul_m_s;
      end case;
   end Speed_Of;

   function Compute_ETA_s
     (Distance_m : Float; Mode : Haul_Mode) return Float is
   begin
      return Distance_m / Speed_Of (Mode);
   end Compute_ETA_s;

   procedure Set_Time_Rate (C : in out Company; Rate : Float) is
   begin
      C.Time_Rate := Rate;
   end Set_Time_Rate;

   function Time_Rate_Of (C : Company) return Float is
   begin
      return C.Time_Rate;
   end Time_Rate_Of;

   function Haul_To_Dispatch (Mode : Haul_Mode) return Dispatch_Mode is
   begin
      case Mode is
         when Road =>
            return Road;
         when Tunnel =>
            return Tunnel;
         when Space_Haul =>
            return Space_Haul;
      end case;
   end Haul_To_Dispatch;


   procedure Mark_Rejected_ATC (C : in out Company; Order : Order_Id) is
      O : Order_Record;
   begin
      if Natural (Order) > C.O_Count then
         return;
      end if;
      O := C.Orders (Order);
      if O.Status in Pending | Accepted then
         C.Orders (Order).Status := Rejected_ATC;
      end if;
   end Mark_Rejected_ATC;

   procedure Assign_Vehicle
     (C          : in out Company;
      Order      : Order_Id;
      Vehicle    : Vehicle_Id;
      Distance_m : Float;
      Mode       : Haul_Mode := Road;
      Success    : out Boolean;
      Now        : Ada.Calendar.Time := Ada.Calendar.Clock)
   is
      O : Order_Record;
      V : Vehicle_Record;
   begin
      Success := False;
      if Natural (Order) > C.O_Count then
         return;
      end if;
      if Natural (Vehicle) > C.V_Count then
         return;
      end if;
      O := C.Orders (Order);
      if O.Status not in Pending | Accepted then
         return;
      end if;
      V := C.Vehicles (Vehicle);
      if not V.Available then
         return;
      end if;

      -- Assignment uses the same educational hazard/matrix gates as
      -- Dispatch_Order.  Haul_Mode is mapped to the public dispatch mode.
      if not Mode_Allows_Hazard (Haul_To_Dispatch (Mode), O.Hazard) then
         return;
      end if;
      if Mode in Road | Tunnel and then not V.Has_Body then
         return;
      end if;
      if not Compatible
        (O.Cargo, V.Attached_Body, Haul_To_Dispatch (Mode), O.Hazard)
      then
         return;
      end if;
      if Mode in Road | Tunnel
        and then Requires_Tank_Body (O.Hazard)
        and then V.Attached_Body /= Tank
      then
         return;
      end if;

      if Mode = Space_Haul then
         if not City_Pad_Open (C, O.Origin)
           or else not City_Pad_Open (C, O.Destination)
         then
            return;
         end if;
      end if;

      --  Assignment owns the vehicle clock for every haul mode.
      C.Vehicles (Vehicle).Available := False;

      C.Orders (Order).Status := En_Route;
      C.Orders (Order).Mode := Haul_To_Dispatch (Mode);
      C.Orders (Order).Assigned_Vehicle := Vehicle;
      C.Orders (Order).Distance_m := Distance_m;
      C.Orders (Order).ETA_s := Compute_ETA_s (Distance_m, Mode);
      C.Orders (Order).Elapsed_s := 0.0;
      C.Orders (Order).Assign_Wall_Time := Now;

      C.Vehicles (Vehicle).Position := C.Cities (O.Origin).Position;
      C.Vehicles (Vehicle).Phase := Underway;
      C.Vehicles (Vehicle).Dock_World := Terra_0;
      C.Vehicles (Vehicle).Dwell_Remaining_s := 0.0;
      C.Vehicles (Vehicle).Route_From := C.Cities (O.Origin).Position;
      C.Vehicles (Vehicle).Route_To := C.Cities (O.Destination).Position;
      C.Vehicles (Vehicle).Trip_Elapsed_s := 0.0;
      C.Vehicles (Vehicle).Trip_ETA_s := C.Orders (Order).ETA_s;
      C.Vehicles (Vehicle).Bound_Order := Order;
      C.Vehicles (Vehicle).Has_Bound := True;
      Success := True;
   end Assign_Vehicle;

   procedure Advance_Vehicles (C : in out Company; Sim_Delta_s : Float) is
      Remaining : Float;
      To_Dock   : Float;
   begin
      if Sim_Delta_s <= 0.0 or else C.V_Count = 0 then
         return;
      end if;

      for I in Vehicle_Id range 1 .. Vehicle_Id (C.V_Count) loop
         Remaining := Sim_Delta_s;

         if C.Vehicles (I).Phase = Underway then
            if C.Vehicles (I).Trip_ETA_s > C.Vehicles (I).Trip_Elapsed_s then
               To_Dock := C.Vehicles (I).Trip_ETA_s
                 - C.Vehicles (I).Trip_Elapsed_s;
               To_Dock := Float'Min (Remaining, To_Dock);
               C.Vehicles (I).Trip_Elapsed_s :=
                 C.Vehicles (I).Trip_Elapsed_s + To_Dock;
               Remaining := Remaining - To_Dock;
            end if;

            C.Vehicles (I).Position :=
              Lerp (C.Vehicles (I).Route_From,
                    C.Vehicles (I).Route_To,
                    (if C.Vehicles (I).Trip_ETA_s > 0.0
                     then C.Vehicles (I).Trip_Elapsed_s
                       / C.Vehicles (I).Trip_ETA_s
                     else 1.0));

            if C.Vehicles (I).Trip_Elapsed_s >= C.Vehicles (I).Trip_ETA_s
              or else C.Vehicles (I).Trip_ETA_s <= 0.0
            then
               C.Vehicles (I).Position := C.Vehicles (I).Route_To;
               C.Vehicles (I).Phase := Docked;
               C.Vehicles (I).Dock_World := Terra_0;
               C.Vehicles (I).Dwell_Remaining_s := C.Turnaround_s;
               C.Vehicles (I).Available := C.Turnaround_s <= 0.0;
               if C.Turnaround_s <= 0.0 then
                  C.Vehicles (I).Dwell_Remaining_s := 0.0;
                  C.Vehicles (I).Has_Bound := False;
               end if;
            end if;
         end if;

         if C.Vehicles (I).Phase = Docked
           and then C.Vehicles (I).Dwell_Remaining_s > 0.0
         then
            if Remaining >= C.Vehicles (I).Dwell_Remaining_s then
               Remaining := Remaining - C.Vehicles (I).Dwell_Remaining_s;
               C.Vehicles (I).Dwell_Remaining_s := 0.0;
               C.Vehicles (I).Available := True;
               C.Vehicles (I).Has_Bound := False;
            else
               C.Vehicles (I).Dwell_Remaining_s :=
                 C.Vehicles (I).Dwell_Remaining_s - Remaining;
               C.Vehicles (I).Available := False;
            end if;
         end if;
      end loop;
   end Advance_Vehicles;

   procedure Advance_Elapsed (C : in out Company; Sim_Delta_s : Float) is
      Ok : Boolean;
   begin
      if Sim_Delta_s <= 0.0 then
         return;
      end if;
      Advance_Pad_Repairs (C, Sim_Delta_s);
      Advance_Vehicles (C, Sim_Delta_s);
      if C.O_Count = 0 then
         return;
      end if;
      for I in Order_Id range 1 .. Order_Id (C.O_Count) loop
         if C.Orders (I).Status = En_Route then
            C.Orders (I).Elapsed_s := C.Orders (I).Elapsed_s + Sim_Delta_s;
            if C.Orders (I).Elapsed_s >= C.Orders (I).ETA_s then
               Complete_Delivery (C, I, Ok);
            end if;
         end if;
      end loop;
   end Advance_Elapsed;

   procedure Tick
     (C   : in out Company;
      Now : Ada.Calendar.Time := Ada.Calendar.Clock)
   is
      Dt_Wall : Duration;
   begin
      if not C.Has_Last_Tick then
         C.Last_Tick_Wall := Now;
         C.Has_Last_Tick := True;
         return;
      end if;
      Dt_Wall := Now - C.Last_Tick_Wall;
      C.Last_Tick_Wall := Now;
      if Dt_Wall > 0.0 then
         Advance_Elapsed (C, Float (Dt_Wall) * C.Time_Rate);
      end if;
   end Tick;

   procedure Tick_Delta
     (C            : in out Company;
      Delta_Wall_s : Float)
   is
   begin
      if Delta_Wall_s > 0.0 then
         Advance_Elapsed (C, Delta_Wall_s * C.Time_Rate);
      end if;
   end Tick_Delta;

end Logistics_Module;
