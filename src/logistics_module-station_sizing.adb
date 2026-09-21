--  Fixed-mix sweep for the educational 150-person station scenario.
pragma Ada_2022;

with Logistics_Module.Demand_Cells;

package body Logistics_Module.Station_Sizing is

   use Logistics_Module.Demand_Cells;

   function Kg_Per_Person_Day
     (Band : Station_Cargo_Band) return Float is
   begin
      case Band is
         when Consumables            => return Consumables_kg_person_day;
         when Spare_Parts            => return Spare_Parts_kg_person_day;
         when Power_Logistics        => return Power_Logistics_kg_person_day;
         when Thermal_Fluids_Cabling => return Thermal_Fluids_Cabling_kg_person_day;
      end case;
   end Kg_Per_Person_Day;

   function Total_Demand_Rate_kg_s (Crew : Natural := Crew_N) return Float is
      Per_Day : Float := 0.0;
   begin
      for Band in Station_Cargo_Band loop
         Per_Day := Per_Day + Kg_Per_Person_Day (Band);
      end loop;
      return Float (Crew) * Per_Day / Seconds_Per_Day_s;
   end Total_Demand_Rate_kg_s;

   procedure Simulate_Mix
     (Crew           : Positive;
      N_Ticks        : Positive;
      Delta_s        : Float;
      Distance_m     : Float;
      Barge_Count    : Natural;
      Courier_Count  : Natural;
      Stub_Count     : Natural;
      Final_Deficit  : out Float;
      Is_Sustained   : out Boolean)
   is
      Market : Barge_Market := Init_Barge_Market;
      Cell   : Demand_Cell;
      State  : Tournament_State;
      Rate   : constant Float := Total_Demand_Rate_kg_s (Crew);
      Slot_Mass : constant Float := Rate * Delta_s;
      Booked : Float;
      Bid : Float;
      Ok : Boolean;
   begin
      --  Whole-barge ownership goes through the shared educational market.
      for I in 1 .. Barge_Count loop
         if not Bid_For_Barge (Market, Market.Ask_Price) then
            Final_Deficit := Float'Last;
            Is_Sustained := False;
            return;
         end if;
      end loop;

      --  Book one current replenishment slot as a separate market product.
      --  The booking is intentionally not the hull throughput calculation.
      if Barge_Count > 0 then
         Booked := Float'Min (Slot_Mass, Remaining_Hold_kg (Market));
         if Booked > 0.0 then
            Bid := Ask_Per_Kg (Market) * Booked;
            Bid_Hold_Slot (Market, Booked, Bid, Ok);
            if not Ok then
               Final_Deficit := Float'Last;
               Is_Sustained := False;
               return;
            end if;
         end if;
      end if;

      Cell :=
        (Demand_Rate_kg_s => Rate,
         Stock_kg         => 0.0,
         Horizon_s        => Delta_s,
         Distance_m       => Distance_m,
         Fleet            => [Barge_Inner   => Barge_Count,
                              Fast_Courier  => Courier_Count,
                              Relativistic_Stub => Stub_Count],
         Preferred        => Barge_Inner,
         Cell_Id          => Crew);
      Seed_Cell_With_Barge_Market (Cell, Market);

      --  The Evolve switch makes the tournament loop a fixed-fleet probe: it
      --  still accrues SI scores and runs the normal stock tick, but a search
      --  candidate cannot mutate while it is being measured.  Run the final
      --  K ticks one at a time so the sustained test is explicit rather than
      --  merely checking one final sample.
      declare
         Tail_Ticks : constant Positive :=
           Positive'Min (Sustained_Window_Ticks, N_Ticks);
         Prefix_Ticks : constant Natural := N_Ticks - Tail_Ticks;
         Tail_Good : Boolean := True;
      begin
         if Prefix_Ticks > 0 then
            Run_Tournament_Ticks
              (Cell      => Cell,
               State     => State,
               N_Ticks   => Prefix_Ticks,
               Delta_s   => Delta_s,
               Log       => False,
               Evolve    => False);
         end if;
         for I in 1 .. Tail_Ticks loop
            Run_Tournament_Ticks
              (Cell      => Cell,
               State     => State,
               N_Ticks   => 1,
               Delta_s   => Delta_s,
               Log       => False,
               Evolve    => False);
            Tail_Good := Tail_Good and then not Under_Served (Cell);
         end loop;
         Final_Deficit := Deficit_kg (Cell);
         Is_Sustained := Tail_Good;
      end;
   end Simulate_Mix;

   procedure Size_Station_Fleet
     (Crew             : Positive := Crew_N;
      N_Ticks          : Positive := 6000;
      Delta_s          : Float := 1_296_000.0;
      Distance_m       : Float := Mars_Offset_m;
      Min_Barges       : out Natural;
      Min_Couriers     : out Natural;
      Min_Rel_Stubs    : out Natural;
      Final_Deficit_kg : out Float;
      Sustained        : out Boolean)
   is
      Found : Boolean := False;
      Deficit : Float := 0.0;
      Good : Boolean := False;
   begin
      Min_Barges := 0;
      Min_Couriers := 0;
      Min_Rel_Stubs := 0;
      Final_Deficit_kg := Float'Last;
      Sustained := False;

      if Delta_s <= 0.0 or else Distance_m <= 0.0 then
         return;
      end if;

      for B in Barge_Pool_Min .. Search_Max_Barges loop
         exit when Found;
         for C in 0 .. Search_Max_Couriers loop
            exit when Found;
            for R in 0 .. Search_Max_Rel_Stubs loop
               Simulate_Mix
                 (Crew, N_Ticks, Delta_s, Distance_m, B, C, R,
                  Deficit, Good);
               if Good then
                  Min_Barges := B;
                  Min_Couriers := C;
                  Min_Rel_Stubs := R;
                  Final_Deficit_kg := Deficit;
                  Sustained := True;
                  Found := True;
                  exit;
               end if;
            end loop;
         end loop;
      end loop;
   end Size_Station_Fleet;

end Logistics_Module.Station_Sizing;
