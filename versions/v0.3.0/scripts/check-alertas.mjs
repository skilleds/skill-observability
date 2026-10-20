#!/usr/bin/env node
// schematize-observability — gate das REGRAS DE ALERTA (Prometheus rule groups; references/alertas-slo.md).
//
// Motivo: alerta sem runbook, sem severidade, sem `for` ou em cima de label de cardinalidade infinita
// é ruído que esconde o alerta real; e "alerta de SLO" sem multi-window/multi-burn-rate dispara tarde
// demais (janela longa só) ou o tempo todo (janela curta só).
//
// Uso:    node check-alertas.mjs [arquivo.yaml | diretório]    (default: .)
//         Em diretório, examina *.yaml/*.yml/*.rules que tenham `groups:` no topo.
// Saída:  0 = passa · 1 = REPROVA · 2 = nada para verificar (nenhuma regra `alert:`), que NÃO é aprovação.
// Regras (por `alert:`):
//   runbook   annotations.runbook_url ausente/vazio
//   severity  labels.severity ausente/vazio
//   for       `for` ausente (um `for: 0m` EXPLÍCITO vale: é decisão escrita)
//   cardinal  expr usa label de alta cardinalidade em by()/without() ou em seletor {…}:
//             user_id, userid, email, client_ip, remote_addr, ip, url, uri, path, request_id,
//             trace_id, span_id, session_id
//   slo       alerta "de SLO" (nome com slo|burn, ou label/annotation `slo`) cuja expr não é
//             multi-window/burn-rate. HEURÍSTICA: exige (a) >= 2 janelas distintas — `[5m]`/`[1h]`
//             na expr OU sufixo em recording rule (`burnrate5m`, `:rate1h`) —, (b) `and` ligando-as e
//             (c) comparação `> <número>` (o multiplicador de budget, ex.: `> (14.4 * 0.001)`).
//             Não prova que o número está certo — só que a forma multi-window/multi-burn existe.
// Waiver: `# obs-ok: <motivo>` em qualquer linha do bloco da regra (do `- alert:` até a próxima regra),
//         COM o motivo. Waiver vale para todos os achados daquela regra.
// Limite: lê YAML com o js-yaml vendorizado (vendor/js-yaml.mjs, MIT); sem rede, sem node_modules.
import { readFileSync, readdirSync, statSync, existsSync } from "node:fs";
import { join, dirname } from "node:path";
import { fileURLToPath } from "node:url";

const aqui = dirname(fileURLToPath(import.meta.url));
const yaml = (await import(join(aqui, "vendor", "js-yaml.mjs"))).default;

const ALTA_CARD = ["user_id", "userid", "email", "client_ip", "remote_addr", "ip", "url", "uri", "path",
  "request_id", "trace_id", "span_id", "session_id"];

/** listar — arquivos de regra sob o alvo (arquivo único ou diretório recursivo). */
function listar(alvo) {
  const st = statSync(alvo);
  if (st.isFile()) return [alvo];
  const out = [];
  for (const e of readdirSync(alvo, { withFileTypes: true })) {
    if ([".git", "node_modules", "versions", "vendor"].includes(e.name)) continue;
    const p = join(alvo, e.name);
    if (e.isDirectory()) out.push(...listar(p));
    else if (/\.(ya?ml|rules)$/.test(e.name)) out.push(p);
  }
  return out;
}

/** labelsAltaCard — nomes de alta cardinalidade usados em by()/without() ou em matchers de seletor. */
export function labelsAltaCard(expr) {
  const achados = new Set();
  const tira = (s) => s.split(",").map((x) => x.trim().replace(/^["']|["']$/g, ""));
  for (const m of expr.matchAll(/\b(?:by|without)\s*\(([^)]*)\)/g)) {
    for (const n of tira(m[1])) if (ALTA_CARD.includes(n)) achados.add(n);
  }
  for (const m of expr.matchAll(/\{([^}]*)\}/g)) {
    for (const mm of m[1].matchAll(/([A-Za-z_][A-Za-z0-9_]*)\s*(?:=~|!~|!=|=)/g)) {
      if (ALTA_CARD.includes(mm[1])) achados.add(mm[1]);
    }
  }
  return [...achados];
}

/** ehSlo — alerta "de SLO": nome com slo|burn, ou label/annotation chamada `slo`. */
function ehSlo(r) {
  return /slo|burn/i.test(r.alert) || (r.labels && "slo" in r.labels) || (r.annotations && "slo" in r.annotations);
}

/** multiBurn — heurística documentada no cabeçalho: >=2 janelas distintas + `and` + comparação numérica. */
export function multiBurn(expr) {
  const janelas = new Set();
  for (const m of expr.matchAll(/\[(\d+[smhdw])(?::\d+[smhdw])?\]/g)) janelas.add(m[1]);
  for (const m of expr.matchAll(/(?:burn_?rate|[:_]rate)(\d+[smhdw])\b/gi)) janelas.add(m[1]);
  const temAnd = /\)\s*and\b|\band\b\s*\(?/i.test(expr) || /\band\b/i.test(expr);
  const temCmp = />\s*\(?\s*\d/.test(expr);
  return janelas.size >= 2 && temAnd && temCmp;
}

/** blocoDaRegra — texto bruto do bloco da regra, para localizar waiver. */
function blocoDaRegra(linhas, nome) {
  const i = linhas.findIndex((l) => new RegExp(`alert:\\s*["']?${nome.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")}["']?\\s*(#.*)?$`).test(l));
  if (i < 0) return { ini: 1, txt: "" };
  let j = i + 1;
  while (j < linhas.length && !/^\s*-\s+(alert|record):/.test(linhas[j])) j++;
  return { ini: i + 1, txt: linhas.slice(i, j).join("\n") };
}

const alvo = process.argv[2] ?? ".";
if (!existsSync(alvo)) { console.error(`✖ ${alvo} não existe — nada para verificar.`); process.exit(2); }

let totalAlertas = 0, erros = 0;
for (const arq of listar(alvo)) {
  const bruto = readFileSync(arq, "utf8");
  let doc;
  try { doc = yaml.load(bruto); } catch (e) {
    if (statSync(alvo).isFile()) { console.log(`✖ ${arq}: YAML inválido: ${e.message.split("\n")[0]}`); erros++; }
    continue;
  }
  if (!doc || !Array.isArray(doc.groups)) continue;
  const linhas = bruto.split("\n");
  for (const g of doc.groups) for (const r of g.rules ?? []) {
    if (!r.alert) continue;
    totalAlertas++;
    const { ini, txt } = blocoDaRegra(linhas, r.alert);
    const waiver = /#\s*obs-ok:\s*\S+/.test(txt);
    const achados = [];
    const expr = String(r.expr ?? "");
    if (!String(r.annotations?.runbook_url ?? "").trim()) achados.push(["runbook", "sem annotations.runbook_url — alerta sem runbook é ruído às 3h da manhã"]);
    if (!String(r.labels?.severity ?? "").trim()) achados.push(["severity", "sem labels.severity — o roteamento não sabe a quem acordar"]);
    if (r.for === undefined || r.for === null || r.for === "") achados.push(["for", "sem `for` (use `for: 0m` explícito se o disparo imediato é decisão)"]);
    const altas = labelsAltaCard(expr);
    if (altas.length) achados.push(["cardinal", `expr usa label de alta cardinalidade: ${altas.join(", ")}`]);
    if (ehSlo(r) && !multiBurn(expr)) achados.push(["slo", "alerta de SLO sem multi-window/multi-burn-rate (>= 2 janelas ligadas por `and` e comparação com o multiplicador do budget)"]);
    for (const [regra, msg] of achados) {
      if (waiver) console.log(`~ ${arq}:${ini} [${regra}] (waiver) ${r.alert}: ${msg}`);
      else { console.log(`✖ ${arq}:${ini} [${regra}] ${r.alert}: ${msg}`); erros++; }
    }
  }
}

if (totalAlertas === 0) { console.error(`✖ nenhuma regra \`alert:\` em ${alvo} — nada para verificar.`); process.exit(2); }
if (erros > 0) { console.log(`REPROVA: ${erros} achado(s) em ${totalAlertas} alerta(s).`); process.exit(1); }
console.log(`OK: ${totalAlertas} alerta(s) sem achados.`);
