# AWS Pricing Calculator Plugin Rules

Whenever the user asks for AWS cost estimates, official **AWS Pricing Calculator** links (`https://calculator.aws/#/`), AWS infrastructure sizing, or importing/editing `calculator.aws/#/estimate?id=...` links:

1. Activate and follow the `aws-pricing-calculator` skill.
2. Exclusively use the `aws-calculator-mcp` server (`search_services`, `get_service_fields`, `build_estimate`, `import_estimate`, `get_estimate_cost`) — never guess prices from memory or invent `serviceCode`/`fieldId` values without inspecting the schema first.
3. Always validate actual costs and effective configurations using `get_estimate_cost` before presenting the final totals to the user, delivering the official `https://calculator.aws/#/estimate?id=...` link together with a USD cost breakdown table.
