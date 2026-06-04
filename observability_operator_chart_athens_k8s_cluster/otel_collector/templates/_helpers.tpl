{{- define "otel-collector.fullname" -}}
{{- printf "%s-%s" .Release.Name "otel-collector" | trunc 63 | trimSuffix "-" -}}
{{- end }}

{{- define "otel-collector.name" -}}
otel-collector
{{- end }}

{{- define "otel-collector.chart" -}}
{{ .Chart.Name }}
{{- end }}
