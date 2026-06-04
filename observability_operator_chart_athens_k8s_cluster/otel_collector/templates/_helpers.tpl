{{- define "otel-collector.fullname" -}}
{{- printf "%s-%s" .Release.Name "otel-collector" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "otel-collector.name" -}}
otel-collector
{{- end -}}

{{- define "otel-collector.labels" -}}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version | replace "+" "_" }}
app.kubernetes.io/name: {{ include "otel-collector.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}
