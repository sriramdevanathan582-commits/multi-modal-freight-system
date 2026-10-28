SET DEFINE OFF
SET SQLBLANKLINES ON
SET SERVEROUTPUT ON
WHENEVER SQLERROR EXIT SQL.SQLCODE ROLLBACK

-- Only for a fresh schema: no existing user tables allowed.
DECLARE
    n NUMBER;
BEGIN
    SELECT COUNT(*) INTO n FROM user_tables;
    IF n > 0 THEN
        RAISE_APPLICATION_ERROR(-20991, 'Use an empty schema. Existing tables detected; installation stopped.');
    END IF;
END;
/
@@01_tables.sql
@@02_sample_data.sql
@@03_plsql_objects.sql
@@06_view_and_index.sql
@@05_verify.sql
PROMPT Installation scripts finished. Review the verification output.
