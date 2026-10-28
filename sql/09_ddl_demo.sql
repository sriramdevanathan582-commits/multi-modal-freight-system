-- Dedicated disposable table only. Stop if CREATE reports an existing name.
WHENEVER SQLERROR EXIT SQL.SQLCODE ROLLBACK
SET AUTOCOMMIT OFF
ROLLBACK;
CREATE TABLE report_ddl_demo (demo_id NUMBER PRIMARY KEY, description VARCHAR2(100));
ALTER TABLE report_ddl_demo ADD demo_status VARCHAR2(20);
DESC report_ddl_demo
INSERT INTO report_ddl_demo VALUES (1,'Report demonstration','READY');
COMMIT;
ROLLBACK;
SELECT * FROM report_ddl_demo;
TRUNCATE TABLE report_ddl_demo;
SELECT COUNT(*) remaining_rows FROM report_ddl_demo;
DROP TABLE report_ddl_demo PURGE;
SELECT table_name FROM user_tables WHERE table_name='REPORT_DDL_DEMO';
