# Oracle Query Results

Captured from Oracle at 2026-10-29T00:32:49+05:30.

These are live results from all 17 report queries.

## 1. Customer directory

| CUSTOMER_ID | CUSTOMER_NAME | PHONE | EMAIL |
| --- | --- | --- | --- |
| 1 | Bengaluru Electronics | 9000000001 | orders@blr-electronics.example |
| 2 | Chennai Textiles | 9000000002 | dispatch@chennai-textiles.example |
| 5 | Delhi Auto Parts | 9000000005 | orders@delhi-auto.example |
| 4 | Hyderabad Pharma | 9000000004 | logistics@hyd-pharma.example |
| 3 | Mumbai Machinery | 9000000003 | shipping@mumbai-machinery.example |

5 row(s).

## 2. Shipments awaiting departure

| SHIPMENT_ID | BOOKED_ON | SHIPMENT_STATUS |
| --- | --- | --- |
| 1 | 20-10-2026 | BOOKED |
| 2 | 20-10-2026 | BOOKED |
| 3 | 20-10-2026 | BOOKED |
| 4 | 20-10-2026 | BOOKED |
| 5 | 20-10-2026 | BOOKED |

5 row(s).

## 3. Shipment customers and endpoints

| SHIPMENT_ID | CUSTOMER_NAME | ORIGIN | DESTINATION |
| --- | --- | --- | --- |
| 1 | Bengaluru Electronics | Bengaluru Warehouse | Mumbai Freight Terminal |
| 2 | Chennai Textiles | Chennai Freight Terminal | Mumbai Freight Terminal |
| 3 | Mumbai Machinery | Mumbai Port | Mumbai Freight Terminal |
| 4 | Hyderabad Pharma | Hyderabad Cargo Airport | Delhi Warehouse |
| 5 | Delhi Auto Parts | Delhi Cargo Airport | Delhi Warehouse |
| 8 | Delhi Auto Parts | Delhi Cargo Airport | Delhi Warehouse |
| 21 | Chennai Textiles | Chennai Freight Terminal | Mumbai Freight Terminal |

7 row(s).

## 4. Transport plan

| SHIPMENT_ID | LEG_ORDER | MODE_NAME | REGISTRATION_NUMBER | FROM_HUB | TO_HUB |
| --- | --- | --- | --- | --- | --- |
| 1 | 1 | ROAD | KA01AB1001 | Bengaluru Warehouse | Chennai Freight Terminal |
| 1 | 2 | RAIL | RAIL-FRT-001 | Chennai Freight Terminal | Mumbai Freight Terminal |
| 2 | 1 | ROAD | TN01CD2002 | Chennai Freight Terminal | Chennai Port |
| 2 | 2 | SEA | SEA-CARGO-001 | Chennai Port | Mumbai Port |
| 2 | 3 | ROAD | TN01CD2002 | Mumbai Port | Mumbai Freight Terminal |
| 3 | 1 | ROAD | KA01AB1001 | Mumbai Port | Mumbai Freight Terminal |
| 4 | 1 | AIR | AIR-CARGO-001 | Hyderabad Cargo Airport | Delhi Cargo Airport |
| 4 | 2 | ROAD | DL01EF3003 | Delhi Cargo Airport | Delhi Warehouse |
| 5 | 1 | ROAD | DL01EF3003 | Delhi Cargo Airport | Delhi Warehouse |
| 8 | 1 | ROAD | DL01EF3003 | Delhi Cargo Airport | Delhi Warehouse |
| 21 | 1 | RAIL | RAIL-FRT-001 | Chennai Freight Terminal | Mumbai Freight Terminal |

11 row(s).

## 5. Cargo totals

| SHIPMENT_ID | CARGO_RECORDS | TOTAL_WEIGHT_KG | TOTAL_VALUE_INR |
| --- | --- | --- | --- |
| 1 | 2 | 960 | 2850000 |
| 2 | 1 | 5000 | 800000 |
| 3 | 1 | 3000 | 1800000 |
| 4 | 1 | 480 | 1200000 |
| 5 | 1 | 2000 | 600000 |
| 8 | 1 | 500 | 150000 |
| 21 | 1 | 500 | 250000 |

7 row(s).

## 6. Total transport cost

| SHIPMENT_ID | CUSTOMER_NAME | TOTAL_COST |
| --- | --- | --- |
| 1 | Bengaluru Electronics | 39000 |
| 2 | Chennai Textiles | 56200 |
| 3 | Mumbai Machinery | 8500 |
| 4 | Hyderabad Pharma | 47500 |
| 5 | Delhi Auto Parts | 4750 |
| 8 | Delhi Auto Parts | 4000 |
| 21 | Chennai Textiles | 4500 |

7 row(s).

## 7. Costs by transport mode

| MODE_NAME | BASE_COST | HANDLING_COST | TOTAL_COST |
| --- | --- | --- | --- |
| AIR | 38000 | 3500 | 41500 |
| RAIL | 26500 | 1800 | 28300 |
| ROAD | 41000 | 7150 | 48150 |
| SEA | 42000 | 4500 | 46500 |

4 row(s).

## 8. Multimodal shipments

| SHIPMENT_ID | CUSTOMER_NAME | MODES_USED |
| --- | --- | --- |
| 1 | Bengaluru Electronics | 2 |
| 2 | Chennai Textiles | 2 |
| 4 | Hyderabad Pharma | 2 |

3 row(s).

## 9. Above-average shipment costs

| SHIPMENT_ID | CUSTOMER_NAME | TOTAL_COST |
| --- | --- | --- |
| 2 | Chennai Textiles | 56200 |
| 4 | Hyderabad Pharma | 47500 |
| 1 | Bengaluru Electronics | 39000 |

3 row(s).

## 10. Fragile cargo shipments

| SHIPMENT_ID | CUSTOMER_NAME |
| --- | --- |
| 1 | Bengaluru Electronics |
| 4 | Hyderabad Pharma |

2 row(s).

## 11. Unassigned vehicles

| VEHICLE_ID | REGISTRATION_NUMBER | VEHICLE_TYPE |
| --- | --- | --- |

0 row(s).

## 12. Vehicle capacity usage per leg

| SHIPMENT_ID | LEG_ORDER | REGISTRATION_NUMBER | CAPACITY_KG | CARGO_KG | USAGE_PCT |
| --- | --- | --- | --- | --- | --- |
| 1 | 1 | KA01AB1001 | 12000.0 | 960 | 8 |
| 1 | 2 | RAIL-FRT-001 | 500000.0 | 960 | 0.19 |
| 2 | 1 | TN01CD2002 | 16000.0 | 5000 | 31.25 |
| 2 | 2 | SEA-CARGO-001 | 10000000.0 | 5000 | 0.05 |
| 2 | 3 | TN01CD2002 | 16000.0 | 5000 | 31.25 |
| 3 | 1 | KA01AB1001 | 12000.0 | 3000 | 25 |
| 4 | 1 | AIR-CARGO-001 | 60000.0 | 480 | 0.8 |
| 4 | 2 | DL01EF3003 | 8000.0 | 480 | 6 |
| 5 | 1 | DL01EF3003 | 8000.0 | 2000 | 25 |
| 8 | 1 | DL01EF3003 | 8000.0 | 500 | 6.25 |
| 21 | 1 | RAIL-FRT-001 | 500000.0 | 500 | 0.1 |

11 row(s).

## 13. Tracking history

| SHIPMENT_ID | LEG_ORDER | EVENT_TYPE | EVENT_LOCATION | EVENT_TIME |
| --- | --- | --- | --- | --- |
| 1 | 1 | CHECKPOINT | Bengaluru Warehouse | 20-10-2026 09:00:00 |
| 2 | 1 | CHECKPOINT | Chennai Freight Terminal | 20-10-2026 09:00:00 |
| 3 | 1 | CHECKPOINT | Mumbai Port | 20-10-2026 09:00:00 |
| 4 | 1 | CHECKPOINT | Hyderabad Cargo Airport | 20-10-2026 09:00:00 |
| 5 | 1 | CHECKPOINT | Delhi Cargo Airport | 20-10-2026 09:00:00 |
| 8 | 1 | DEPARTED | Delhi Cargo Airport | 23-10-2026 01:06:51 |
| 8 | 1 | ARRIVED | Delhi Warehouse | 23-10-2026 01:10:04 |
| 21 | 1 | DEPARTED | Chennai Freight Terminal | 23-10-2026 12:10:12 |
| 21 | 1 | ARRIVED | Mumbai Freight Terminal | 23-10-2026 12:11:01 |

9 row(s).

## 14. Latest tracking event per shipment

| SHIPMENT_ID | EVENT_TYPE | EVENT_LOCATION | EVENT_TIME |
| --- | --- | --- | --- |
| 1 | CHECKPOINT | Bengaluru Warehouse | 20-10-2026 09:00:00 |
| 2 | CHECKPOINT | Chennai Freight Terminal | 20-10-2026 09:00:00 |
| 3 | CHECKPOINT | Mumbai Port | 20-10-2026 09:00:00 |
| 4 | CHECKPOINT | Hyderabad Cargo Airport | 20-10-2026 09:00:00 |
| 5 | CHECKPOINT | Delhi Cargo Airport | 20-10-2026 09:00:00 |
| 8 | ARRIVED | Delhi Warehouse | 23-10-2026 01:10:04 |
| 21 | ARRIVED | Mumbai Freight Terminal | 23-10-2026 12:11:01 |

7 row(s).

## 15. Operator leg assignments

| OPERATOR_NAME | ASSIGNED_LEGS |
| --- | --- |
| Swift Road Logistics | 7 |
| National Rail Freight | 2 |
| Ocean Freight Services | 1 |
| Sky Cargo Services | 1 |

4 row(s).

## 16. Planned journey distance

| SHIPMENT_ID | CUSTOMER_NAME | TOTAL_DISTANCE_KM |
| --- | --- | --- |
| 1 | Bengaluru Electronics | 1630 |
| 2 | Chennai Textiles | 2260 |
| 3 | Mumbai Machinery | 35 |
| 4 | Hyderabad Pharma | 1280 |
| 5 | Delhi Auto Parts | 30 |
| 8 | Delhi Auto Parts | 30 |
| 21 | Chennai Textiles | 1280 |

7 row(s).

## 17. Shipment cost ranking

| SHIPMENT_ID | CUSTOMER_NAME | TOTAL_COST | COST_RANK |
| --- | --- | --- | --- |
| 2 | Chennai Textiles | 56200 | 1 |
| 4 | Hyderabad Pharma | 47500 | 2 |
| 1 | Bengaluru Electronics | 39000 | 3 |
| 3 | Mumbai Machinery | 8500 | 4 |
| 5 | Delhi Auto Parts | 4750 | 5 |
| 21 | Chennai Textiles | 4500 | 6 |
| 8 | Delhi Auto Parts | 4000 | 7 |

7 row(s).
