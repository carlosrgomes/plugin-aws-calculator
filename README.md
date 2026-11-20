# AWS Pricing Calculator Plugin (`aws-calculator-mcp`)

🌐 **[English](#-english)** | **[Português (Brasil)](#-português-brasil)**

---

## 🇺🇸 English

Complete plugin for **Antigravity (`agy`)**, **Claude Code / Desktop**, and **Devin** that bundles:

1. **Official AWS Pricing Calculator MCP Server** ([`sample-aws-pricing-calculator-mcp`](https://www.npmjs.com/package/sample-aws-pricing-calculator-mcp) — 442 AWS services, no AWS credentials or login required).
2. **Automatic Playwright + Chromium installation** (inside `~/.cache/aws-calculator-mcp`) so `get_estimate_cost` computes and validates official AWS costs in USD directly in chat.
3. **Specialized `aws-pricing-calculator` Skill** (`skills/aws-pricing-calculator/SKILL.md`) and **routing rules** (`rules/AGENTS.md`) covering EC2/RDS/EKS/S3/Lambda sizing, AWS FinOps best practices (Graviton, Savings Plans, `gp3`), and mandatory cost verification.

### Plugin Structure

```text
aws-calculator-mcp/
├── plugin.json                        # Native Antigravity manifest
├── .antigravity-plugin/plugin.json    # Antigravity marketplace manifest
├── .claude-plugin/
│   ├── plugin.json                    # Claude Code plugin manifest
│   └── marketplace.json               # Claude Code marketplace entry
├── marketplace.json                   # Antigravity marketplace entry
├── mcp_config.json                    # Plugin MCP config (Antigravity)
├── .mcp.json                          # Plugin MCP config (Claude Code / Devin)
├── scripts/
│   ├── install.sh                     # 1-command installer (MCP + Playwright + Chromium + registration)
│   └── run-mcp.sh                     # Self-bootstrapping wrapper (installs on first run if missing)
├── skills/
│   └── aws-pricing-calculator/
│       └── SKILL.md                   # AWS Pricing Calculator expert skill
└── rules/
    └── AGENTS.md                      # Routing rule to enforce skill + MCP usage
```

### Prerequisites

- **Node.js 20+** (`node` and `npm` available in `PATH`)
- **macOS or Linux** (`bash`)

### Quick Install (Recommended — 1 Command)

Clone the repository and run the installer. It installs `sample-aws-pricing-calculator-mcp`, `playwright`, and **Chromium** into `~/.cache/aws-calculator-mcp`, and automatically registers the plugin/MCP in **Antigravity** and **Claude Code**:

```bash
git clone https://github.com/carlosrgomes/plugin-aws-calculator.git aws-calculator-mcp
cd aws-calculator-mcp
./scripts/install.sh
```

> **No `sudo` and no `npx` cache isolation issues**: the MCP server and Playwright are co-located in `~/.cache/aws-calculator-mcp`, ensuring `get_estimate_cost` always resolves Playwright and Chromium cleanly.

### Installation by Client

#### 1. Antigravity (`agy` CLI & IDE)

**Via installer script (installs full plugin: MCP + Skill + Rules + Playwright + Chromium):**

```bash
./scripts/install.sh
```

This links the plugin at `~/.gemini/config/plugins/aws-calculator-mcp`.

> If you previously registered a standalone `aws-calculator-mcp` entry in `agy mcp list`, remove it to avoid duplicates:
> ```bash
> agy mcp remove aws-calculator-mcp
> ```

**Or via `agy plugin install` (from a local path or Git URL):**

```bash
agy plugin install /absolute/path/to/aws-calculator-mcp
```

*(On the first tool call, `scripts/run-mcp.sh` automatically bootstraps the MCP server + Playwright + Chromium if not already present in `~/.cache/aws-calculator-mcp`.)*

#### 2. Claude Code & Claude Desktop

**Claude Code (CLI):**

`./scripts/install.sh` registers the MCP automatically in `user` scope. To register manually:

```bash
claude mcp add aws-calculator-mcp -s user -- bash /absolute/path/to/aws-calculator-mcp/scripts/run-mcp.sh
```

Verify connection:

```bash
claude mcp list
# aws-calculator-mcp: bash .../scripts/run-mcp.sh - ✔ Connected
```

You can also install this repository as a Claude Code plugin (`.claude-plugin/plugin.json` and `.mcp.json` are included).

**Claude Desktop:**

1. Open **Settings → Developer → Edit Config**:
   - **macOS**: `~/Library/Application Support/Claude/claude_desktop_config.json`
   - **Windows (WSL/Git Bash)**: `%APPDATA%\Claude\claude_desktop_config.json`
2. Add under `"mcpServers"`:

```json
{
  "mcpServers": {
    "aws-calculator-mcp": {
      "command": "bash",
      "args": ["/absolute/path/to/aws-calculator-mcp/scripts/run-mcp.sh"]
    }
  }
}
```

3. Save and restart Claude Desktop.

#### 3. Devin (Web & CLI)

**Devin CLI:**

Add to `~/.config/devin/mcp.json` (or `.mcp.json` in your project root):

```json
{
  "mcpServers": {
    "aws-calculator-mcp": {
      "command": "bash",
      "args": ["/absolute/path/to/aws-calculator-mcp/scripts/run-mcp.sh"]
    }
  }
}
```

**Devin Web (App):**

1. Go to **Customize → MCPs → Add MCP → Add custom MCP**.
2. Fill in:
   - **Server Name**: `aws-calculator-mcp`
   - **Transport**: `stdio` *(Command)*
   - **Command**: `bash`
   - **Arguments**: `/absolute/path/to/aws-calculator-mcp/scripts/run-mcp.sh` *(or, without cloning the repo, `Command: npx` with `Arguments: -y sample-aws-pricing-calculator-mcp@latest` — without Playwright cost rendering)*
   - **Authentication**: `None`
3. Save and click **Connect**.

### Available Tools (10 Tools)

| Tool | Description |
| :--- | :--- |
| `search_services` | Searches all 442 official AWS Pricing Calculator services and returns their `service keys`. |
| `get_service_fields` | Returns field IDs, types, `{ value, unit }` shapes, valid options, and Free Tier choices. |
| `build_estimate` | One-shot: creates an estimate, adds services (with groups), validates fields, saves to AWS, and returns the official `https://calculator.aws/#/estimate?id=...` URL. |
| `create_estimate` / `add_service` / `validate_estimate` / `export_estimate` | Granular workflow for large multi-group estimates or dry-run preflight validation. |
| `import_estimate` | Downloads any existing `https://calculator.aws/#/estimate?id=...` estimate in `json` or `markdown`. |
| `get_estimate_cost` | Opens the estimate via Playwright + headless Chromium and returns `monthly_cost`, `upfront_cost`, `total_12_months_cost`, per-service `rows[]`, and `priced_estimate_url`. |
| `get_server_info` | Displays server version, available tools, and supported partitions (`aws`, `aws-iso`, `aws-iso-b`, `aws-eusc`). |

### Example Prompts

- **Create a new estimate with verified costs**:
  > *"Build an AWS estimate in `us-east-1` with 2× `m7g.large` Linux EC2 instances (1-Year Compute Savings Plan) + 100 GB gp3 EBS each, 1× Multi-AZ RDS PostgreSQL `db.m6i.large`, and 1 TB S3 Standard. Give me the official link and full cost breakdown."*
- **Compare regions**:
  > *"Import `https://calculator.aws/#/estimate?id=...`, clone it to `sa-east-1` (São Paulo), and show the monthly cost comparison."*
- **Review and optimize an existing link**:
  > *"Read `https://calculator.aws/#/estimate?id=...` and suggest cost optimizations (Graviton, Savings Plans, gp3)."*

### Troubleshooting

- **Update MCP / Playwright to the latest version**:
  ```bash
  rm -rf ~/.cache/aws-calculator-mcp
  ./scripts/install.sh
  ```
- **Verify the wrapper starts cleanly**:
  ```bash
  echo '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test","version":"1.0"}}}' | bash scripts/run-mcp.sh
  ```

---

## 🇧🇷 Português (Brasil)

Plugin completo para **Antigravity (`agy`)**, **Claude Code / Desktop** e **Devin** que empacota:

1. **Servidor MCP oficial da Calculadora AWS** ([`sample-aws-pricing-calculator-mcp`](https://www.npmjs.com/package/sample-aws-pricing-calculator-mcp), 442 serviços, sem autenticação AWS).
2. **Instalação automática de Playwright + Chromium** (em `~/.cache/aws-calculator-mcp`) para que `get_estimate_cost` calcule e valide custos reais em USD diretamente no chat.
3. **Skill especialista `aws-pricing-calculator`** (`skills/aws-pricing-calculator/SKILL.md`) e **regras de roteamento** (`rules/AGENTS.md`) no padrão de qualidade do `gcp-calculator-mcp`, com sizing EC2/RDS/EKS/S3/Lambda, boas práticas FinOps (Graviton, Savings Plans, `gp3`) e validação obrigatória de custos.

### Estrutura do Plugin

```text
aws-calculator-mcp/
├── plugin.json                        # Manifesto nativo Antigravity
├── .antigravity-plugin/plugin.json    # Manifesto Antigravity (padrão marketplace)
├── .claude-plugin/
│   ├── plugin.json                    # Manifesto Claude Code
│   └── marketplace.json               # Marketplace Claude Code
├── marketplace.json                   # Marketplace Antigravity
├── mcp_config.json                    # Config MCP do plugin (Antigravity)
├── .mcp.json                          # Config MCP do plugin (Claude Code / Devin)
├── scripts/
│   ├── install.sh                     # Instalador 1 comando (MCP + Playwright + Chromium + registro)
│   └── run-mcp.sh                     # Wrapper auto-bootstrap (instala na 1ª execução se faltar)
├── skills/
│   └── aws-pricing-calculator/
│       └── SKILL.md                   # Skill especialista AWS Pricing Calculator
└── rules/
    └── AGENTS.md                      # Regra de roteamento para ativar skill + MCP
```

### Pré-requisitos

- **Node.js 20+** (`node` e `npm` no `PATH`)
- **macOS ou Linux** (`bash`)

### Instalação Rápida (Recomendado — 1 Comando)

Clone o repositório e execute o instalador. Ele instala `sample-aws-pricing-calculator-mcp`, `playwright` e o **Chromium** em `~/.cache/aws-calculator-mcp` e registra automaticamente o plugin/MCP no **Antigravity** e no **Claude Code**:

```bash
git clone https://github.com/carlosrgomes/plugin-aws-calculator.git aws-calculator-mcp
cd aws-calculator-mcp
./scripts/install.sh
```

> **Sem `sudo` e sem conflito de cache `npx`**: o MCP e o Playwright ficam colocalizados em `~/.cache/aws-calculator-mcp`, garantindo que `get_estimate_cost` encontre o Playwright e o Chromium sempre.

### Instalação por Ferramenta

#### 1. Antigravity (`agy` CLI e IDE)

**Via script (já instala plugin completo: MCP + Skill + Rules + Playwright + Chromium):**

```bash
./scripts/install.sh
```

O script cria o link do plugin em `~/.gemini/config/plugins/aws-calculator-mcp`.

> Se você tinha um servidor avulso `aws-calculator-mcp` em `agy mcp list`, remova-o para evitar duplicidade:
> ```bash
> agy mcp remove aws-calculator-mcp
> ```

**Ou via `agy plugin install` (a partir do diretório ou URL Git):**

```bash
agy plugin install /caminho/absoluto/para/aws-calculator-mcp
```

*(Na primeira chamada de ferramenta, `scripts/run-mcp.sh` baixa automaticamente o MCP + Playwright + Chromium caso ainda não estejam em `~/.cache/aws-calculator-mcp`.)*

#### 2. Claude Code e Claude Desktop

**Claude Code (CLI):**

O `./scripts/install.sh` já registra automaticamente o MCP no escopo `user`. Se preferir registrar manualmente:

```bash
claude mcp add aws-calculator-mcp -s user -- bash /caminho/absoluto/para/aws-calculator-mcp/scripts/run-mcp.sh
```

Verifique:

```bash
claude mcp list
# aws-calculator-mcp: bash .../scripts/run-mcp.sh - ✔ Connected
```

Você também pode instalar como plugin no Claude Code apontando para este repositório (`.claude-plugin/plugin.json` e `.mcp.json` já estão configurados).

**Claude Desktop:**

1. Abra **Settings → Developer → Edit Config**:
   - **macOS**: `~/Library/Application Support/Claude/claude_desktop_config.json`
   - **Windows (WSL/Git Bash)**: `%APPDATA%\Claude\claude_desktop_config.json`
2. Adicione em `"mcpServers"`:

```json
{
  "mcpServers": {
    "aws-calculator-mcp": {
      "command": "bash",
      "args": ["/caminho/absoluto/para/aws-calculator-mcp/scripts/run-mcp.sh"]
    }
  }
}
```

3. Salve e reinicie o Claude Desktop.

#### 3. Devin (Web e CLI)

**Devin CLI:**

Adicione em `~/.config/devin/mcp.json` (ou `.mcp.json` na raiz do projeto):

```json
{
  "mcpServers": {
    "aws-calculator-mcp": {
      "command": "bash",
      "args": ["/caminho/absoluto/para/aws-calculator-mcp/scripts/run-mcp.sh"]
    }
  }
}
```

**Devin Web (App):**

1. Acesse **Customize → MCPs → Add MCP → Add custom MCP**.
2. Configure:
   - **Server Name**: `aws-calculator-mcp`
   - **Transport**: `stdio` *(Command)*
   - **Command**: `bash`
   - **Arguments**: `/caminho/absoluto/para/aws-calculator-mcp/scripts/run-mcp.sh` *(ou, sem clonar o repo, `Command: npx` com `Arguments: -y sample-aws-pricing-calculator-mcp@latest` — neste modo sem Playwright)*
   - **Authentication**: `None`
3. Salve e clique em **Connect**.

### Ferramentas Disponíveis (10 Tools)

| Ferramenta | Descrição |
| :--- | :--- |
| `search_services` | Busca entre os 442 serviços oficiais da AWS Pricing Calculator e retorna as `service keys`. |
| `get_service_fields` | Retorna campos, tipos, unidades (`{ value, unit }`), opções válidas e escolha de Free Tier. |
| `build_estimate` | Cria a estimativa, adiciona serviços (com grupos), valida campos, salva na AWS e retorna o link oficial `https://calculator.aws/#/estimate?id=...`. |
| `create_estimate` / `add_service` / `validate_estimate` / `export_estimate` | Fluxo granular para estimativas grandes ou dry-run de validação antes de salvar. |
| `import_estimate` | Baixa qualquer link `https://calculator.aws/#/estimate?id=...` existente em `json` ou `markdown`. |
| `get_estimate_cost` | Abre a estimativa via Playwright + Chromium headless e devolve `monthly_cost`, `upfront_cost`, `total_12_months_cost`, breakdown `rows[]` e `priced_estimate_url`. |
| `get_server_info` | Exibe versão, ferramentas e partições suportadas (`aws`, `aws-iso`, `aws-iso-b`, `aws-eusc`). |

### Exemplos de Prompts

- **Nova estimativa com custos verificados**:
  > *"Monte uma calculadora AWS em `us-east-1` com 2 instâncias EC2 `m7g.large` Linux (1-Year Compute Savings Plan) + 100 GB EBS gp3 cada, 1 RDS PostgreSQL Multi-AZ `db.m6i.large` e 1 TB de S3 Standard. Me entregue o link oficial e a tabela de custos."*
- **Comparar regiões**:
  > *"Importe `https://calculator.aws/#/estimate?id=...`, clone para `sa-east-1` (São Paulo) e mostre o comparativo mensal entre as duas regiões."*
- **Revisar arquitetura existente**:
  > *"Leia o link `https://calculator.aws/#/estimate?id=...` e sugira otimizações de custo (Graviton, Savings Plans, gp3)."*

### Solução de Problemas

- **Atualizar para a versão mais recente do MCP / Playwright**:
  ```bash
  rm -rf ~/.cache/aws-calculator-mcp
  ./scripts/install.sh
  ```
- **Verificar se o wrapper inicia sem erro**:
  ```bash
  echo '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test","version":"1.0"}}}' | bash scripts/run-mcp.sh
  ```
