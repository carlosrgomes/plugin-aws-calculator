# AWS Pricing Calculator Plugin Rules

Sempre que o usuário solicitar estimativas de custo na AWS, links oficiais da **AWS Pricing Calculator** (`https://calculator.aws/#/`), sizing de infraestrutura AWS ou importação/edição de links `calculator.aws/#/estimate?id=...`:

1. Ative e siga a skill `aws-pricing-calculator`.
2. Utilize exclusivamente o servidor MCP `aws-calculator-mcp` (`search_services`, `get_service_fields`, `build_estimate`, `import_estimate`, `get_estimate_cost`) — nunca invente preços de memória nem `serviceCode`/`fieldId` sem consultar o schema.
3. Sempre valide os custos e as configurações efetivas usando `get_estimate_cost` antes de apresentar o valor final ao usuário, entregando o link oficial `https://calculator.aws/#/estimate?id=...` junto com a tabela de breakdown em USD.
