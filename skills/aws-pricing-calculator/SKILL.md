---
name: aws-pricing-calculator
description: >-
  Specialist for the official AWS Pricing Calculator (https://calculator.aws/#/)
  using the aws-calculator-mcp server (with Playwright/Chromium for official USD
  cost calculation). Use whenever the user requests AWS cost estimates, official
  AWS Pricing Calculator links, EC2/RDS/EKS/S3/Lambda sizing, importing/editing
  calculator.aws/#/estimate?id=... links, or cost comparisons (On-Demand vs
  Savings Plans vs Reserved vs Graviton, or multi-region).
---

# AWS Pricing Calculator — Operating Guide (`aws-calculator-mcp`)

This skill standardizes the use of the **`aws-calculator-mcp`** server with dynamic schema discovery, technical sizing, and mandatory cost verification on the official **AWS Pricing Calculator** (`https://calculator.aws/#/`).

---

## 1. Mandatory Workflow (Always Follow This Order)

Never guess `serviceCode` or `fieldId` from memory. Follow these 4 steps strictly:

1. **Service Discovery (`search_services`)**:
   - Search the official catalog (442 services) to get the exact `service key` (e.g., `ec2Enhancement`, `amazonS3Standard`, `amazonRDSPostgreSQLDB`, `awsEks`, `aWSLambda`, `elasticLoadBalancing`, `aWSDataTransfer`).
2. **Schema Inspection (`get_service_fields`)**:
   - Call `get_service_fields` with one or more comma-separated keys (e.g., `"ec2Enhancement, amazonS3Standard"`).
   - Check:
     - Exact **field IDs** and **types** (`dropdown`, `numericInput`, `fileSize`, `workload`, `ec2AdvPricingStrategyV2`, etc.).
     - **Unit shapes** for `fileSize` / `numericWithUnit` fields: always `{ "value": "<num>", "unit": "<unit>" }` (e.g., `{ "value": "50", "unit": "gb|NA" }` for EBS, `{ "value": "500", "unit": "gb|month" }` for S3).
     - **AWS Free Tier choice (`freeTierChoice`)**: when a service (such as `aWSLambda`) exposes `includeFreeTier` vs `excludeFreeTier`, **prefer `excludeFreeTier` (e.g., `estimateFor: "lambdaWithoutFreeTier"`) for production/steady-state estimates** and state this clearly in assumptions (or ask the user if they want the Free Tier included).
     - **Redirects (`redirect_to_parent` / `redirect_to_provider`)**: follow them immediately when the schema points to a verified child service code.
3. **Estimate Creation (`build_estimate`)**:
   - Build the JSON services array in a single `build_estimate` call (or use `create_estimate` + `add_service` + `validate_estimate` + `export_estimate` for very large architectures).
   - Organize multi-service architectures using logical `"group"` names (e.g., `"Compute"`, `"Database"`, `"Storage"`, `"Networking"`).
   - Always set `"region"` and a clear `"description"` for every service.
4. **Official Cost Calculation & Verification (`get_estimate_cost`)**:
   - Whenever the user asks for costs, totals, or comparisons, call **`get_estimate_cost`** with the `sharable_url` returned by `build_estimate`.
   - **Mandatory verification check**: inspect `rows[].config` returned by `get_estimate_cost` to verify that **instance count, instance type, region, storage, and pricing model** match the user's request 100% (the AWS calculator can silently apply defaults if a composite field has an unexpected shape). If anything differs, fix it and rebuild before replying.

---

## 2. Editing & Cloning Existing Estimates

To modify sizing, add/remove services, or migrate regions on an existing `https://calculator.aws/#/estimate?id=...` link:

1. Call `import_estimate` with `format: "json"` passing the full URL.
2. Inspect the current services, regions, and `calculationComponents`.
3. Apply the requested changes and generate the updated link with `build_estimate`.
4. Call `get_estimate_cost` on both the original (if needed) and updated estimates.
5. Present a **Before vs. After comparison table** showing the monthly delta (`USD/mo` and `%`) and the new official link (`priced_estimate_url`).

---

## 3. AWS Service Reference & Common Pitfalls

| Workload / Need | Official `service key` | Notes & Known Pitfalls |
| :--- | :--- | :--- |
| **EC2 (VMs + EBS)** | `ec2Enhancement` | Always specify `tenancy` (`shared`), `selectedOS` (`linux`, `windows`, `windows-std`, etc.), `instanceType`, `pricingStrategy` (`ondemand`, `spot`, `computeSavings1yrNoUpfront`, `instanceSavings3yrAllUpfront`, etc.), `storageType` (`Storage General Purpose gp3 GB Mo`), and `storageAmount`. **Always verify `Number of instances` in `get_estimate_cost`!** |
| **S3 (Object Storage)** | `amazonS3Standard`, `amazonS3StandardInfrequentAccess`, `amazonS3IntelligentTiering`, `amazonS3Glacier`, `amazonS3GlacierDeepArhive`, `s3GlacierInstantRetrieval` | Each storage class is its own service key. `s3StandardStorageSize` expects `{ "value": "...", "unit": "gb|month" }` or `"tb|month"`. |
| **RDS (Relational DBs)** | `amazonRDSPostgreSQLDB`, `amazonRDSMySQLDB`, `amazonRDSMariaDB`, `amazonRdsForOracle`, `amazonRDSForSQLServer` | Each database engine is a separate service. Always configure instance class (`db.m6i.large`, `db.r6g.xlarge`, etc.), **Single-AZ vs Multi-AZ**, storage (`gp3`/`io1`), and backup storage. |
| **Aurora** | Search via `search_services("aurora")` | Distinguish Aurora Standard vs Aurora I/O-Optimized, and Provisioned vs Serverless v2 (ACUs). |
| **EKS (Kubernetes)** | `awsEks` | `awsEks` covers the **control plane** (`numberOfEKSClusters`). Add **worker nodes** separately via `ec2Enhancement` or Fargate (`awsFargate`), plus `elasticLoadBalancing` and `aWSDataTransfer`. |
| **Lambda (Serverless)** | `aWSLambda` | Requires `selectArchitectureRequests` (`x86` or `arm64`) and `selectArchitectureConcurrency`. `numberOfRequests` and `sizeOfMemoryAllocated` require `{ value, unit }`. Set `estimateFor: "lambdaWithoutFreeTier"` for steady-state production. |
| **Load Balancer (ALB/NLB)** | `elasticLoadBalancing` | Covers Application Load Balancer (LCUs), Network Load Balancer (NLCUs), and Gateway Load Balancer. |
| **Data Transfer** | `aWSDataTransfer` | Always ask about or include Internet egress (Data Transfer Out), which is often a major hidden cost in AWS architectures. |

---

## 4. EC2 Sizing & AWS FinOps Guide

When the user specifies vCPU/RAM requirements without naming an instance family, recommend current-generation families:

| Workload Profile | x86 Families (Intel/AMD) | Graviton Families (ARM — ~20% better price-performance) | Typical Use Cases |
| :--- | :--- | :--- | :--- |
| **Burstable / Dev / Low CPU** | `t3`, `t3a` | `t4g` | Dev/staging environments, lightweight APIs, bastions |
| **General Purpose (1:4 vCPU:RAM)** | `m7i`, `m7a`, `m6i` | `m8g`, `m7g` | Web apps, microservices, standard EKS worker nodes |
| **Compute-Optimized (1:2)** | `c7i`, `c7a`, `c6i` | `c8g`, `c7g` | CPU-bound APIs, batch processing, gaming, media encoding |
| **Memory-Optimized (1:8)** | `r7i`, `r7a`, `r6i` | `r8g`, `r7g` | Databases, Redis/Valkey, in-memory analytics |
| **Storage-Optimized (NVMe)** | `i4i`, `i3en` | `im4gn`, `is4gen` | High-IOPS NoSQL, Kafka, Elasticsearch/OpenSearch |
| **GPU / AI** | `g6`, `g5`, `p4d`, `p5` | — | LLM/vision inference (`g5`/`g6`), model training (`p4d`/`p5`) |

### Reference Regions
- `us-east-1` (N. Virginia) / `us-east-2` (Ohio): lowest baseline pricing and broadest service availability.
- `sa-east-1` (São Paulo): lowest latency in South America; typically **30% to 60% more expensive** than `us-east-1` — always highlight this when comparing regions.

### FinOps Optimization Levers (Mention When Relevant)
1. **AWS Graviton (`m7g`/`c7g`/`r7g`)**: up to ~20% lower cost and better performance/watt for ARM64-compatible Linux/container/RDS workloads.
2. **Compute / EC2 Savings Plans (1-Year or 3-Year)**: ~30% to ~66% discount over On-Demand for steady 24×7 workloads.
3. **EBS `gp3` over `gp2`**: ~20% cheaper per GB with 3,000 IOPS and 125 MB/s included at no extra cost.
4. **S3 Intelligent-Tiering or Glacier Lifecycle**: cuts cold-data storage costs automatically without operational overhead.

---

## 5. Output Standard

Always deliver a clear, executive-ready, verifiable response:

1. **Clickable official link**: prefer `priced_estimate_url` (returned by `get_estimate_cost`, which opens with saved costs) or `sharable_url`.
2. **USD cost breakdown table**: Service, Region, Configuration Summary, Upfront, Monthly, and 12-Month Total.
3. **Assumptions**: region, hours/month (default 730 h), purchasing model (On-Demand/Savings Plans), Free Tier included vs. excluded, and whether Data Transfer/Backup/Support are included.
4. **Optimization suggestions (1–3 brief bullets)**: concrete levers to reduce cost (e.g., Graviton, 1y/3y Savings Plans, `gp3`, S3 tiering).
