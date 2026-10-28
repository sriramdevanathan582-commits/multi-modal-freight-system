"""One-file Oracle demo for the Multi-Modal Freight Transportation System."""

from datetime import datetime
from decimal import Decimal, InvalidOperation
from getpass import getpass
from pathlib import Path
import re
import sys

try:
    import oracledb
except ImportError:
    raise SystemExit("Install the Oracle driver first: python -m pip install oracledb")


TABLES = (
    "CUSTOMER", "SHIPMENT", "HUB", "ROUTE", "SHIPMENT_LEG", "CARGO",
    "TRANSPORT_MODE", "TRACKING_EVENT", "OPERATOR", "VEHICLE", "TRANSPORT_COST",
)
OBJECTS = (
    "FN_SHIPMENT_TOTAL_COST", "FN_SHIPMENT_CARGO_WEIGHT", "FN_SHIPMENT_STATUS",
    "SP_CREATE_SHIPMENT", "SP_ADD_SHIPMENT_LEG", "SP_RECORD_TRACKING_EVENT",
    "SP_REFRESH_SHIPMENT_STATUSES", "SP_ASSIGN_VEHICLE_TO_LEG",
    "TRG_TRACKING_EVENT_APPLY", "TRG_SHIPMENT_STATUS_ROLLUP", "TRG_LEG_VEHICLE_MODE",
)


def connect():
    if not sys.stdin.isatty():
        raise RuntimeError("Run app.py in a terminal so the password prompt stays hidden.")
    print("Connect to your Oracle project database")
    user = input("Database username [freight]: ").strip() or "freight"
    dsn = input("Oracle DSN [localhost:1521/XEPDB1]: ").strip() or "localhost:1521/XEPDB1"
    password = getpass("Database password (hidden): ")
    if not user or not dsn or not password:
        raise RuntimeError("Username, DSN, and password are required.")

    options = {}
    if input("Does this connection require an mTLS wallet? [y/N]: ").strip().lower() in ("y", "yes"):
        wallet = input("Private wallet folder: ").strip().strip('"')
        wallet_password = getpass("Wallet password (hidden): ")
        if not wallet or not wallet_password:
            raise RuntimeError("Wallet folder and password are required.")
        options = {
            "config_dir": wallet,
            "wallet_location": wallet,
            "wallet_password": wallet_password,
        }
    return oracledb.connect(user=user, password=password, dsn=dsn, **options)


def validate_database(connection):
    names = ",".join(f"'{name}'" for name in TABLES)
    with connection.cursor() as cursor:
        cursor.execute(f"SELECT table_name FROM user_tables WHERE table_name IN ({names})")
        found = {row[0] for row in cursor.fetchall()}
        missing = sorted(set(TABLES) - found)
        if missing:
            raise RuntimeError("Missing tables: " + ", ".join(missing) + ". Run SQL scripts 01 and 02.")

        print("Current table record counts:")
        for table in TABLES:
            cursor.execute(f"SELECT COUNT(*) FROM {table}")
            print(f"  {table}: {cursor.fetchone()[0]}")

        names = ",".join(f"'{name}'" for name in OBJECTS)
        cursor.execute(
            f"SELECT object_name, status FROM user_objects "
            f"WHERE object_type IN ('FUNCTION','PROCEDURE','TRIGGER') AND object_name IN ({names})"
        )
        statuses = dict(cursor.fetchall())
        missing = sorted(set(OBJECTS) - set(statuses))
        invalid = sorted(name for name, status in statuses.items() if status != "VALID")
        if missing or invalid:
            problems = missing + [name + " (invalid)" for name in invalid]
            raise RuntimeError("PL/SQL objects need attention: " + ", ".join(problems) + ". Run SQL script 03.")
    print("Database ready: 11 tables and all 11 required PL/SQL objects are valid.")


def rows(connection, sql, values=None):
    with connection.cursor() as cursor:
        cursor.execute(sql, values or {})
        headings = [column[0] for column in cursor.description]
        print(" | ".join(headings))
        print("-" * min(120, sum(len(item) for item in headings) + 3 * len(headings)))
        result = cursor.fetchall()
        if not result:
            print("No rows found.")
        for row in result:
            print(" | ".join("NULL" if value is None else str(value) for value in row))
        print(f"{len(result)} row(s)")


def integer(prompt):
    while True:
        try:
            return int(input(prompt).strip())
        except ValueError:
            print("Enter a whole number.")


def number(prompt):
    while True:
        try:
            value = Decimal(input(prompt).strip())
            if not value.is_finite():
                raise ValueError("Enter a finite number.")
            return value
        except (ValueError, InvalidOperation):
            print("Enter a finite number.")


def date_value(prompt):
    value = input(prompt).strip()
    if not value:
        return None
    try:
        return datetime.strptime(value, "%Y-%m-%d").date()
    except ValueError:
        raise ValueError("Use YYYY-MM-DD, or leave the date blank.")


def show_reference_data(connection):
    selections = (
        ("Customers", "SELECT customer_id, customer_name FROM customer ORDER BY customer_id"),
        ("Hubs", "SELECT hub_id, hub_name FROM hub ORDER BY hub_id"),
        ("Routes", "SELECT route_id, route_name FROM route ORDER BY route_id"),
        ("Transport modes", "SELECT mode_id, mode_name FROM transport_mode ORDER BY mode_id"),
        ("Operators", "SELECT operator_id, operator_name FROM operator ORDER BY operator_id"),
        (
            "Vehicles",
            "SELECT v.vehicle_id, v.registration_number, m.mode_name, o.operator_name "
            "FROM vehicle v JOIN transport_mode m ON m.mode_id=v.mode_id "
            "JOIN operator o ON o.operator_id=v.operator_id ORDER BY v.vehicle_id",
        ),
    )
    for title, sql in selections:
        print("\n" + title)
        rows(connection, sql)


def create_shipment(connection):
    customer = integer("Customer ID: ")
    origin = integer("Origin hub ID: ")
    destination = integer("Destination hub ID: ")
    with connection.cursor() as cursor:
        new_id = cursor.var(oracledb.NUMBER)
        cursor.callproc("sp_create_shipment", [customer, origin, destination, new_id])
        shipment_id = int(new_id.getvalue())
    connection.commit()
    print(f"Shipment {shipment_id} created.")


def add_leg(connection):
    shipment = integer("Shipment ID: ")
    route = integer("Route ID: ")
    mode = integer("Transport mode ID: ")
    vehicle = integer("Vehicle ID for this mode: ")
    order = integer("Leg order: ")
    departure = None
    arrival = None
    print("Actual travel times will be recorded by tracking events.")
    cost = number("Base leg cost in INR: ")
    with connection.cursor() as cursor:
        new_id = cursor.var(oracledb.NUMBER)
        cursor.callproc("sp_add_shipment_leg", [
            shipment, route, mode, vehicle, order, departure, arrival, cost, new_id,
        ])
        leg_id = int(new_id.getvalue())
    connection.commit()
    print(f"Shipment leg {leg_id} added; shipment status was recalculated.")


def manage_cargo(connection):
    choice = input("Cargo: [1] Add  [2] Change value  [3] Delete  [0] Back: ").strip()
    with connection.cursor() as cursor:
        if choice == "1":
            new_id = cursor.var(oracledb.NUMBER)
            cursor.execute(
                "INSERT INTO cargo (shipment_id,mode_id,cargo_type,description,weight_kg,quantity,declared_value,fragile_flag) "
                "VALUES (:b_shipment,:b_mode,:b_kind,:b_description,:b_weight,:b_quantity,:b_value,:b_fragile) "
                "RETURNING cargo_id INTO :b_new_id",
                {
                    "b_shipment": integer("Shipment ID: "),
                    "b_mode": integer("Primary transport mode ID: "),
                    "b_kind": input("Cargo type: ").strip(),
                    "b_description": input("Description: ").strip(),
                    "b_weight": number("Weight per unit in kg: "),
                    "b_quantity": integer("Quantity: "),
                    "b_value": number("Declared value for the entire cargo row in INR: "),
                    "b_fragile": input("Fragile? Y/N [N]: ").strip().upper() or "N",
                    "b_new_id": new_id,
                },
            )
            cargo_id = int(new_id.getvalue()[0])
            cursor.execute(
                "SELECT COUNT(*) FROM shipment_leg sl "
                "JOIN vehicle v ON v.vehicle_id=sl.vehicle_id "
                "WHERE sl.shipment_id=(SELECT shipment_id FROM cargo WHERE cargo_id=:b_cargo) "
                "AND (sl.status <> 'PLANNED' OR "
                "fn_shipment_cargo_weight(sl.shipment_id)>v.capacity)",
                {"b_cargo": cargo_id},
            )
            if cursor.fetchone()[0]:
                raise ValueError("Cargo cannot be added after a leg starts or beyond assigned vehicle capacity.")
            connection.commit()
            print(f"Cargo {cargo_id} added.")
        elif choice == "2":
            cursor.execute(
                "UPDATE cargo SET declared_value=:b_value WHERE cargo_id=:b_cargo",
                {"b_value": number("New declared value in INR: "), "b_cargo": integer("Cargo ID: ")},
            )
            count = cursor.rowcount
            connection.commit()
            print(f"Updated {count} cargo row(s).")
        elif choice == "3":
            cargo = integer("Cargo ID: ")
            if input("Type YES to delete this cargo row: ").strip().upper() == "YES":
                cursor.execute("DELETE FROM cargo WHERE cargo_id=:b_cargo", {"b_cargo": cargo})
                count = cursor.rowcount
                connection.commit()
                print(f"Deleted {count} cargo row(s).")
            else:
                print("Delete cancelled.")
        elif choice != "0":
            print("Choose 1, 2, 3, or 0.")


def record_event(connection):
    leg = integer("Shipment leg ID: ")
    event = input("Event (CHECKPOINT, DEPARTED, ARRIVED, DELAYED, CANCELLED): ").strip()
    location = input("Event location: ").strip()
    remarks = input("Remarks (optional): ").strip() or None
    with connection.cursor() as cursor:
        cursor.callproc("sp_record_tracking_event", [leg, event, location, remarks])
    connection.commit()
    print("Tracking event saved; status triggers ran.")


def shipment_summary(connection):
    shipment = integer("Shipment ID: ")
    rows(connection,
        "SELECT s.shipment_id,c.customer_name,s.shipment_status, "
        "fn_shipment_total_cost(s.shipment_id) AS total_cost_inr, "
        "fn_shipment_cargo_weight(s.shipment_id) AS total_weight_kg "
        "FROM shipment s JOIN customer c ON c.customer_id=s.customer_id "
        "WHERE s.shipment_id=:b_shipment", {"b_shipment": shipment})


def fleet_and_costs(connection):
    choice = input("Fleet/costs: [1] View assignments  [2] Assign vehicle  [3] Add cost  [0] Back: ").strip()
    if choice == "1":
        rows(connection,
            "SELECT sl.leg_id,sl.shipment_id,sl.leg_order,m.mode_name,v.registration_number,o.operator_name "
            "FROM shipment_leg sl JOIN transport_mode m ON m.mode_id=sl.mode_id "
            "LEFT JOIN vehicle v ON v.vehicle_id=sl.vehicle_id "
            "LEFT JOIN operator o ON o.operator_id=v.operator_id ORDER BY sl.shipment_id,sl.leg_order")
    elif choice == "2":
        with connection.cursor() as cursor:
            cursor.callproc("sp_assign_vehicle_to_leg", [integer("Shipment leg ID: "), integer("Vehicle ID: ")])
        connection.commit()
        print("Vehicle assigned; the database checked its transport mode.")
    elif choice == "3":
        with connection.cursor() as cursor:
            new_id = cursor.var(oracledb.NUMBER)
            cursor.execute(
                "INSERT INTO transport_cost (leg_id,cost_type,amount,description) "
                "VALUES (:b_leg,:b_kind,:b_amount,:b_description) RETURNING cost_id INTO :b_new_id",
                {
                    "b_leg": integer("Shipment leg ID: "),
                    "b_kind": input("Cost type (FUEL, HANDLING, TOLL, STORAGE, INSURANCE, OTHER): ").strip().upper(),
                    "b_amount": number("Amount in INR: "),
                    "b_description": input("Description (optional): ").strip() or None,
                    "b_new_id": new_id,
                },
            )
        connection.commit()
        print(f"Transport cost {int(new_id.getvalue()[0])} added.")
    elif choice != "0":
        print("Choose 1, 2, 3, or 0.")


REPORTS = (
    ('1', 'Customer directory', 'SELECT customer_id,customer_name,phone,email FROM customer ORDER BY customer_name'),
    ('2', 'Shipments awaiting departure', "SELECT shipment_id,TO_CHAR(shipment_date,'DD-MM-YYYY') booked_on,shipment_status FROM shipment WHERE shipment_status='BOOKED' ORDER BY shipment_id"),
    ('3', 'Shipment customers and endpoints', 'SELECT s.shipment_id,c.customer_name,ho.hub_name origin,hd.hub_name destination FROM shipment s JOIN customer c ON c.customer_id=s.customer_id JOIN hub ho ON ho.hub_id=s.origin_hub_id JOIN hub hd ON hd.hub_id=s.destination_hub_id ORDER BY s.shipment_id'),
    ('4', 'Transport plan', 'SELECT sl.shipment_id,sl.leg_order,tm.mode_name,v.registration_number,hf.hub_name from_hub,ht.hub_name to_hub FROM shipment_leg sl JOIN transport_mode tm ON tm.mode_id=sl.mode_id JOIN vehicle v ON v.vehicle_id=sl.vehicle_id JOIN hub hf ON hf.hub_id=sl.from_hub_id JOIN hub ht ON ht.hub_id=sl.to_hub_id ORDER BY sl.shipment_id,sl.leg_order'),
    ('5', 'Cargo totals', 'SELECT s.shipment_id,COUNT(cg.cargo_id) cargo_records,NVL(SUM(cg.weight_kg*cg.quantity),0) total_weight_kg,NVL(SUM(cg.declared_value),0) total_value_inr FROM shipment s LEFT JOIN cargo cg ON cg.shipment_id=s.shipment_id GROUP BY s.shipment_id ORDER BY s.shipment_id'),
    ('6', 'Total transport cost', 'SELECT s.shipment_id,c.customer_name,NVL(SUM(tc.amount),0) total_cost FROM shipment s JOIN customer c ON c.customer_id=s.customer_id LEFT JOIN shipment_leg sl ON sl.shipment_id=s.shipment_id LEFT JOIN transport_cost tc ON tc.leg_id=sl.leg_id GROUP BY s.shipment_id,c.customer_name ORDER BY s.shipment_id'),
    ('7', 'Costs by transport mode', "SELECT tm.mode_name,SUM(CASE WHEN tc.cost_type='BASE' THEN tc.amount ELSE 0 END) base_cost,SUM(CASE WHEN tc.cost_type='HANDLING' THEN tc.amount ELSE 0 END) handling_cost,SUM(tc.amount) total_cost FROM transport_mode tm JOIN shipment_leg sl ON sl.mode_id=tm.mode_id JOIN transport_cost tc ON tc.leg_id=sl.leg_id GROUP BY tm.mode_name ORDER BY tm.mode_name"),
    ('8', 'Multimodal shipments', 'SELECT s.shipment_id,c.customer_name,COUNT(DISTINCT sl.mode_id) modes_used FROM shipment s JOIN customer c ON c.customer_id=s.customer_id JOIN shipment_leg sl ON sl.shipment_id=s.shipment_id GROUP BY s.shipment_id,c.customer_name HAVING COUNT(DISTINCT sl.mode_id)>1 ORDER BY s.shipment_id'),
    ('9', 'Above-average shipment costs', 'SELECT s.shipment_id,c.customer_name,fn_shipment_total_cost(s.shipment_id) total_cost FROM shipment s JOIN customer c ON c.customer_id=s.customer_id WHERE fn_shipment_total_cost(s.shipment_id)>(SELECT AVG(fn_shipment_total_cost(shipment_id)) FROM shipment) ORDER BY total_cost DESC'),
    ('10', 'Fragile cargo shipments', "SELECT s.shipment_id,c.customer_name FROM shipment s JOIN customer c ON c.customer_id=s.customer_id WHERE EXISTS (SELECT 1 FROM cargo cg WHERE cg.shipment_id=s.shipment_id AND cg.fragile_flag='Y') ORDER BY s.shipment_id"),
    ('11', 'Unassigned vehicles', 'SELECT v.vehicle_id,v.registration_number,v.vehicle_type FROM vehicle v WHERE NOT EXISTS (SELECT 1 FROM shipment_leg sl WHERE sl.vehicle_id=v.vehicle_id) ORDER BY v.vehicle_id'),
    ('12', 'Vehicle capacity usage per leg', 'SELECT sl.shipment_id,sl.leg_order,v.registration_number,v.capacity capacity_kg,fn_shipment_cargo_weight(sl.shipment_id) cargo_kg,ROUND(fn_shipment_cargo_weight(sl.shipment_id)/v.capacity*100,2) usage_pct FROM shipment_leg sl JOIN vehicle v ON v.vehicle_id=sl.vehicle_id ORDER BY sl.shipment_id,sl.leg_order'),
    ('13', 'Tracking history', "SELECT sl.shipment_id,sl.leg_order,te.event_type,te.event_location,TO_CHAR(te.event_datetime,'DD-MM-YYYY HH24:MI:SS') event_time FROM tracking_event te JOIN shipment_leg sl ON sl.leg_id=te.leg_id ORDER BY sl.shipment_id,te.event_datetime,te.event_id"),
    ('14', 'Latest tracking event per shipment', "SELECT shipment_id,event_type,event_location,TO_CHAR(event_datetime,'DD-MM-YYYY HH24:MI:SS') event_time FROM (SELECT sl.shipment_id,te.event_type,te.event_location,te.event_datetime,ROW_NUMBER() OVER (PARTITION BY sl.shipment_id ORDER BY te.event_datetime DESC,te.event_id DESC) rn FROM tracking_event te JOIN shipment_leg sl ON sl.leg_id=te.leg_id) WHERE rn=1 ORDER BY shipment_id"),
    ('15', 'Operator leg assignments', 'SELECT o.operator_name,COUNT(sl.leg_id) assigned_legs FROM operator o LEFT JOIN vehicle v ON v.operator_id=o.operator_id LEFT JOIN shipment_leg sl ON sl.vehicle_id=v.vehicle_id GROUP BY o.operator_id,o.operator_name ORDER BY assigned_legs DESC,o.operator_name'),
    ('16', 'Planned journey distance', 'SELECT s.shipment_id,c.customer_name,NVL(SUM(r.distance),0) total_distance_km FROM shipment s JOIN customer c ON c.customer_id=s.customer_id LEFT JOIN shipment_leg sl ON sl.shipment_id=s.shipment_id LEFT JOIN route r ON r.route_id=sl.route_id GROUP BY s.shipment_id,c.customer_name ORDER BY s.shipment_id'),
    ('17', 'Shipment cost ranking', 'SELECT shipment_id,customer_name,total_cost,DENSE_RANK() OVER (ORDER BY total_cost DESC) cost_rank FROM (SELECT s.shipment_id,c.customer_name,fn_shipment_total_cost(s.shipment_id) total_cost FROM shipment s JOIN customer c ON c.customer_id=s.customer_id) ORDER BY cost_rank,shipment_id'),
)

def reports_from_sql():
    return REPORTS


def run_report(connection):
    reports = reports_from_sql()
    for number, title, _ in reports:
        print(f"{number}. {title}")
    choice = integer("Report number: ")
    if not 1 <= choice <= len(reports):
        print("Choose a report from 1 to 17.")
        return
    _, title, sql = reports[choice - 1]
    print("\n" + title)
    rows(connection, sql)


def markdown(value):
    if value is None:
        return "NULL"
    return str(value).replace("|", "\\|").replace("\r\n", "<br>").replace("\n", "<br>")


def capture_reports(connection):
    output = [
        "# Oracle Query Results", "",
        f"Captured from Oracle at {datetime.now().astimezone().isoformat(timespec='seconds')}.",
        "", "These are live results from all 17 report queries.", "",
    ]
    with connection.cursor() as cursor:
        for number, title, sql in reports_from_sql():
            cursor.execute(sql)
            headings = [column[0] for column in cursor.description]
            result = cursor.fetchall()
            output.extend([f"## {number}. {title}", "", "| " + " | ".join(headings) + " |", "| " + " | ".join("---" for _ in headings) + " |"])
            for row in result:
                output.append("| " + " | ".join(markdown(value) for value in row) + " |")
            output.extend(["", f"{len(result)} row(s).", ""])
    path = Path(__file__).with_name("query_outputs.md")
    path.write_text("\n".join(output), encoding="utf-8")
    print(f"Saved live results for all 17 queries to {path.name}.")


def refresh_statuses(connection):
    with connection.cursor() as cursor:
        cursor.callproc("sp_refresh_shipment_statuses")
    connection.commit()
    print("Shipment statuses refreshed by the cursor procedure.")


def main():
    if len(sys.argv) > 1 and sys.argv[1] in ("-h", "--help"):
        print("Usage: python app.py [--capture]\nRun the menu, or save all 17 Oracle query results with --capture.")
        return 0
    if len(sys.argv) > 2 or (len(sys.argv) == 2 and sys.argv[1] != "--capture"):
        print("Usage: python app.py [--capture]")
        return 2

    connection = None
    try:
        connection = connect()
        with connection.cursor() as cursor:
            cursor.execute("SELECT 'Connected to Oracle' FROM dual")
            print(cursor.fetchone()[0])
        validate_database(connection)

        if len(sys.argv) == 2:
            capture_reports(connection)
            return 0

        actions = {
            "1": ("Show customers, hubs, routes, modes, operators, and vehicles", show_reference_data),
            "2": ("Create a shipment", create_shipment),
            "3": ("Add a shipment leg", add_leg),
            "4": ("Add, update, or delete cargo", manage_cargo),
            "5": ("Record a tracking event", record_event),
            "6": ("Show shipment cost and cargo summary", shipment_summary),
            "7": ("View fleet, assign a vehicle, or add a transport cost", fleet_and_costs),
            "8": ("Run one of the 17 report queries", run_report),
            "9": ("Refresh shipment statuses with the cursor", refresh_statuses),
            "10": ("Save results from all 17 report queries", capture_reports),
        }
        while True:
            print("\nMULTI-MODAL FREIGHT DATABASE")
            for number, (label, _) in actions.items():
                print(f"{number}. {label}")
            print("0. Exit")
            choice = input("Choose an option: ").strip()
            if choice == "0":
                print("Goodbye.")
                return 0
            action = actions.get(choice)
            if action is None:
                print("Choose one of the listed options.")
                continue
            try:
                action[1](connection)
            except (oracledb.Error, RuntimeError, ValueError, OSError) as exc:
                connection.rollback()
                print(f"Could not complete that operation: {exc}")
    except KeyboardInterrupt:
        print("\nCancelled.")
        return 130
    except Exception as exc:
        print(f"Could not start the project: {exc}")
        return 1
    finally:
        if connection is not None:
            connection.close()


if __name__ == "__main__":
    raise SystemExit(main())