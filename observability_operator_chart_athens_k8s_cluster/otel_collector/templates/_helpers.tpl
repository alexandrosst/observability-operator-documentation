{{- define "otel-collector.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "otel-collector.chart" -}}
{{ .Chart.Name }}-{{ .Chart.Version }}
{{- end -}}
