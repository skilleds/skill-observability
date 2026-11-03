#!/usr/bin/env bash
# Valida os assets da observabilidade do piso 28/24: regras de fila no yaml (gate verde + 4 alertas com trace_lookup)
# e a tabela sinal -> operação do ops (JSON válido, cada operação começa por "ops"). Vermelho plantado: yaml sem DLQ.
set -euo pipefail
AQUI="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RAIZ="$(cd "$AQUI/.." && pwd)"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT INT TERM

cat >"$T/valida.mjs" <<'JS'
import { readFileSync } from "node:fs";
const [, , raiz, rulesPath] = process.argv;
const yaml = (await import(raiz + "/scripts/vendor/js-yaml.mjs")).default;
const doc = yaml.load(readFileSync(rulesPath, "utf8"));
const grupo = (doc.groups || []).find((g) => g.name === "fila-e-resiliencia");
if (!grupo) { console.error("grupo fila-e-resiliencia ausente"); process.exit(1); }
const exige = { FilaProfundidadeAlta: "queue_depth", FilaItemMaisAntigoVelho: "queue_oldest_item_age_seconds", DLQComItem: "queue_dlq_depth", OutboxLagAlto: "outbox_lag_seconds" };
let erros = 0;
for (const [nome, metrica] of Object.entries(exige)) {
  const r = grupo.rules.find((x) => x.alert === nome);
  if (!r) { console.error("alerta ausente: " + nome); erros++; continue; }
  if (!String(r.expr).includes(metrica)) { console.error(nome + ": expr sem " + metrica); erros++; }
  if (!r.for) { console.error(nome + ": sem for"); erros++; }
  if (!r.labels?.severity) { console.error(nome + ": sem severity"); erros++; }
  if (!r.annotations?.runbook_url) { console.error(nome + ": sem runbook_url"); erros++; }
  if (!/trace_id/.test(r.annotations?.trace_lookup || "")) { console.error(nome + ": annotation trace_lookup sem trace_id"); erros++; }
  if (/by \([^)]*trace_id/.test(String(r.expr))) { console.error(nome + ": trace_id como label na expr"); erros++; }
}
process.exit(erros ? 1 : 0);
JS

echo "== gate check-alertas no asset"
node "$AQUI/check-alertas.mjs" "$RAIZ/assets/alertas-slo.rules.yaml"
echo "== 4 alertas de fila com trace_lookup"
node "$T/valida.mjs" "$RAIZ" "$RAIZ/assets/alertas-slo.rules.yaml"

echo "== vermelho: yaml sem DLQ reprova"
grep -v "DLQComItem" "$RAIZ/assets/alertas-slo.rules.yaml" >"$T/sem-dlq.yaml"
if node "$T/valida.mjs" "$RAIZ" "$T/sem-dlq.yaml" 2>/dev/null; then echo "FALHA: yaml sem DLQ passou"; exit 1; fi

echo "== tabela sinal -> operação do ops"
node --input-type=module -e '
import { readFileSync } from "node:fs";
const d = JSON.parse(readFileSync(process.argv[1], "utf8"));
const obrig = ["logs","traces","metricas","alertas","saude","filas"];
for (const s of obrig) { const l = d.sinais.find((x) => x.sinal === s); if (!l) { console.error("sinal ausente: " + s); process.exit(1); } if (!/^ops /.test(l.operacao)) { console.error("operacao fora do ops: " + s); process.exit(1); } if (!l.argumentos.includes("--json")) { console.error("sem --json: " + s); process.exit(1); } }
' "$RAIZ/assets/sinal-operacao-ops.json"
echo "alertas-fila: ok"
