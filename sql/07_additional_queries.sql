SET DEFINE OFF
SET LINESIZE 160
SET PAGESIZE 100

-- string
SELECT customer_id, UPPER(customer_name) AS uppercase_name,
       SUBSTR(customer_name, 1, 10) AS short_name,
       LENGTH(customer_name) AS name_length
FROM customer ORDER BY customer_id;

-- date
SELECT leg_id,
       TO_CHAR(departure_date,'YYYY-MM-DD HH24:MI:SS') departure,
       TO_CHAR(arrival_date,'YYYY-MM-DD HH24:MI:SS') arrival,
       ROUND((arrival_date-departure_date)*1440,2) duration_minutes
FROM shipment_leg WHERE arrival_date IS NOT NULL ORDER BY leg_id;

-- aggregate
SELECT COUNT(*) cost_records, SUM(amount) total_cost,
       ROUND(AVG(amount),2) average_cost,
       MIN(amount) minimum_cost, MAX(amount) maximum_cost
FROM transport_cost;

-- right
SELECT c.customer_id, c.customer_name, s.shipment_id
FROM shipment s RIGHT JOIN customer c
ON c.customer_id=s.customer_id ORDER BY c.customer_id,s.shipment_id;

-- cross
SELECT c.customer_name, m.mode_name
FROM customer c CROSS JOIN transport_mode m
WHERE c.customer_id=1 ORDER BY m.mode_id;

-- self
SELECT a.shipment_id, a.leg_order first_leg,
       b.leg_order next_leg, a.to_hub_id transfer_hub
FROM shipment_leg a JOIN shipment_leg b
ON b.shipment_id=a.shipment_id AND b.leg_order=a.leg_order+1
AND b.from_hub_id=a.to_hub_id ORDER BY a.shipment_id,a.leg_order;

-- in
SELECT customer_id, customer_name FROM customer
WHERE customer_id IN (SELECT customer_id FROM shipment
WHERE shipment_status='DELIVERED') ORDER BY customer_id;

-- correlated
SELECT s.shipment_id, s.customer_id,
       fn_shipment_total_cost(s.shipment_id) shipment_cost
FROM shipment s WHERE fn_shipment_total_cost(s.shipment_id) >
(SELECT AVG(fn_shipment_total_cost(s2.shipment_id)) FROM shipment s2
WHERE s2.customer_id=s.customer_id) ORDER BY s.shipment_id;

-- UNION
SELECT origin_hub_id AS hub_id FROM shipment
UNION
SELECT destination_hub_id FROM shipment ORDER BY hub_id;

-- INTERSECT
SELECT origin_hub_id AS hub_id FROM shipment
INTERSECT
SELECT destination_hub_id FROM shipment ORDER BY hub_id;

-- MINUS
SELECT origin_hub_id AS hub_id FROM shipment
MINUS
SELECT destination_hub_id FROM shipment ORDER BY hub_id;