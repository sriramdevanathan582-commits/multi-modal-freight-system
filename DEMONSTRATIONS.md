# Manual demonstrations

Do not run these concurrently with application writes. Use separate SQL*Plus sessions
connected to XEPDB1. Keep passwords out of scripts and screenshots.

## Read-only view
```sql
SELECT * FROM vw_shipment_summary ORDER BY shipment_id;
UPDATE vw_shipment_summary SET shipment_status='CANCELLED' WHERE shipment_id=8;
-- Expected ORA-42399; leave SQLERROR continuation enabled for this negative test.
SELECT shipment_id,shipment_status FROM vw_shipment_summary WHERE shipment_id=8;
```

## Execution plans
The recorded before-index plan was captured before IDX_SHIPMENT_CUSTOMER existed.
The fresh install includes that index. Do not drop a working index just to replay the baseline.
```sql
EXPLAIN PLAN FOR SELECT shipment_id,customer_id,shipment_status
FROM shipment WHERE customer_id=2;
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(NULL,NULL,'BASIC +PREDICATE'));
```
Observed: full scan before; index range scan and batched ROWID access after.
No timing or throughput benchmark was performed.

## Isolation
A: SET AUTOCOMMIT OFF; update customer 1 phone to '9000000077' without committing.
A sees that value. B: SELECT phone FROM customer WHERE customer_id=1;
B sees committed '9000000001'. A: ROLLBACK;

## Row locks
A: SELECT customer_id FROM customer WHERE customer_id=1 FOR UPDATE;
B: SELECT customer_id FROM customer WHERE customer_id=1 FOR UPDATE NOWAIT;
Expected ORA-00054. A: ROLLBACK; Repeat B query: succeeds. B: ROLLBACK;
This is lock contention, not a deadlock.

## Access control
In SYSTEM connected to XEPDB1, first check DBA_USERS for FREIGHT_REVIEWER.
Create only if absent. Set a private password interactively: run ACCEPT separately,
then type the password before pasting CREATE USER. Avoid double quotes and ampersands
in the password used with this substitution example. Keep spool off.
```sql
SET DEFINE ON
SET VERIFY OFF
ACCEPT reviewer_password CHAR PROMPT 'Choose reviewer password: ' HIDE
CREATE USER freight_reviewer IDENTIFIED BY "&reviewer_password";
UNDEFINE reviewer_password
GRANT CREATE SESSION TO freight_reviewer;
GRANT SELECT ON freight.customer TO freight_reviewer;
```
In a reviewer session: SHOW USER, then SELECT customer_id,customer_name FROM freight.customer;
The SELECT succeeds. UPDATE freight.customer SET phone=phone WHERE customer_id=1;
fails with ORA-01031. ROLLBACK;
In SYSTEM: REVOKE SELECT ON freight.customer FROM freight_reviewer;
Repeat the SELECT in reviewer: ORA-00942. Do not grant DBA or broad table privileges.
The final reviewer account retains CREATE SESSION but has no CUSTOMER SELECT grant.

## Savepoints and disposable DDL
Use sql/08_savepoint_demo.sql for partial rollback and sql/09_ddl_demo.sql for
CREATE, ALTER, COMMIT, TRUNCATE and DROP. The latter creates and removes only
REPORT_DDL_DEMO and should be run in a clean session.
