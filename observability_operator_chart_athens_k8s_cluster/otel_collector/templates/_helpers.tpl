{{- define "otel-collector.fullname" -}}
{{ .Release.Name }}-otel-collector
{{- end -}}

{{- define "otel-collector.chart" -}}
{{ .Chart.Name }}
{{- end -}}