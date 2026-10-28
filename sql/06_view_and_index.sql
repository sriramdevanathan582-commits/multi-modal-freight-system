SET DEFINE OFF
WHENEVER SQLERROR EXIT SQL.SQLCODE ROLLBACK
CREATE OR REPLACE VIEW vw_shipment_summary AS
SELECT s.shipment_id, c.customer_name, s.shipment_status,
       fn_shipment_total_cost(s.shipment_id) AS total_cost_inr,
       fn_shipment_cargo_weight(s.shipment_id) AS total_weight_kg
FROM shipment s JOIN customer c ON c.customer_id = s.customer_id
WITH READ ONLY;

CREATE INDEX idx_shipment_customer ON shipment(customer_id);
