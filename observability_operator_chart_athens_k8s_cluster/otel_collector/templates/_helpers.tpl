{{- define "otel-collector.fullname" -}}
{{- $name := default "otel-collector" .Values.fullnameOverride }}
{{- if .Release.Name }}{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}{{ else }}{{- $name | trunc 63 | trimSuffix "-" }}{{ end }}
{{- end }}

{{- define "otel-collector.name" -}}
{{- .Chart.Name }}
{{- end }}

{{- define "otel-collector.chart" -}}
{{ .Chart.Name }}-{{ .Chart.Version }}
{{- end }}

{{- define "otel-collector.serviceAccountName" -}}
{{ include "otel-collector.fullname" . }}
{{- end }}