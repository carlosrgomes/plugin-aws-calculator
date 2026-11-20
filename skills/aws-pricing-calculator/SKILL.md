---
name: aws-pricing-calculator
description: >-
  Especialista na Calculadora de Preços oficial da AWS (https://calculator.aws/#/)
  usando o servidor MCP aws-calculator-mcp (com Playwright/Chromium para cálculo
  oficial em USD). Use sempre que o usuário pedir estimativas de custo AWS, links
  oficiais da AWS Pricing Calculator, sizing de instâncias EC2/RDS/EKS/S3/Lambda,
  importação/edição de links calculator.aws/#/estimate?id=..., ou comparativos
  de custos (On-Demand vs Savings Plans vs Reserved vs Graviton, ou multi-região).
---

# AWS Pricing Calculator — Guia de Operação (`aws-calculator-mcp`)

Esta skill padroniza o uso do servidor MCP **`aws-calculator-mcp`** no mesmo padrão de rigor, descoberta dinâmica de schema e verificação de custos do `gcp-calculator-mcp`, adaptado para as particularidades da **AWS Pricing Calculator** (`https://calculator.aws/#/`).

---

## 1. Fluxo Obrigatório (Sempre seguir esta ordem)

Nunca chute `serviceCode` nem `fieldId` de memória. Siga rigorosamente os 4 passos:

1. **Descoberta de Serviços (`search_services`)**:
   - Pesquise no catálogo oficial (442 serviços) para obter a `service key` exata (ex.: `ec2Enhancement`, `amazonS3Standard`, `amazonRDSPostgreSQLDB`, `awsEks`, `aWSLambda`, `elasticLoadBalancing`, `aWSDataTransfer`).
2. **Inspeção de Schema (`get_service_fields`)**:
   - Chame `get_service_fields` com uma ou mais keys separadas por vírgula (ex.: `"ec2Enhancement, amazonS3Standard"`).
   - Verifique:
     - **IDs exatos** e **tipos** dos campos (`dropdown`, `numericInput`, `fileSize`, `workload`, `ec2AdvPricingStrategyV2`, etc.).
     - **Formato de unidades** para campos `fileSize` / `numericWithUnit`: sempre `{ "value": "<num>", "unit": "<unit>" }` (ex.: `{ "value": "50", "unit": "gb|NA" }` para EBS, `{ "value": "500", "unit": "gb|month" }` para S3).
     - **Escolha de AWS Free Tier (`freeTierChoice`)**: quando um serviço (como `aWSLambda`) expuser `includeFreeTier` vs `excludeFreeTier`, **prefira `excludeFreeTier` (ex.: `estimateFor: "lambdaWithoutFreeTier"`) para estimativas de produção/steady-state** e informe isso explicitamente nas premissas (ou pergunte ao usuário se quiser incluir o Free Tier).
     - **Redirecionamentos (`redirect_to_parent` / `redirect_to_provider`)**: respeite imediatamente quando o schema indicar o código filho correto.
3. **Criação da Estimativa (`build_estimate`)**:
   - Monte o array JSON de serviços em uma única chamada `build_estimate` (ou `create_estimate` + `add_service` + `validate_estimate` + `export_estimate` para cenários muito grandes).
   - Organize arquiteturas multi-serviço usando `"group"` lógico (ex.: `"Compute"`, `"Database"`, `"Storage"`, `"Networking"`).
   - Sempre preencha `"region"` e `"description"` clara em cada serviço.
4. **Cálculo e Verificação Oficial (`get_estimate_cost`)**:
   - Sempre que o usuário pedir custos, totais ou comparativos, chame **`get_estimate_cost`** com a `sharable_url` retornada pelo `build_estimate`.
   - **Verificação crítica obrigatória**: inspecione o campo `rows[].config` retornado pelo `get_estimate_cost` para confirmar que **quantidade de instâncias, tipo de máquina, região, storage e modelo de compra** bateram 100% com o solicitado (a calculadora AWS pode aplicar default silencioso se algum objeto composto estiver com formato incorreto). Se algo divergir, corrija e gere novamente antes de responder!

---

## 2. Edição e Clonagem de Estimativas Existentes

Para editar, ajustar sizing ou migrar região de um link `https://calculator.aws/#/estimate?id=...`:

1. Chame `import_estimate` com `format: "json"` passando a URL completa.
2. Analise os serviços, regiões e `calculationComponents` atuais.
3. Aplique as alterações desejadas e gere o novo link com `build_estimate`.
4. Chame `get_estimate_cost` na estimativa original (se necessário) e na nova estimativa.
5. Apresente uma **tabela comparativa (Antes × Depois)** com a diferença mensal (`USD/mês` e `%`) e o novo link oficial (`priced_estimate_url`).

---

## 3. Referência Rápida de Serviços e Armadilhas da AWS

| Necessidade | `service key` oficial | Atenção / Armadilhas conhecidas |
| :--- | :--- | :--- |
| **EC2 (VMs + EBS)** | `ec2Enhancement` | Sempre confirme `tenancy` (`shared`), `selectedOS` (`linux`, `windows`, `windows-std`, etc.), `instanceType`, `pricingStrategy` (`ondemand`, `spot`, `computeSavings1yrNoUpfront`, `instanceSavings3yrAllUpfront`, etc.), `storageType` (`Storage General Purpose gp3 GB Mo`) e `storageAmount`. **Confira sempre `Number of instances` no `get_estimate_cost`!** |
| **S3 (Object Storage)** | `amazonS3Standard`, `amazonS3StandardInfrequentAccess`, `amazonS3IntelligentTiering`, `amazonS3Glacier`, `amazonS3GlacierDeepArhive`, `s3GlacierInstantRetrieval` | Cada classe de armazenamento é uma service key separada. `s3StandardStorageSize` usa `{ "value": "...", "unit": "gb|month" }` ou `"tb|month"`. |
| **RDS (Bancos relacionais)** | `amazonRDSPostgreSQLDB`, `amazonRDSMySQLDB`, `amazonRDSMariaDB`, `amazonRdsForOracle`, `amazonRDSForSQLServer` | Cada engine é um serviço próprio. Sempre defina instância (`db.m6i.large`, `db.r6g.xlarge`, etc.), **Single-AZ vs Multi-AZ**, storage (`gp3`/`io1`) e backup storage. |
| **Aurora** | Pesquise com `search_services("aurora")` | Diferenciar Aurora Standard vs Aurora I/O-Optimized e Serverless v2 (ACUs). |
| **EKS (Kubernetes)** | `awsEks` | `awsEks` cobre o **control plane** (`numberOfEKSClusters`). Os **worker nodes** devem ser adicionados separadamente via `ec2Enhancement` ou Fargate (`awsFargate`), mais `elasticLoadBalancing` e `aWSDataTransfer`. |
| **Lambda (Serverless)** | `aWSLambda` | Exige `selectArchitectureRequests` (`x86` ou `arm64`) e `selectArchitectureConcurrency`. `numberOfRequests` e `sizeOfMemoryAllocated` usam `{ value, unit }`. Defina `estimateFor: "lambdaWithoutFreeTier"` para produção. |
| **Load Balancer (ALB/NLB)** | `elasticLoadBalancing` | Inclui Application Load Balancer (LCUs), Network Load Balancer (NLCUs) e Gateway Load Balancer. |
| **Data Transfer** | `aWSDataTransfer` | Sempre lembre de perguntar/incluir egresso para a Internet (Data Transfer Out), que frequentemente é o custo oculto em arquiteturas AWS. |

---

## 4. Guia de Dimensionamento EC2 & FinOps AWS (Equivalente ao `recommend_machine_type`)

Quando o usuário pedir sizing por vCPU/RAM sem informar a família de instância, recomende famílias de geração atual:

| Perfil de Workload | Famílias x86 (Intel/AMD) | Famílias Graviton (ARM — ~20% menor custo) | Uso típico |
| :--- | :--- | :--- | :--- |
| **Burstable / Dev / Baixo uso** | `t3`, `t3a` | `t4g` | Ambientes de dev/homolog, APIs leves, bastions |
| **Uso Geral (1:4 vCPU:RAM)** | `m7i`, `m7a`, `m6i` | `m8g`, `m7g` | Aplicações web, microsserviços, nodes EKS padrão |
| **Compute-Optimized (1:2)** | `c7i`, `c7a`, `c6i` | `c8g`, `c7g` | APIs CPU-bound, batch, gaming, transcodificação |
| **Memory-Optimized (1:8)** | `r7i`, `r7a`, `r6i` | `r8g`, `r7g` | Bancos de dados, Redis/Valkey, analytics em memória |
| **Storage-Optimized (NVMe)** | `i4i`, `i3en` | `im4gn`, `is4gen` | NoSQL de alto IOPS, Kafka, Elasticsearch/OpenSearch |
| **GPU / IA** | `g6`, `g5`, `p4d`, `p5` | — | Inferência LLM/visão (`g5`/`g6`), treinamento (`p4d`/`p5`) |

### Regiões de Referência
- `us-east-1` (N. Virginia) / `us-east-2` (Ohio): referência de menor custo e maior disponibilidade de serviços.
- `sa-east-1` (São Paulo): menor latência no Brasil; normalmente **30% a 60% mais cara** que `us-east-1` — sempre alertar o usuário quando comparar regiões.

### Alavancas de Otimização FinOps (sempre mencionar quando relevante)
1. **AWS Graviton (`m7g`/`c7g`/`r7g`)**: até ~20% de economia e melhor performance/watt em workloads Linux/containers/RDS compatíveis com ARM64.
2. **Compute / EC2 Savings Plans (1 ano ou 3 anos)**: ~30% a ~66% de desconto frente ao On-Demand para workloads previsíveis 24×7.
3. **EBS `gp3` em vez de `gp2`**: ~20% mais barato por GB com 3.000 IOPS e 125 MB/s inclusos.
4. **S3 Intelligent-Tiering ou Lifecycle para Glacier**: reduz drasticamente custos de dados frios sem retrabalho operacional.

---

## 5. Padrão de Entrega ao Usuário

Sempre apresente o resultado final de forma executiva e verificável:

1. **Link oficial clicável**: prefira `priced_estimate_url` (retornado por `get_estimate_cost`, que já abre com os valores calculados) ou `sharable_url`.
2. **Tabela de custos em USD**: Serviço, Região, Configuração resumida, Upfront, Mensal e Total 12 meses.
3. **Premissas assumidas**: região, horas/mês (padrão 730 h), modelo de compra (On-Demand/Savings Plans), Free Tier incluído ou excluído, e se Data Transfer/Backup/Support foram incluídos.
4. **Sugestões de otimização (1–3 bullets curtos)**: opções objetivas para reduzir o custo (ex.: Graviton, Savings Plans 1y/3y, `gp3`, etc.).
