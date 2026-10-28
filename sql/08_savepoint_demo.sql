-- Run manually as FREIGHT, one section at a time. Finish pending work first.
SET AUTOCOMMIT OFF
SAVEPOINT before_demo;
UPDATE customer SET phone='9000000088' WHERE customer_id=1;
SAVEPOINT after_phone;
UPDATE customer SET customer_name='Temporary Demo Name' WHERE customer_id=1;
SELECT customer_id,customer_name,phone FROM customer WHERE customer_id=1;
ROLLBACK TO after_phone;
SELECT customer_id,customer_name,phone FROM customer WHERE customer_id=1;
ROLLBACK TO before_demo;
ROLLBACK;
-- Separate two-session instructions: see DEMONSTRATIONS.md.
