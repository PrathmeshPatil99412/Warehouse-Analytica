# Warehouse Analytica

Enterprise-grade PostgreSQL analytics platform for warehouse and supply-chain
intelligence, built with advanced SQL, query optimization, and BI reporting.

> Status: 🚧 In progress — Deliverables 1–8 complete (repo, schema, data pipeline,
> 50 analytics queries, views/matviews, procedures/triggers, performance engineering).
> Remaining: Power BI dashboard, FastAPI integration, documentation polish.

---

## Table of Contents

1. [Overview](#overview)
2. [Tech Stack](#tech-stack)
3. [Architecture](#architecture)
4. [Database Design](#database-design)
5. [Data Generation](#data-generation)
6. [Analytics Layer](#analytics-layer)
7. [Performance Engineering](#performance-engineering)
8. [Dashboard](#dashboard)
9. [API](#api)
10. [Getting Started](#getting-started)
11. [Repository Structure](#repository-structure)
12. [Interview Discussion Points](#interview-discussion-points)

---

## Overview

A simulated warehouse and supply-chain operation — multiple warehouses buying from
suppliers, selling to customers, and tracking inventory movement between them —
built to demonstrate depth in relational database design, advanced SQL, and query
performance optimization, with a thin API and BI layer on top to show the data
in action end to end.

## Tech Stack

| Layer | Choice |
|---|---|
| Database | PostgreSQL 18 |
| DB tooling | pgAdmin 4 |
| Language | Python 3.14 |
| Data generation | Faker, Pandas, NumPy |
| DB driver | psycopg 3 |
| Config | python-dotenv |
| Analytics | Raw SQL, Views, Materialized Views, Window Functions, Recursive CTEs |
| Performance | EXPLAIN ANALYZE, Composite/Partial/Covering Indexes, Range Partitioning |
| Backend | FastAPI (minimal — exposes KPIs, refreshes materialized views) |
| Dashboard | Power BI Desktop |
| Docs | Markdown (diagrams described as text, hand-drawn in Excalidraw) |

## Architecture



## Database Design



## Data Generation

Synthetic data generated with Faker, seeded (`SEED=42`) for reproducibility:

| Entity | Count |
|---|---|
| Warehouses | 10 |
| Products | 5,000 |
| Suppliers | 100 |
| Employees | 300 |
| Customers | 2,000 |
| Purchase orders | 20,000 (→ 69,530 line items) |
| Sales orders | 50,000 (→ 150,096 line items) |
| Inventory movements | 222,312 (derived from real order/transfer activity, not independently randomized) |

## Analytics Layer

- **50 business SQL queries** across 9 categories: sales, inventory, warehouse,
  supplier, customer analysis, window functions, recursive CTEs, KPIs, and case
  studies.
- **10 views** — live reads over the OLTP tables (inventory status, dead stock,
  order revenue, customer LTV, supplier performance, warehouse utilization, etc.)
- **5 materialized views** — cached aggregations refreshed on demand via
  `sp_refresh_dashboard()` (monthly sales, inventory snapshot, supplier metrics,
  dashboard KPIs, warehouse summary)
- **4 stored procedures** — receive inventory, transfer stock, create purchase
  order, refresh dashboard
- **3 triggers** — inventory non-negative check, auto-reserve on sale, auto-complete
  purchase order

## Performance Engineering

- **Real monthly range partitioning** on `inventory_movements` (44 partitions,
  Jan 2023 – Aug 2026 + a future catch-all)
- **16 indexes** — composite, partial, covering, and FK-support
- **Before/after benchmarks** (EXPLAIN ANALYZE):

| Query | Before | After | Improvement |
|---|---|---|---|
| Dead stock detection | 94.234 ms | 21.980 ms | ~4.3× |
| Warehouse movements (30d) | 54.150 ms | 0.344 ms | ~157× |
| Customer LTV ranking | 306.441 ms | 202.124 ms | ~1.5× |

- **Partition pruning confirmed** — EXPLAIN plan shows only 1 of 44 partitions
  scanned for a date-range query

## Dashboard


## API

Minimal FastAPI layer exposing analytics over the materialized views:

```
GET /dashboard/kpis
GET /inventory/current
GET /inventory/below-reorder
GET /analytics/products/top-selling
GET /analytics/warehouses/utilization
GET /analytics/suppliers/performance
POST /analytics/refresh-materialized-views
```

<!-- TODO: confirm final endpoint list once Deliverable 10 is complete -->

## Getting Started

```bash
# 1. Clone and configure
git clone <repo-url>
cd warehouse-analytics
copy .env.example .env   # edit credentials as needed

# 2. Install PostgreSQL 18 and create the database

# 3. Set up Python environment
python -m venv .venv
.venv\Scripts\activate
pip install -r requirements.txt

# 4. Generate synthetic data
cd data-generator
python generate_all.py
cd ..

# 5. Load data into PostgreSQL
python scripts/load_database.py
python scripts/derive_movements.py

# 6. Apply schema, indexes, and partitioning
psql -U warehouse_admin -d warehouse_analytics -f sql/ddl/01_schema.sql
psql -U warehouse_admin -d warehouse_analytics -f sql/ddl/04_partitioning.sql
psql -U warehouse_admin -d warehouse_analytics -f sql/ddl/03_indexes.sql

# 7. Create views, materialized views, procedures, and triggers
psql -U warehouse_admin -d warehouse_analytics -f sql/views/inventory_views.sql
# ... (repeat for remaining view/procedure/trigger files)

# 8. Run the API
uvicorn backend.app:app --reload
```

## Repository Structure

```
warehouse-analytics/
├── README.md
├── LICENSE
├── .gitignore
├── .gitattributes
├── requirements.txt
├── .env.example
├── docs/
├── sql/
│ ├── ddl/ # schema, indexes, partitioning
│ ├── views/
│ ├── materialized_views/
│ ├── procedures/
│ ├── triggers/
│ └── analytics/ # the 50 business queries, split by category
├── data-generator/
│ ├── config.py
│ ├── generate_all.py
│ ├── generators/
│ └── utils/
├── backend/
│ ├── app.py
│ ├── database.py
│ └── routers/
├── dashboard/
├── scripts/ # load_database, derive_movements, benchmark
└── tests/
```
