SET DEFINE OFF
SET SQLBLANKLINES ON
SET SERVEROUTPUT ON
WHENEVER SQLERROR EXIT SQL.SQLCODE ROLLBACK



SET LINESIZE 200
SET PAGESIZE 100

SELECT 'CUSTOMER' AS table_name, COUNT(*) AS actual_count, 5 AS expected_snapshot_count FROM CUSTOMER;

SELECT 'HUB' AS table_name, COUNT(*) AS actual_count, 8 AS expected_snapshot_count FROM HUB;

SELECT 'TRANSPORT_MODE' AS table_name, COUNT(*) AS actual_count, 4 AS expected_snapshot_count FROM TRANSPORT_MODE;

SELECT 'OPERATOR' AS table_name, COUNT(*) AS actual_count, 4 AS expected_snapshot_count FROM OPERATOR;

SELECT 'ROUTE' AS table_name, COUNT(*) AS actual_count, 7 AS expected_snapshot_count FROM ROUTE;

SELECT 'VEHICLE' AS table_name, COUNT(*) AS actual_count, 6 AS expected_snapshot_count FROM VEHICLE;

SELECT 'SHIPMENT' AS table_name, COUNT(*) AS actual_count, 7 AS expected_snapshot_count FROM SHIPMENT;

SELECT 'CARGO' AS table_name, COUNT(*) AS actual_count, 8 AS expected_snapshot_count FROM CARGO;

SELECT 'SHIPMENT_LEG' AS table_name, COUNT(*) AS actual_count, 11 AS expected_snapshot_count FROM SHIPMENT_LEG;

SELECT 'TRACKING_EVENT' AS table_name, COUNT(*) AS actual_count, 9 AS expected_snapshot_count FROM TRACKING_EVENT;

SELECT 'TRANSPORT_COST' AS table_name, COUNT(*) AS actual_count, 20 AS expected_snapshot_count FROM TRANSPORT_COST;

SELECT object_name, object_type, status FROM user_objects WHERE object_type IN ('FUNCTION','PROCEDURE','TRIGGER','VIEW') ORDER BY object_type, object_name;

SELECT name, type, line, position, text FROM user_errors ORDER BY name, sequence;

DECLARE
    n NUMBER;
BEGIN
    SELECT COUNT(*) INTO n FROM user_objects
    WHERE object_type IN ('FUNCTION','PROCEDURE','TRIGGER','VIEW') AND status <> 'VALID';
    IF n > 0 THEN RAISE_APPLICATION_ERROR(-20990, 'Invalid PL/SQL objects; inspect USER_ERRORS.'); END IF;
END;
/
