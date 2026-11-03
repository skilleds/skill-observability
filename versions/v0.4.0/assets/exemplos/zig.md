# Exemplo de instrumentação — Zig

> Verificado em: 2026-10-14 · fontes: https://github.com/open-telemetry/opentelemetry-zig (README, build.zig.zon), https://github.com/zig-o11y/opentelemetry-sdk (aviso "not maintained"), `schematize-zig` -> `references/observabilidade.md` §16.3 · **NADA compilado**: não há toolchain Zig na máquina de verificação. <!-- reverificar -->

Zig não tem SDK OpenTelemetry estável. Estado em 2026-10-14:

| Opção | Estado |
|---|---|
| `open-telemetry/opentelemetry-zig` | **alpha** (README: "not battle-tested"); sem tag nem release, só `main`; exige Zig >= 0.16.0; traces/métricas/logs, OTLP **HTTP/protobuf e HTTP/JSON** (sem gRPC); commit de referência `645ff36f6e43993b2f2ffd9ab197702e70e51e39` (2026-10-13) |
| `zig-o11y/opentelemetry-sdk` | **abandonado** (movido para o repo acima; última tag v0.2.0); não usar em código novo |

Rota recomendada, coerente com a §16.3 da `schematize-zig` (a rota é decisão de ADR):

1. **Piso (rota a): log JSON com `trace_id`/`span_id` + `/metrics` Prometheus.** Não depende de nenhum SDK; o Collector coleta stdout e faz scrape. Entrega RED e correlação.
2. **Traces (rota c): propague `traceparent` W3C** na entrada e saída e deixe o Collector/Beyla (eBPF) montar os spans HTTP. O `trace_id` atravessa o serviço mesmo sem SDK.
3. **SDK in-process só com ADR:** `zig fetch --save "git+https://github.com/open-telemetry/opentelemetry-zig#645ff36f6e43993b2f2ffd9ab197702e70e51e39"` (pin por commit, nunca branch) e, no `build.zig`, `exe.root_module.addImport("opentelemetry-sdk", dep.module("sdk"))`. Endpoint por `OTEL_EXPORTER_OTLP_ENDPOINT` (use `http://localhost:4318`, HTTP). Releia a API do README no commit pinado antes de escrever código: ela quebra entre commits e este exemplo não a reproduz de propósito.

## Log JSON com ids de trace (sem dependência)

Esboço do formato; a API de I/O do Zig mudou na 0.16, ajuste `writer` ao seu `std.Io`. <!-- reverificar -->

```zig
const std = @import("std");

/// Contexto W3C extraído do header `traceparent` (00-<trace_id 32 hex>-<span_id 16 hex>-<flags>).
pub const Ctx = struct { trace_id: [32]u8, span_id: [16]u8 };

pub fn parseTraceparent(h: []const u8) ?Ctx {
    if (h.len != 55 or h[2] != '-' or h[35] != '-' or h[52] != '-') return null;
    var c: Ctx = undefined;
    @memcpy(&c.trace_id, h[3..35]);
    @memcpy(&c.span_id, h[36..52]);
    return c;
}

/// Uma linha JSON por evento: nunca user_id, e-mail ou corpo de request.
pub fn logInfo(writer: anytype, ctx: ?Ctx, msg: []const u8, canal: []const u8) !void {
    try writer.print("{{\"level\":\"INFO\",\"msg\":\"{s}\",\"canal\":\"{s}\"", .{ msg, canal });
    if (ctx) |c| try writer.print(",\"trace_id\":\"{s}\",\"span_id\":\"{s}\"", .{ c.trace_id, c.span_id });
    try writer.writeAll("}\n");
}
```

`msg` e `canal` devem vir de constantes (enum), nunca de entrada externa sem escape JSON.

## Métricas e healthchecks

- `/metrics` em texto Prometheus: counter `pedidos_criados_total{canal}` e histograma `http_server_request_duration_seconds` com os buckets do semconv (0.005 ... 10), contadores sob atômica (`std.atomic.Value`).
- `/livez`: 200 sem tocar dependência. `/readyz`: 200 só se a dependência (banco/fila) responde dentro do timeout, senão 503.
