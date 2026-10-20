# SLI/SLO, error budget, alertas e dashboards

> Parte da skill **schematize-observability**. Exemplo executável: `assets/alertas-slo.rules.yaml`.
> Gate: `scripts/check-alertas.mjs`.

## 1. SLI e SLO

- **SLI** = proporção de eventos bons sobre elegíveis, medida **do ponto de vista do usuário**:
  disponibilidade (respostas não-5xx / total), latência (respostas abaixo de X ms / total),
  frescor/correção para pipelines de dados. Um SLI por jornada que importa, não por componente.
- **SLO** = meta do SLI numa janela (ex.: 99,9% em 30 dias). Escrito em `/docs/slo.md` do serviço,
  com SLI, janela, meta, dono e política de budget. Sem SLO, alerta é chute.
- A meta é **menor que 100%** de propósito: 100% não existe, custa o infinito e impede de mudar.
  Dependência 99,9% não sustenta serviço 99,99%.
- Metas padrão de performance (p95/p99, startup): `schematize-engineering -> references/observabilidade.md` §30;
  o SLO específico do serviço sobrescreve.

## 2. Error budget

`budget = 1 - SLO` (99,9% = 0,1% de falhas permitidas na janela). Política escrita:

- budget saudável: ship normal;
- queimando rápido (alerta de página): para a feature, corrige;
- budget esgotado: **freeze de features** até recuperar (confiabilidade prioriza sobre feature);
- o relatório do budget entra na revisão de release.

## 3. Alertas: multi-window, multi-burn-rate

Alertar em "taxa de erro > X por 5 min" paga ruído (picos curtos) ou perde incidente lento.
O método da casa é o do SRE Workbook: alertar na **velocidade de queima do budget**, com **duas janelas**
(longa confirma que é significativo, curta confirma que ainda está acontecendo) — o que também faz o
alerta **parar de disparar logo após a correção**.

Para SLO 99,9% / 30 dias (budget 0,001):

| Severidade | Burn rate | Janela longa | Janela curta | Budget gasto | Ação |
|---|---|---|---|---|---|
| página | 14,4 | 1 h | 5 min | 2% | acorda alguém |
| página | 6 | 6 h | 30 min | 5% | acorda alguém |
| ticket | 3 | 1 d | 2 h | 10% | ticket no dia |
| ticket | 1 | 3 d | 6 h | 10% | ticket, sem urgência |

Expressão: `erro_longa > (burn * budget) and erro_curta > (burn * budget)`. Calcule a razão por recording
rule (`assets/alertas-slo.rules.yaml`), agregando por serviço — **sem** label de alta cardinalidade.
`scripts/check-alertas.mjs` reprova regra de SLO sem duas janelas.

## 4. Anatomia de um alerta aceitável

1. **Sintoma de usuário, não causa.** Alerta = "o usuário está sentindo" (burn rate, `/ready` do
   fleet inteiro caindo, fila sem drenar com idade crescente, certificado vencendo em N dias). "CPU a
   80%", "disco 70%", "pod reiniciou" são **causa/diagnóstico**: vão para dashboard e para o
   *drill-down* do runbook, não para a página. Exceção: saturação que *vai* virar sintoma sem ação (disco
   enchendo, cota de e-mail) com previsão (`predict_linear`) e severidade de ticket.
2. **`severity`** (`page` | `ticket`) obrigatório: decide o roteamento. Página só para o que exige ação humana imediata.
3. **`for`** explícito (evita flapping); `for: 0m` só com motivo escrito.
4. **`runbook_url`** em `annotations`, **para todo alerta**, apontando runbook que diz: o que significa,
   impacto, como confirmar (painel/trace/consulta), mitigação, escalonamento, quando fechar. Runbook
   se escreve e se testa pela `schematize-docs -> references/runbooks.md`. Alerta sem runbook é
   alerta que ninguém sabe tratar às 3h.
5. `summary`/`description` dizem **o que o usuário sente** e o valor medido.
6. **Acionável e dono:** se o plantonista não tem o que fazer, apague o alerta. Revise alerta que
   disparou e foi ignorado: ele ou vira ticket, ou some. Ruído esconde o alerta real.
7. **Versionado como código**, revisado em PR, entregue com o serviço (junto do chart/IaC), testado
   com `promtool test rules` quando possível.
8. **Hml não acorda ninguém** (roteia para canal), exceto violações de piso (`ambientes.md`).

## 5. Dashboards como código

- JSON/Jsonnet/Grafana Foundation SDK (ou o provisionamento por arquivo do Grafana) **no repo do
  serviço**, aplicado pelo pipeline; nada editado só na UI sem voltar para o git.
- Estrutura padrão por serviço: linha de **SLO/budget**, **RED**, **USE** (recursos e saturação),
  dependências, deploy/versão como anotação, e links para trace (exemplar), log e runbook.
- Variáveis (`$env`, `$service`, `$version`) de conjunto **limitado**; painel que consulta label de
  alta cardinalidade derruba o Grafana no mesmo jeito que derruba o Prometheus.
- Dashboard de negócio separado do técnico. Um dashboard nasce de template; o que é específico do
  serviço é o delta.
- Nenhum painel só de CPU: todo painel responde uma pergunta de operação.

## 6. On-call

Escala com dono, canal, matriz de escalonamento, pós-incidente sem culpa que termina com a **camada
implantada** (alerta/limite/teste), não com "vamos prestar atenção". Alerta SEV1/SEV2 disparado, papéis (IC, comms, escriba) e postmortem blameless: `schematize-incident`
(esta skill entrega o sinal e o runbook; a resposta é de lá). ADR: `schematize-docs`.
