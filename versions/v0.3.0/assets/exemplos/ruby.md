# Exemplo de instrumentação — Ruby

> Verificado em: 2026-10-14 · fontes: https://rubygems.org, https://opentelemetry.io/docs/languages/ruby/ · **executado** em `ruby:3.4-slim` (+ build-essential) com `OTEL_TRACES_EXPORTER=console`: span criado com resource correto; não executado contra Collector.

| Gem | Versão |
|---|---|
| `opentelemetry-sdk` | 1.13.1 |
| `opentelemetry-exporter-otlp` | 0.37.0 |
| `opentelemetry-instrumentation-all` | 0.98.0 |

Métricas e logs do SDK Ruby estão em Development (status 2026-10-14): para RED use `yabeda-prometheus` (`/metrics`) ou deixe o Collector derivar RED dos traces; log vai em JSON no stdout (`lograge`/`semantic_logger`) com `trace_id`. <!-- reverificar -->
`bigdecimal` (dependência do protobuf) compila extensão nativa: a imagem de build precisa de `gcc`/`make`.

```ruby
# Gemfile
gem "opentelemetry-sdk", "1.13.1"
gem "opentelemetry-exporter-otlp", "0.37.0"
gem "opentelemetry-instrumentation-all", "0.98.0"
```

```ruby
require "json"
require "opentelemetry/sdk"
require "opentelemetry/exporter/otlp"
require "opentelemetry/instrumentation/all"

# Endpoint vem de OTEL_EXPORTER_OTLP_ENDPOINT; resource por OTEL_RESOURCE_ATTRIBUTES + abaixo.
OpenTelemetry::SDK.configure do |c|
  c.service_name = "pedidos-api"
  c.service_version = "1.4.2"
  c.resource = OpenTelemetry::SDK::Resources::Resource.create(
    "deployment.environment.name" => ENV.fetch("APP_ENV", "dev")
  )
  c.use_all # Rails/Rack/Sidekiq/PG/Redis (auto-instrumentação)
end

TRACER = OpenTelemetry.tracer_provider.tracer("pedidos-api")

# Log JSON de uma linha com trace_id/span_id do span corrente.
module LogJson
  def self.info(msg, **campos)
    ctx = OpenTelemetry::Trace.current_span.context
    ids = ctx.valid? ? { trace_id: ctx.hex_trace_id, span_id: ctx.hex_span_id } : {}
    $stdout.puts({ ts: Time.now.utc.iso8601(3), level: "INFO", msg: msg }.merge(campos).merge(ids).to_json)
  end
end

TRACER.in_span("pedido.criar", attributes: { "pedido.canal" => "web" }) do
  LogJson.info("pedido_criado", canal: "web") # nunca user_id/e-mail
end
```

Healthchecks (Rails): `get "/livez" => proc { [200, {}, ["ok"]] }` (sem dependência) e `/readyz` rodando `ActiveRecord::Base.connection.execute("SELECT 1")` com rescue para 503. Em Rails, `use_all` + `config.filter_parameters` (sem PII no log).
