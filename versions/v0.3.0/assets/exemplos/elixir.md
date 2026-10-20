# Exemplo de instrumentação — Elixir

> Verificado em: 2026-10-14 · fontes: https://hex.pm, https://opentelemetry.io/docs/languages/erlang/ · **resolvido via `mix deps.get`; sintaxe validada (`Code.string_to_quoted!`) e funções conferidas no código das deps; NÃO compilado** (a máquina de verificação não tem os headers de `public_key`, a dep `ssl_verify_fun` não compila). <!-- reverificar -->

| Pacote Hex | Versão |
|---|---|
| `opentelemetry_api` | == 1.5.0 |
| `opentelemetry` (SDK) | == 1.7.0 |
| `opentelemetry_exporter` | == 1.11.0 |
| `opentelemetry_phoenix` | == 2.0.1 |
| `opentelemetry_ecto` | == 1.2.0 |

Métricas: o SDK Erlang/Elixir ainda está em Development (página de status). Para RED use `/metrics` Prometheus (`telemetry_metrics_prometheus_core`/PromEx) ou deixe o span-metrics do Collector derivar RED dos traces. <!-- reverificar -->

```elixir
# mix.exs (deps)
{:opentelemetry_api, "== 1.5.0"},
{:opentelemetry, "== 1.7.0"},
{:opentelemetry_exporter, "== 1.11.0"},
{:opentelemetry_phoenix, "== 2.0.1"},
{:opentelemetry_ecto, "== 1.2.0"}

# config/runtime.exs  (endpoint: OTEL_EXPORTER_OTLP_ENDPOINT)
config :opentelemetry,
  resource: %{
    service: %{name: "pedidos-api", version: "1.4.2"},
    deployment: %{environment: %{name: System.get_env("APP_ENV", "dev")}}
  },
  span_processor: :batch,
  traces_exporter: :otlp,
  metrics_exporter: :none

config :opentelemetry_exporter, otlp_protocol: :grpc
```

```elixir
defmodule Pedidos.Application do
  use Application
  def start(_t, _a) do
    OpentelemetryPhoenix.setup(adapter: :bandit)   # ou :cowboy2
    OpentelemetryEcto.setup([:pedidos, :repo])
    :logger.add_primary_filter(:otel_ids, {&Pedidos.LogIds.filter/2, []})
    Supervisor.start_link([], strategy: :one_for_one)
  end
end

defmodule Pedidos.LogIds do
  @moduledoc "Anexa trace_id/span_id ao metadata de todo log (o formatter JSON os emite)."
  def filter(%{meta: meta} = event, _extra) do
    case :otel_tracer.current_span_ctx() do
      :undefined -> event
      ctx -> %{event | meta: Map.merge(meta, %{
               trace_id: :otel_span.hex_trace_id(ctx),
               span_id: :otel_span.hex_span_id(ctx)})}
    end
  end
end

defmodule Pedidos.Criar do
  require OpenTelemetry.Tracer, as: Tracer
  require Logger

  def run do
    Tracer.with_span "pedido.criar", %{attributes: %{"pedido.canal" => "web"}} do
      Logger.info("pedido_criado", canal: "web")   # nunca user_id/e-mail
      :ok
    end
  end
end
```

Formatter JSON: `logger_json` (`LoggerJSON.Formatters.Basic`) com `metadata: [:trace_id, :span_id, :request_id]`. Healthchecks: `/livez` é um `plug` que responde 200 sem dependência; `/readyz` roda `Ecto.Adapters.SQL.query(Repo, "SELECT 1")` com timeout e devolve 503.
