# Exemplo de instrumentação — C#

> Verificado em: 2026-10-14 · fontes: https://www.nuget.org, https://opentelemetry.io/docs/languages/dotnet/ · **compilado** (`mcr.microsoft.com/dotnet/sdk:9.0-alpine`, `dotnet build`: 0 avisos, 0 erros); não executado contra Collector.

| Pacote NuGet | Versão |
|---|---|
| `OpenTelemetry.Exporter.OpenTelemetryProtocol` | 1.19.1 |
| `OpenTelemetry.Extensions.Hosting` | 1.19.1 |
| `OpenTelemetry.Instrumentation.AspNetCore` / `.Http` / `.Runtime` | 1.19.0 |

`UseOtlpExporter()` (namespace `OpenTelemetry`) liga traces, métricas e logs ao mesmo endpoint e lê `OTEL_EXPORTER_OTLP_ENDPOINT`. Traces, métricas e logs do .NET são Stable.

```csharp
using OpenTelemetry;
using System.Diagnostics;
using System.Diagnostics.Metrics;
using OpenTelemetry.Logs;
using OpenTelemetry.Metrics;
using OpenTelemetry.Resources;
using OpenTelemetry.Trace;

var builder = WebApplication.CreateBuilder(args);

// Endpoint vem de OTEL_EXPORTER_OTLP_ENDPOINT (UseOtlpExporter lê as variáveis padrão).
builder.Services.AddOpenTelemetry()
    .ConfigureResource(r => r
        .AddService("pedidos-api", serviceVersion: "1.4.2")
        .AddAttributes(new Dictionary<string, object>
        {
            ["deployment.environment.name"] = builder.Environment.EnvironmentName.ToLowerInvariant(),
        }))
    .WithTracing(t => t.AddAspNetCoreInstrumentation().AddHttpClientInstrumentation().AddSource(Telemetria.Nome))
    .WithMetrics(m => m.AddAspNetCoreInstrumentation().AddRuntimeInstrumentation().AddMeter(Telemetria.Nome))
    .UseOtlpExporter();

// Log JSON no stdout; ILogger inclui TraceId/SpanId do Activity corrente.
builder.Logging.ClearProviders().AddJsonConsole(o =>
{
    o.IncludeScopes = true;           // scope traz TraceId, SpanId, ParentId
    o.UseUtcTimestamp = true;
});
builder.Logging.Configure(o => o.ActivityTrackingOptions =
    ActivityTrackingOptions.TraceId | ActivityTrackingOptions.SpanId);

builder.Services.AddHealthChecks().AddCheck("db", () => Microsoft.Extensions.Diagnostics.HealthChecks.HealthCheckResult.Healthy(), tags: new[] { "ready" });

var app = builder.Build();
app.MapHealthChecks("/livez", new() { Predicate = _ => false });                 // liveness: sem dependência
app.MapHealthChecks("/readyz", new() { Predicate = c => c.Tags.Contains("ready") }); // readiness: dependências

app.MapPost("/pedidos", (ILogger<Program> log) =>
{
    var t0 = Stopwatch.GetTimestamp();
    using var span = Telemetria.Fonte.StartActivity("pedido.criar");
    span?.SetTag("pedido.canal", "web");                      // baixa cardinalidade
    Telemetria.Criados.Add(1, new KeyValuePair<string, object?>("canal", "web"));
    log.LogInformation("pedido_criado {Canal}", "web");        // nunca user_id/e-mail
    Telemetria.Duracao.Record(Stopwatch.GetElapsedTime(t0).TotalSeconds, new KeyValuePair<string, object?>("canal", "web"));
    return Results.Created();
});
app.Run();

static class Telemetria
{
    public const string Nome = "pedidos-api";
    public static readonly ActivitySource Fonte = new(Nome);
    static readonly Meter M = new(Nome);
    public static readonly Counter<long> Criados = M.CreateCounter<long>("pedidos.criados", "{pedido}");
    public static readonly Histogram<double> Duracao = M.CreateHistogram<double>("pedidos.criacao.duracao", "s");
}
```
