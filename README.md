# Multi-Modal Freight Transportation System

Database Systems project, VIT Vellore, academic year 2026–2027.

- Sriram Devanathan — 25BYB0277
- Rohan Pande P — 25BYB0276

Oracle relational database with a Python terminal application for customers, shipments,
cargo, road/rail/air/sea legs, vehicles, tracking events and transport costs.
Tracking events are entered manually; this is not live GPS tracking.

## Existing working database

If the FREIGHT database is already installed, **do not run installation scripts against it**.
Use the existing application as before. The SQL package is for reproduction in an empty schema.

## Requirements

- Oracle Database 21c XE and SQL*Plus; service XEPDB1 accessible locally.
- Python 3 and the `oracledb` package. Exact dependency versions were not captured.
- An empty project schema with CREATE SESSION, CREATE TABLE, CREATE PROCEDURE,
  CREATE TRIGGER, CREATE VIEW and a suitable tablespace quota, provisioned by the local DBA.
- Credentials entered interactively; no passwords are included in this repository.

## Fresh database installation

Open Command Prompt in this repository folder. Connect as the empty project schema:

```bat
sqlplus freight@//localhost:1521/XEPDB1
```

Use another schema username if FREIGHT already contains the working database.
At SQL*Plus, run:

```sql
@sql/install.sql
```

The installer stops if user tables already exist. It does not drop or erase any tables.
DDL commits implicitly; a failure can leave a partially created schema. Do not blindly rerun it.
The scripts are schema-neutral (the original FREIGHT qualifiers were removed).

Execution order:
1. `01_tables.sql`: 11 tables and their exported constraints.
2. `02_sample_data.sql`: current exported data; preserves IDs and date/time precision.
3. `03_plsql_objects.sql`: 3 functions, 5 procedures, 3 triggers.
4. `06_view_and_index.sql`: read-only summary view and customer lookup index.
5. `05_verify.sql`: counts, object status and compilation errors.

Data is loaded before triggers to avoid replaying completed tracking events.
Identity columns temporarily accept explicit values during import, then return to
GENERATED ALWAYS with START WITH LIMIT VALUE to advance beyond restored IDs.
New IDs need not match those produced by the original installation.
Reference: https://docs.oracle.com/en/database/oracle/oracle-database/21/sqlrf/ALTER-TABLE.html

## Run the application (Windows)

```bat
python -m venv .venv
.venv\Scripts\activate
python -m pip install -r requirements.txt
python app.py
```

Enter the schema username, `localhost:1521/XEPDB1`, and password when prompted.
For the local XE setup choose N for the mTLS-wallet question.

Menu: reference data; create shipment; add leg; add/update/delete cargo; record tracking;
shipment summary; fleet and costs; 17 reports; refresh statuses; export report results.
Writes commit when successful; handled operation errors roll back.
Use fresh IDs returned by the application for each new demonstration.
Plan all legs before departure. Complete earlier legs before departing on later legs.

Run the report queries in SQL*Plus with `@sql/04_report_queries.sql`, or choose
menu option 10 to save current query results to `query_outputs.md` beside app.py.

## Exported snapshot

| Table | Rows |
|---|---:|
| CUSTOMER | 5 |
| HUB | 8 |
| TRANSPORT_MODE | 4 |
| OPERATOR | 4 |
| ROUTE | 7 |
| VEHICLE | 6 |
| SHIPMENT | 7 |
| CARGO | 8 |
| SHIPMENT_LEG | 11 |
| TRACKING_EVENT | 9 |
| TRANSPORT_COST | 20 |

Includes delivered shipments 8 and 21. Counts change after new demonstrations.

## Verification and limitations

Packaging checks performed: Python syntax, 11 DDL definitions, 11 PL/SQL source
objects, 17 extracted report queries, XML parsing, snapshot IDs/foreign-key references,
and date/time formats. No Oracle instance was available in the packaging environment;
a fresh installation has not yet been executed there. Validate in an empty Oracle schema
before claiming a tested clean install.

The application is the uploaded working version, unchanged. The report queries are
extracted from its REPORTS tuple. Tables and PL/SQL logic preserve the exported design.

The schema is not fully in 3NF/BCNF: shipment legs repeat route endpoints and vehicle
mode, and vehicles repeat operator mode under the current one-mode-per-operator rule.
Triggers validate selected operations but do not remove redundancy or cover every
possible parent-table edit. No real-time fleet scheduling or comprehensive concurrent
capacity enforcement is implemented. The application connects as a schema owner;
separate least-privilege application roles are not yet implemented.

Additional evidence now covers the view, index access-path change, savepoints, read isolation,
row locking, GRANT/REVOKE, additional SQL and disposable DDL. See DEMONSTRATIONS.md.
No performance timing, deadlock experiment or backup/restore test was performed.
Complete administrative schema provisioning is still a DBA prerequisite.

## Final evidence
query_outputs.md was refreshed on 29 October 2026 at 00:32:49 IST.
The existing installation shows 3 functions, 5 procedures, 3 triggers and 1 view VALID.
Run on PowerShell without activation: `.\.venv\Scripts\python.exe app.py --capture`.
New scripts 07 to 09 are demonstrations, not automatic installation steps.
