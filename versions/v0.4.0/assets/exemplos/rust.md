# Exemplo de instrumentação — Rust

> Verificado em: 2026-10-14 · fontes: https://crates.io, https://docs.rs/opentelemetry · **compilado** (cargo 1.96, `cargo build`); não executado contra Collector.

| Crate | Versão (pin exato) |
|---|---|
| `opentelemetry`, `opentelemetry_sdk` (feature `rt-tokio`) | =0.33.1 |
| `opentelemetry-otlp` (feature `grpc-tonic`; `http-proto` para OTLP/HTTP) | =0.33.1 |
| `opentelemetry-semantic-conventions` | =0.33.1 |
| `tracing-opentelemetry` | =0.34.0 |
| `opentelemetry-appender-tracing` (logs via OTLP, com trace_id/span_id automáticos) | 0.33.1 |

A API do Rust muda a cada minor: por isso o pin com `=`. Traces no SDK Rust são Beta e logs/métricas Stable na página de status do OpenTelemetry (2026-10-14). <!-- reverificar -->
O `fmt::layer().json()` do exemplo NÃO escreve `trace_id` sozinho: para correlação, use `opentelemetry-appender-tracing` (log vai por OTLP com os ids) ou um campo explícito no span.

```toml
# Cargo.toml
[dependencies]
opentelemetry = "=0.33.1"
opentelemetry_sdk = { version = "=0.33.1", features = ["rt-tokio"] }
opentelemetry-otlp = { version = "=0.33.1", features = ["grpc-tonic"] }
opentelemetry-semantic-conventions = "=0.33.1"
tracing = "0.1"
tracing-subscriber = { version = "0.3", features = ["json", "env-filter"] }
tracing-opentelemetry = "=0.34.0"
tokio = { version = "1", features = ["rt-multi-thread", "macros"] }
```

```rust
use opentelemetry::{global, trace::TracerProvider as _, KeyValue};
use opentelemetry_otlp::{MetricExporter, SpanExporter};
use opentelemetry_sdk::{metrics::SdkMeterProvider, trace::SdkTracerProvider, Resource};
use tracing_subscriber::{layer::SubscriberExt, util::SubscriberInitExt};

fn resource() -> Resource {
    Resource::builder()
        .with_service_name("pedidos-api")
        .with_attributes([
            KeyValue::new("service.version", "1.4.2"),
            KeyValue::new("deployment.environment.name", std::env::var("APP_ENV").unwrap_or_default()),
        ])
        .build()
}

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    // Endpoint vem de OTEL_EXPORTER_OTLP_ENDPOINT (lido pelo exporter).
    let tp = SdkTracerProvider::builder()
        .with_batch_exporter(SpanExporter::builder().with_tonic().build()?)
        .with_resource(resource())
        .build();
    let mp = SdkMeterProvider::builder()
        .with_periodic_exporter(MetricExporter::builder().with_tonic().build()?)
        .with_resource(resource())
        .build();
    global::set_tracer_provider(tp.clone());
    global::set_meter_provider(mp.clone());

    tracing_subscriber::registry()
        .with(tracing_opentelemetry::layer().with_tracer(tp.tracer("pedidos-api")))
        .with(tracing_subscriber::fmt::layer().json().with_current_span(true))
        .init();

    let meter = global::meter("pedidos-api");
    let criados = meter.u64_counter("pedidos.criados").with_unit("{pedido}").build();
    let dur = meter.f64_histogram("pedidos.criacao.duracao").with_unit("s").build();

    let t0 = std::time::Instant::now();
    {
        let span = tracing::info_span!("pedido.criar", pedido.canal = "web");
        let _g = span.enter();
        criados.add(1, &[KeyValue::new("canal", "web")]);
        tracing::info!(canal = "web", "pedido_criado");
    }
    dur.record(t0.elapsed().as_secs_f64(), &[KeyValue::new("canal", "web")]);

    tp.shutdown()?;
    mp.shutdown()?;
    Ok(())
}
```

Healthchecks (axum): `/livez` responde 200 sem tocar dependência; `/readyz` faz `SELECT 1` com timeout curto e devolve 503 se falhar.
