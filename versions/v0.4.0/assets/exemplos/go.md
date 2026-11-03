# Exemplo de instrumentação — Go

> Verificado em: 2026-10-14 · fontes: https://proxy.golang.org (versões), https://opentelemetry.io/docs/languages/go/ · **compilado** (go 1.24, `go build`); não executado contra Collector.

| Módulo | Versão |
|---|---|
| `go.opentelemetry.io/otel`, `otel/sdk`, `otel/sdk/metric`, `otel/trace`, `otel/metric` | v1.47.0 |
| `.../exporters/otlp/otlptrace/otlptracegrpc`, `.../otlpmetric/otlpmetricgrpc` | v1.47.0 |
| `go.opentelemetry.io/contrib/instrumentation/net/http/otelhttp` | v0.72.0 |
| `semconv/v1.40.0` (pacote dentro de `otel`) | — |

Logs: o SDK de logs do Go (`otel/sdk/log`, v1.47.0; `otlploggrpc` v0.23.0) ainda é Release Candidate; o caminho robusto é `log/slog` em JSON no stdout (abaixo) e o Collector coletar (`filelog`/stdout do container). <!-- reverificar -->

Variáveis: `OTEL_EXPORTER_OTLP_ENDPOINT=http://localhost:4317`, `OTEL_SERVICE_NAME`, `APP_ENV`.

```go
package main

import (
	"context"
	"log/slog"
	"net/http"
	"os"
	"time"

	"go.opentelemetry.io/contrib/instrumentation/net/http/otelhttp"
	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/attribute"
	"go.opentelemetry.io/otel/exporters/otlp/otlpmetric/otlpmetricgrpc"
	"go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracegrpc"
	"go.opentelemetry.io/otel/metric"
	"go.opentelemetry.io/otel/propagation"
	sdkmetric "go.opentelemetry.io/otel/sdk/metric"
	"go.opentelemetry.io/otel/sdk/resource"
	sdktrace "go.opentelemetry.io/otel/sdk/trace"
	semconv "go.opentelemetry.io/otel/semconv/v1.40.0"
	"go.opentelemetry.io/otel/trace"
)

// initOTel configura traces e métricas; o endpoint vem de OTEL_EXPORTER_OTLP_ENDPOINT.
func initOTel(ctx context.Context) (func(context.Context) error, error) {
	res, err := resource.New(ctx,
		resource.WithFromEnv(), // OTEL_RESOURCE_ATTRIBUTES, OTEL_SERVICE_NAME
		resource.WithAttributes(
			semconv.ServiceName("pedidos-api"),
			semconv.ServiceVersion("1.4.2"),
			attribute.String("deployment.environment.name", os.Getenv("APP_ENV")),
		))
	if err != nil {
		return nil, err
	}
	te, err := otlptracegrpc.New(ctx)
	if err != nil {
		return nil, err
	}
	tp := sdktrace.NewTracerProvider(sdktrace.WithBatcher(te), sdktrace.WithResource(res))
	me, err := otlpmetricgrpc.New(ctx)
	if err != nil {
		return nil, err
	}
	mp := sdkmetric.NewMeterProvider(sdkmetric.WithResource(res),
		sdkmetric.WithReader(sdkmetric.NewPeriodicReader(me, sdkmetric.WithInterval(15*time.Second))))
	otel.SetTracerProvider(tp)
	otel.SetMeterProvider(mp)
	otel.SetTextMapPropagator(propagation.NewCompositeTextMapPropagator(
		propagation.TraceContext{}, propagation.Baggage{}))
	return func(c context.Context) error { _ = mp.Shutdown(c); return tp.Shutdown(c) }, nil
}

// logger devolve slog JSON; cada registro leva trace_id/span_id do contexto.
type otelHandler struct{ slog.Handler }

func (h otelHandler) Handle(ctx context.Context, r slog.Record) error {
	if sc := trace.SpanContextFromContext(ctx); sc.IsValid() {
		r.AddAttrs(slog.String("trace_id", sc.TraceID().String()), slog.String("span_id", sc.SpanID().String()))
	}
	return h.Handler.Handle(ctx, r)
}

func main() {
	ctx := context.Background()
	shutdown, err := initOTel(ctx)
	if err != nil {
		slog.Error("otel_init_falhou", "erro", err.Error())
		os.Exit(1)
	}
	defer shutdown(ctx)
	log := slog.New(otelHandler{slog.NewJSONHandler(os.Stdout, nil)})

	meter := otel.Meter("pedidos-api")
	criados, _ := meter.Int64Counter("pedidos.criados", metric.WithUnit("{pedido}"))
	dur, _ := meter.Float64Histogram("pedidos.criacao.duracao", metric.WithUnit("s"))

	mux := http.NewServeMux()
	mux.HandleFunc("GET /livez", func(w http.ResponseWriter, _ *http.Request) { w.WriteHeader(http.StatusOK) })
	mux.HandleFunc("GET /readyz", func(w http.ResponseWriter, r *http.Request) {
		// readiness checa dependência (aqui: placeholder); liveness NÃO checa.
		w.WriteHeader(http.StatusOK)
	})
	mux.HandleFunc("POST /pedidos", func(w http.ResponseWriter, r *http.Request) {
		ctx, span := otel.Tracer("pedidos-api").Start(r.Context(), "pedido.criar")
		defer span.End()
		t0 := time.Now()
		span.SetAttributes(attribute.String("pedido.canal", "web")) // baixa cardinalidade
		criados.Add(ctx, 1, metric.WithAttributes(attribute.String("canal", "web")))
		log.InfoContext(ctx, "pedido_criado", "canal", "web") // nunca user_id/e-mail
		dur.Record(ctx, time.Since(t0).Seconds(), metric.WithAttributes(attribute.String("canal", "web")))
		w.WriteHeader(http.StatusCreated)
	})
	// otelhttp gera http.server.request.duration (semconv estável) com http.route.
	_ = http.ListenAndServe(":8080", otelhttp.NewHandler(mux, "http.server"))
}
```
