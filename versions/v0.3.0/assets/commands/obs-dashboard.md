---
description: schematize-observability — cria ou audita dashboard como código (SLO/budget, RED, USE, dependências, links para trace/log/runbook), versionado no repo do serviço
argument-hint: "[serviço]"
---

# /obs-dashboard — dashboard é código, não clique

1. **Estrutura padrão:** linha de **SLO e budget** -> **RED** -> **USE/saturação** -> dependências ->
   anotação de deploy/versão. Cada painel responde uma pergunta de operação.
2. **Ligações:** exemplar do histograma -> trace; trace -> log por `trace_id`; alerta -> dashboard -> runbook.
3. **Variáveis** (`$env`, `$service`, `$version`) de conjunto limitado; nada consultando label de alta
   cardinalidade.
4. **Como código:** JSON/Jsonnet/Foundation SDK no repo do serviço, provisionado pelo pipeline; edição na UI
   só volta ao git. Negócio separado do técnico.
5. **Visual gerado não é assunto desta skill:** dashboard é dado/JSON. Se o pedido incluir imagem ou
   arte, siga a regra de mídia da casa — imagem nunca pelo Claude: detecte Codex/Gemini e **pergunte
   qual usar**; sem nenhum, avise que visual gerado pelo Claude sai ruim e ofereça alternativas
   (instalar Codex/Gemini, banco de imagem com licença comercial, asset do cliente).
6. Referência: `references/slo-alertas.md` §5; para gráficos em artefato/relatório, a skill `dataviz`.
