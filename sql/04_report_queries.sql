SET DEFINE OFF
SET SQLBLANKLINES ON
SET SERVEROUTPUT ON
WHENEVER SQLERROR EXIT SQL.SQLCODE ROLLBACK

SET LINESIZE 200
SET PAGESIZE 100

PROMPT 1. Customer directory
SELECT customer_id,customer_name,phone,email FROM customer ORDER BY customer_name;

PROMPT 2. Shipments awaiting departure
SELECT shipment_id,TO_CHAR(shipment_date,'DD-MM-YYYY') booked_on,shipment_status FROM shipment WHERE shipment_status='BOOKED' ORDER BY shipment_id;

PROMPT 3. Shipment customers and endpoints
SELECT s.shipment_id,c.customer_name,ho.hub_name origin,hd.hub_name destination FROM shipment s JOIN customer c ON c.customer_id=s.customer_id JOIN hub ho ON ho.hub_id=s.origin_hub_id JOIN hub hd ON hd.hub_id=s.destination_hub_id ORDER BY s.shipment_id;

PROMPT 4. Transport plan
SELECT sl.shipment_id,sl.leg_order,tm.mode_name,v.registration_number,hf.hub_name from_hub,ht.hub_name to_hub FROM shipment_leg sl JOIN transport_mode tm ON tm.mode_id=sl.mode_id JOIN vehicle v ON v.vehicle_id=sl.vehicle_id JOIN hub hf ON hf.hub_id=sl.from_hub_id JOIN hub ht ON ht.hub_id=sl.to_hub_id ORDER BY sl.shipment_id,sl.leg_order;

PROMPT 5. Cargo totals
SELECT s.shipment_id,COUNT(cg.cargo_id) cargo_records,NVL(SUM(cg.weight_kg*cg.quantity),0) total_weight_kg,NVL(SUM(cg.declared_value),0) total_value_inr FROM shipment s LEFT JOIN cargo cg ON cg.shipment_id=s.shipment_id GROUP BY s.shipment_id ORDER BY s.shipment_id;

PROMPT 6. Total transport cost
SELECT s.shipment_id,c.customer_name,NVL(SUM(tc.amount),0) total_cost FROM shipment s JOIN customer c ON c.customer_id=s.customer_id LEFT JOIN shipment_leg sl ON sl.shipment_id=s.shipment_id LEFT JOIN transport_cost tc ON tc.leg_id=sl.leg_id GROUP BY s.shipment_id,c.customer_name ORDER BY s.shipment_id;

PROMPT 7. Costs by transport mode
SELECT tm.mode_name,SUM(CASE WHEN tc.cost_type='BASE' THEN tc.amount ELSE 0 END) base_cost,SUM(CASE WHEN tc.cost_type='HANDLING' THEN tc.amount ELSE 0 END) handling_cost,SUM(tc.amount) total_cost FROM transport_mode tm JOIN shipment_leg sl ON sl.mode_id=tm.mode_id JOIN transport_cost tc ON tc.leg_id=sl.leg_id GROUP BY tm.mode_name ORDER BY tm.mode_name;

PROMPT 8. Multimodal shipments
SELECT s.shipment_id,c.customer_name,COUNT(DISTINCT sl.mode_id) modes_used FROM shipment s JOIN customer c ON c.customer_id=s.customer_id JOIN shipment_leg sl ON sl.shipment_id=s.shipment_id GROUP BY s.shipment_id,c.customer_name HAVING COUNT(DISTINCT sl.mode_id)>1 ORDER BY s.shipment_id;

PROMPT 9. Above-average shipment costs
SELECT s.shipment_id,c.customer_name,fn_shipment_total_cost(s.shipment_id) total_cost FROM shipment s JOIN customer c ON c.customer_id=s.customer_id WHERE fn_shipment_total_cost(s.shipment_id)>(SELECT AVG(fn_shipment_total_cost(shipment_id)) FROM shipment) ORDER BY total_cost DESC;

PROMPT 10. Fragile cargo shipments
SELECT s.shipment_id,c.customer_name FROM shipment s JOIN customer c ON c.customer_id=s.customer_id WHERE EXISTS (SELECT 1 FROM cargo cg WHERE cg.shipment_id=s.shipment_id AND cg.fragile_flag='Y') ORDER BY s.shipment_id;

PROMPT 11. Unassigned vehicles
SELECT v.vehicle_id,v.registration_number,v.vehicle_type FROM vehicle v WHERE NOT EXISTS (SELECT 1 FROM shipment_leg sl WHERE sl.vehicle_id=v.vehicle_id) ORDER BY v.vehicle_id;

PROMPT 12. Vehicle capacity usage per leg
SELECT sl.shipment_id,sl.leg_order,v.registration_number,v.capacity capacity_kg,fn_shipment_cargo_weight(sl.shipment_id) cargo_kg,ROUND(fn_shipment_cargo_weight(sl.shipment_id)/v.capacity*100,2) usage_pct FROM shipment_leg sl JOIN vehicle v ON v.vehicle_id=sl.vehicle_id ORDER BY sl.shipment_id,sl.leg_order;

PROMPT 13. Tracking history
SELECT sl.shipment_id,sl.leg_order,te.event_type,te.event_location,TO_CHAR(te.event_datetime,'DD-MM-YYYY HH24:MI:SS') event_time FROM tracking_event te JOIN shipment_leg sl ON sl.leg_id=te.leg_id ORDER BY sl.shipment_id,te.event_datetime,te.event_id;

PROMPT 14. Latest tracking event per shipment
SELECT shipment_id,event_type,event_location,TO_CHAR(event_datetime,'DD-MM-YYYY HH24:MI:SS') event_time FROM (SELECT sl.shipment_id,te.event_type,te.event_location,te.event_datetime,ROW_NUMBER() OVER (PARTITION BY sl.shipment_id ORDER BY te.event_datetime DESC,te.event_id DESC) rn FROM tracking_event te JOIN shipment_leg sl ON sl.leg_id=te.leg_id) WHERE rn=1 ORDER BY shipment_id;

PROMPT 15. Operator leg assignments
SELECT o.operator_name,COUNT(sl.leg_id) assigned_legs FROM operator o LEFT JOIN vehicle v ON v.operator_id=o.operator_id LEFT JOIN shipment_leg sl ON sl.vehicle_id=v.vehicle_id GROUP BY o.operator_id,o.operator_name ORDER BY assigned_legs DESC,o.operator_name;

PROMPT 16. Planned journey distance
SELECT s.shipment_id,c.customer_name,NVL(SUM(r.distance),0) total_distance_km FROM shipment s JOIN customer c ON c.customer_id=s.customer_id LEFT JOIN shipment_leg sl ON sl.shipment_id=s.shipment_id LEFT JOIN route r ON r.route_id=sl.route_id GROUP BY s.shipment_id,c.customer_name ORDER BY s.shipment_id;

PROMPT 17. Shipment cost ranking
SELECT shipment_id,customer_name,total_cost,DENSE_RANK() OVER (ORDER BY total_cost DESC) cost_rank FROM (SELECT s.shipment_id,c.customer_name,fn_shipment_total_cost(s.shipment_id) total_cost FROM shipment s JOIN customer c ON c.customer_id=s.customer_id) ORDER BY cost_rank,shipment_id;
