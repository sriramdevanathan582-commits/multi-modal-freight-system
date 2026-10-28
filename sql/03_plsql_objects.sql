SET DEFINE OFF
SET SQLBLANKLINES ON
SET SERVEROUTPUT ON
WHENEVER SQLERROR EXIT SQL.SQLCODE ROLLBACK

CREATE OR REPLACE FUNCTION fn_shipment_cargo_weight (
    p_shipment_id IN NUMBER
) RETURN NUMBER
IS
    v_exists NUMBER;
    v_total NUMBER;
BEGIN
    SELECT COUNT(*)
    INTO v_exists
    FROM shipment
    WHERE shipment_id = p_shipment_id;
    IF v_exists = 0 THEN
        RAISE_APPLICATION_ERROR(-20001, 'Shipment does not exist.');
    END IF;
    SELECT NVL(SUM(weight_kg * quantity), 0)
    INTO v_total
    FROM cargo
    WHERE shipment_id = p_shipment_id;
    RETURN v_total;
END;
/
SHOW ERRORS

CREATE OR REPLACE FUNCTION fn_shipment_status (
    p_shipment_id IN NUMBER
) RETURN VARCHAR2
IS
    v_origin NUMBER;
    v_destination NUMBER;
    v_total NUMBER := 0;
    v_completed NUMBER := 0;
    v_cancelled NUMBER := 0;
    v_delayed NUMBER := 0;
    v_planned NUMBER := 0;
    v_expected_hub NUMBER;
    v_chain_valid BOOLEAN := TRUE;
BEGIN
    BEGIN
        SELECT origin_hub_id, destination_hub_id
        INTO v_origin, v_destination
        FROM shipment
        WHERE shipment_id = p_shipment_id;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20001,
                'Shipment does not exist.');
    END;
    v_expected_hub := v_origin;
    FOR rec IN (
        SELECT leg_order, from_hub_id, to_hub_id, status
        FROM shipment_leg
        WHERE shipment_id = p_shipment_id
        ORDER BY leg_order
    ) LOOP
        v_total := v_total + 1;
        IF rec.leg_order <> v_total
           OR rec.from_hub_id <> v_expected_hub THEN
            v_chain_valid := FALSE;
        END IF;
        v_expected_hub := rec.to_hub_id;
        CASE rec.status
            WHEN 'COMPLETED' THEN
                v_completed := v_completed + 1;
            WHEN 'CANCELLED' THEN
                v_cancelled := v_cancelled + 1;
            WHEN 'DELAYED' THEN
                v_delayed := v_delayed + 1;
            WHEN 'PLANNED' THEN
                v_planned := v_planned + 1;
            ELSE
                NULL;
        END CASE;
    END LOOP;
    IF v_total = 0 THEN
        RETURN 'BOOKED';
    ELSIF v_cancelled = v_total THEN
        RETURN 'CANCELLED';
    ELSIF v_delayed > 0 OR v_cancelled > 0 THEN
        RETURN 'DELAYED';
    ELSIF v_completed = v_total
          AND v_chain_valid
          AND v_expected_hub = v_destination THEN
        RETURN 'DELIVERED';
    ELSIF v_planned = v_total THEN
        RETURN 'BOOKED';
    ELSE
        RETURN 'IN_TRANSIT';
    END IF;
END;
/
SHOW ERRORS

CREATE OR REPLACE FUNCTION fn_shipment_total_cost (
    p_shipment_id IN NUMBER
) RETURN NUMBER
IS
    v_exists NUMBER;
    v_total NUMBER;
BEGIN
    SELECT COUNT(*)
    INTO v_exists
    FROM shipment
    WHERE shipment_id = p_shipment_id;
    IF v_exists = 0 THEN
        RAISE_APPLICATION_ERROR(-20001, 'Shipment does not exist.');
    END IF;
    SELECT NVL(SUM(tc.amount), 0)
    INTO v_total
    FROM shipment_leg sl
    JOIN transport_cost tc ON tc.leg_id = sl.leg_id
    WHERE sl.shipment_id = p_shipment_id;
    RETURN v_total;
END;
/
SHOW ERRORS

CREATE OR REPLACE PROCEDURE sp_add_shipment_leg (
    p_shipment_id IN NUMBER,
    p_route_id IN NUMBER,
    p_mode_id IN NUMBER,
    p_vehicle_id IN NUMBER,
    p_leg_order IN NUMBER,
    p_departure_date IN DATE,
    p_arrival_date IN DATE,
    p_base_cost IN NUMBER,
    p_leg_id OUT NUMBER
)
IS
    v_origin NUMBER;
    v_destination NUMBER;
    v_shipment_status shipment.shipment_status%TYPE;
    v_from NUMBER;
    v_to NUMBER;
    v_vehicle_mode NUMBER;
    v_operator_mode NUMBER;
    v_capacity NUMBER;
    v_weight NUMBER;
    v_last_order NUMBER;
    v_expected_from NUMBER;
BEGIN
    p_leg_id := NULL;
    IF p_shipment_id IS NULL OR p_route_id IS NULL
       OR p_mode_id IS NULL OR p_vehicle_id IS NULL
       OR p_leg_order IS NULL OR p_base_cost IS NULL THEN
        RAISE_APPLICATION_ERROR(-20010,
            'Shipment, route, mode, vehicle, order and cost are required.');
    END IF;
    IF p_leg_order < 1 OR p_leg_order <> TRUNC(p_leg_order) THEN
        RAISE_APPLICATION_ERROR(-20011,
            'Leg order must be a positive whole number.');
    END IF;
    IF p_base_cost < 0 THEN
        RAISE_APPLICATION_ERROR(-20012,
            'Base cost cannot be negative.');
    END IF;
    IF p_arrival_date < p_departure_date THEN
        RAISE_APPLICATION_ERROR(-20013,
            'Arrival cannot be before departure.');
    END IF;
    BEGIN
        SELECT origin_hub_id, destination_hub_id, shipment_status
        INTO v_origin, v_destination, v_shipment_status
        FROM shipment
        WHERE shipment_id = p_shipment_id
        FOR UPDATE;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20014,
                'Shipment does not exist.');
    END;
    IF v_shipment_status <> 'BOOKED' THEN
        RAISE_APPLICATION_ERROR(-20015,
            'Legs can only be added to a booked shipment.');
    END IF;
    BEGIN
        SELECT from_hub_id, to_hub_id
        INTO v_from, v_to
        FROM route
        WHERE route_id = p_route_id;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20016,
                'Route does not exist.');
    END;
    BEGIN
        SELECT v.mode_id, o.mode_id, v.capacity
        INTO v_vehicle_mode, v_operator_mode, v_capacity
        FROM vehicle v
        JOIN operator o ON o.operator_id = v.operator_id
        WHERE v.vehicle_id = p_vehicle_id;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20017,
                'Vehicle does not exist.');
    END;
    IF p_mode_id <> v_vehicle_mode
       OR p_mode_id <> v_operator_mode THEN
        RAISE_APPLICATION_ERROR(-20018,
            'Leg, vehicle and operator modes must match.');
    END IF;
    v_weight := fn_shipment_cargo_weight(p_shipment_id);
    IF v_weight > v_capacity THEN
        RAISE_APPLICATION_ERROR(-20019,
            'Cargo weight exceeds vehicle capacity.');
    END IF;
    SELECT NVL(MAX(leg_order), 0)
    INTO v_last_order
    FROM shipment_leg
    WHERE shipment_id = p_shipment_id;
    IF p_leg_order <> v_last_order + 1 THEN
        RAISE_APPLICATION_ERROR(-20020,
            'Add legs consecutively, starting at 1.');
    END IF;
    IF v_last_order = 0 THEN
        v_expected_from := v_origin;
    ELSE
        SELECT to_hub_id
        INTO v_expected_from
        FROM shipment_leg
        WHERE shipment_id = p_shipment_id
          AND leg_order = v_last_order;
        IF v_expected_from = v_destination THEN
            RAISE_APPLICATION_ERROR(-20021,
                'The route already reaches the shipment destination.');
        END IF;
    END IF;
    IF v_from <> v_expected_from THEN
        RAISE_APPLICATION_ERROR(-20022,
            'Route must start where the previous leg ends, or at origin.');
    END IF;
    SAVEPOINT before_leg_insert;
    BEGIN
        INSERT INTO shipment_leg (
            shipment_id, route_id, mode_id, vehicle_id,
            from_hub_id, to_hub_id, leg_order,
            departure_date, arrival_date, status
        )
        VALUES (
            p_shipment_id, p_route_id, p_mode_id, p_vehicle_id,
            v_from, v_to, p_leg_order,
            p_departure_date, p_arrival_date, 'PLANNED'
        )
        RETURNING leg_id INTO p_leg_id;
        INSERT INTO transport_cost (
            leg_id, cost_type, amount, currency, description
        )
        VALUES (
            p_leg_id, 'BASE', p_base_cost, 'INR',
            'Base transport charge'
        );
    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK TO before_leg_insert;
            p_leg_id := NULL;
            RAISE;
    END;
END;
/
SHOW ERRORS

CREATE OR REPLACE PROCEDURE sp_assign_vehicle_to_leg (
    p_leg_id IN NUMBER,
    p_vehicle_id IN NUMBER
)
IS
    v_status shipment_leg.status%TYPE;
    v_count NUMBER;
BEGIN
    IF p_leg_id IS NULL OR p_vehicle_id IS NULL THEN
        RAISE_APPLICATION_ERROR(-20070,
            'Leg ID and vehicle ID are required.');
    END IF;
    BEGIN
        SELECT status INTO v_status
        FROM shipment_leg
        WHERE leg_id = p_leg_id
        FOR UPDATE;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20071,
                'Shipment leg does not exist.');
    END;
    IF v_status <> 'PLANNED' THEN
        RAISE_APPLICATION_ERROR(-20072,
            'Vehicles can only be reassigned before a leg starts.');
    END IF;
    SELECT COUNT(*) INTO v_count
    FROM vehicle
    WHERE vehicle_id = p_vehicle_id;
    IF v_count = 0 THEN
        RAISE_APPLICATION_ERROR(-20073,
            'Vehicle does not exist.');
    END IF;
    UPDATE shipment_leg
    SET vehicle_id = p_vehicle_id
    WHERE leg_id = p_leg_id;
END;
/
SHOW ERRORS

CREATE OR REPLACE PROCEDURE sp_create_shipment (
    p_customer_id IN NUMBER,
    p_origin_hub_id IN NUMBER,
    p_destination_hub_id IN NUMBER,
    p_shipment_id OUT NUMBER
)
IS
    v_count NUMBER;
BEGIN
    IF p_customer_id IS NULL
       OR p_origin_hub_id IS NULL
       OR p_destination_hub_id IS NULL THEN
        RAISE_APPLICATION_ERROR(-20002,
            'Customer, origin and destination are required.');
    END IF;
    IF p_origin_hub_id = p_destination_hub_id THEN
        RAISE_APPLICATION_ERROR(-20003,
            'Origin and destination must be different.');
    END IF;
    SELECT COUNT(*) INTO v_count
    FROM customer
    WHERE customer_id = p_customer_id;
    IF v_count = 0 THEN
        RAISE_APPLICATION_ERROR(-20004, 'Customer does not exist.');
    END IF;
    SELECT COUNT(*) INTO v_count
    FROM hub
    WHERE hub_id IN (p_origin_hub_id, p_destination_hub_id);
    IF v_count <> 2 THEN
        RAISE_APPLICATION_ERROR(-20005,
            'Origin or destination hub does not exist.');
    END IF;
    INSERT INTO shipment (
        customer_id, shipment_date,
        origin_hub_id, destination_hub_id, shipment_status
    )
    VALUES (
        p_customer_id, SYSDATE,
        p_origin_hub_id, p_destination_hub_id, 'BOOKED'
    )
    RETURNING shipment_id INTO p_shipment_id;
END;
/
SHOW ERRORS

CREATE OR REPLACE PROCEDURE sp_record_tracking_event (
    p_leg_id IN NUMBER,
    p_event_type IN VARCHAR2,
    p_event_location IN VARCHAR2,
    p_remarks IN VARCHAR2
)
IS
    v_count NUMBER;
    v_event_type VARCHAR2(100);
BEGIN
    v_event_type := UPPER(TRIM(p_event_type));
    IF v_event_type IS NULL
       OR v_event_type NOT IN (
           'CHECKPOINT', 'DEPARTED', 'ARRIVED',
           'DELAYED', 'CANCELLED'
       ) THEN
        RAISE_APPLICATION_ERROR(-20060,
            'Invalid tracking event type.');
    END IF;
    IF TRIM(p_event_location) IS NULL THEN
        RAISE_APPLICATION_ERROR(-20061,
            'Event location is required.');
    END IF;
    SELECT COUNT(*) INTO v_count
    FROM shipment_leg
    WHERE leg_id = p_leg_id;
    IF v_count = 0 THEN
        RAISE_APPLICATION_ERROR(-20062,
            'Shipment leg does not exist.');
    END IF;
    INSERT INTO tracking_event (
        leg_id, event_type, event_location,
        event_datetime, remarks
    )
    VALUES (
        p_leg_id, v_event_type, TRIM(p_event_location),
        SYSTIMESTAMP, p_remarks
    );
END;
/
SHOW ERRORS

CREATE OR REPLACE PROCEDURE sp_refresh_shipment_statuses
IS
    CURSOR c_shipments IS
        SELECT shipment_id, shipment_status
        FROM shipment
        ORDER BY shipment_id
        FOR UPDATE OF shipment_status;
    v_new_status shipment.shipment_status%TYPE;
    v_checked NUMBER := 0;
    v_updated NUMBER := 0;
BEGIN
    FOR rec IN c_shipments LOOP
        v_checked := v_checked + 1;
        v_new_status := fn_shipment_status(rec.shipment_id);
        IF rec.shipment_status <> v_new_status THEN
            UPDATE shipment
            SET shipment_status = v_new_status
            WHERE CURRENT OF c_shipments;
            v_updated := v_updated + 1;
        END IF;
    END LOOP;
    DBMS_OUTPUT.PUT_LINE('Shipments checked: ' || v_checked);
    DBMS_OUTPUT.PUT_LINE('Statuses updated: ' || v_updated);
END;
/
SHOW ERRORS

CREATE OR REPLACE TRIGGER trg_leg_vehicle_mode
BEFORE INSERT OR UPDATE OF
    shipment_id, vehicle_id, mode_id, route_id,
    from_hub_id, to_hub_id
ON shipment_leg
FOR EACH ROW
DECLARE
    v_vehicle_mode NUMBER;
    v_operator_mode NUMBER;
    v_capacity NUMBER;
    v_route_from NUMBER;
    v_route_to NUMBER;
    v_weight NUMBER;
BEGIN
    BEGIN
        SELECT v.mode_id, o.mode_id, v.capacity
        INTO v_vehicle_mode, v_operator_mode, v_capacity
        FROM vehicle v
        JOIN operator o ON o.operator_id = v.operator_id
        WHERE v.vehicle_id = :NEW.vehicle_id;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20040,
                'A valid vehicle is required.');
    END;
    IF :NEW.mode_id IS NULL
       OR :NEW.mode_id <> v_vehicle_mode
       OR :NEW.mode_id <> v_operator_mode THEN
        RAISE_APPLICATION_ERROR(-20041,
            'Leg, vehicle and operator transport modes must match.');
    END IF;
    BEGIN
        SELECT from_hub_id, to_hub_id
        INTO v_route_from, v_route_to
        FROM route
        WHERE route_id = :NEW.route_id;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20042,
                'A valid route is required.');
    END;
    IF :NEW.from_hub_id IS NULL
       OR :NEW.to_hub_id IS NULL
       OR :NEW.from_hub_id <> v_route_from
       OR :NEW.to_hub_id <> v_route_to THEN
        RAISE_APPLICATION_ERROR(-20043,
            'Leg hubs must match the selected route.');
    END IF;
    v_weight := fn_shipment_cargo_weight(:NEW.shipment_id);
    IF v_weight > v_capacity THEN
        RAISE_APPLICATION_ERROR(-20044,
            'Cargo weight exceeds vehicle capacity.');
    END IF;
END;
/
SHOW ERRORS

CREATE OR REPLACE TRIGGER trg_shipment_status_rollup
FOR INSERT OR UPDATE OR DELETE ON shipment_leg
COMPOUND TRIGGER
    TYPE t_id_list IS TABLE OF shipment.shipment_id%TYPE
        INDEX BY PLS_INTEGER;
    g_ids t_id_list;
    g_count PLS_INTEGER := 0;
    PROCEDURE remember_shipment (
        p_id IN shipment.shipment_id%TYPE
    ) IS
    BEGIN
        IF p_id IS NULL THEN
            RETURN;
        END IF;
        IF g_count > 0 THEN
            FOR i IN 1 .. g_count LOOP
                IF g_ids(i) = p_id THEN
                    RETURN;
                END IF;
            END LOOP;
        END IF;
        g_count := g_count + 1;
        g_ids(g_count) := p_id;
    END remember_shipment;
    AFTER EACH ROW IS
    BEGIN
        IF INSERTING OR UPDATING THEN
            remember_shipment(:NEW.shipment_id);
        END IF;
        IF DELETING OR UPDATING THEN
            remember_shipment(:OLD.shipment_id);
        END IF;
    END AFTER EACH ROW;
    AFTER STATEMENT IS
        v_status shipment.shipment_status%TYPE;
    BEGIN
        IF g_count > 0 THEN
            FOR i IN 1 .. g_count LOOP
                v_status := fn_shipment_status(g_ids(i));
                UPDATE shipment
                SET shipment_status = v_status
                WHERE shipment_id = g_ids(i)
                  AND shipment_status <> v_status;
            END LOOP;
        END IF;
    END AFTER STATEMENT;
END trg_shipment_status_rollup;
/
SHOW ERRORS

CREATE OR REPLACE TRIGGER trg_tracking_event_apply
AFTER INSERT ON tracking_event
FOR EACH ROW
DECLARE
    v_shipment_id NUMBER;
    v_leg_order NUMBER;
    v_status shipment_leg.status%TYPE;
    v_departure DATE;
    v_pending NUMBER;
    v_event_date DATE;
BEGIN
    SELECT shipment_id, leg_order, status, departure_date
    INTO v_shipment_id, v_leg_order, v_status, v_departure
    FROM shipment_leg
    WHERE leg_id = :NEW.leg_id
    FOR UPDATE;
    v_event_date := CAST(:NEW.event_datetime AS DATE);
    IF :NEW.event_type <> 'CHECKPOINT' THEN
        IF v_status IN ('COMPLETED', 'CANCELLED') THEN
            RAISE_APPLICATION_ERROR(-20050,
                'Cannot change a completed or cancelled leg.');
        END IF;
        CASE :NEW.event_type
            WHEN 'DEPARTED' THEN
                IF v_status NOT IN ('PLANNED', 'DELAYED') THEN
                    RAISE_APPLICATION_ERROR(-20051,
                        'Departure requires a planned or delayed leg.');
                END IF;
                SELECT COUNT(*) INTO v_pending
                FROM shipment_leg
                WHERE shipment_id = v_shipment_id
                  AND leg_order < v_leg_order
                  AND status <> 'COMPLETED';
                IF v_pending > 0 THEN
                    RAISE_APPLICATION_ERROR(-20052,
                        'Complete earlier legs before departing.');
                END IF;
                IF v_status = 'DELAYED'
                   AND v_departure IS NOT NULL
                   AND v_event_date < v_departure THEN
                    RAISE_APPLICATION_ERROR(-20053,
                        'Event cannot precede departure.');
                END IF;
                UPDATE shipment_leg
                SET status = 'IN_TRANSIT',
                    departure_date =
                        CASE
                            WHEN v_status = 'PLANNED'
                                 OR v_departure IS NULL
                            THEN v_event_date
                            ELSE v_departure
                        END,
                    arrival_date = NULL
                WHERE leg_id = :NEW.leg_id;
            WHEN 'ARRIVED' THEN
                IF v_status NOT IN ('IN_TRANSIT', 'DELAYED')
                   OR v_departure IS NULL THEN
                    RAISE_APPLICATION_ERROR(-20054,
                        'Record departure before arrival.');
                END IF;
                IF v_event_date < v_departure THEN
                    RAISE_APPLICATION_ERROR(-20055,
                        'Arrival cannot precede departure.');
                END IF;
                UPDATE shipment_leg
                SET status = 'COMPLETED',
                    arrival_date = v_event_date
                WHERE leg_id = :NEW.leg_id;
            WHEN 'DELAYED' THEN
                UPDATE shipment_leg
                SET status = 'DELAYED'
                WHERE leg_id = :NEW.leg_id;
            WHEN 'CANCELLED' THEN
                UPDATE shipment_leg
                SET status = 'CANCELLED'
                WHERE leg_id = :NEW.leg_id;
        END CASE;
    END IF;
END;
/
SHOW ERRORS
