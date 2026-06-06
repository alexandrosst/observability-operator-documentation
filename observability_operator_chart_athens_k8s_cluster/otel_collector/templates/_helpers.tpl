{{- define "otel-collector.fullname" -}}
{{- $name := default .Chart.Name .Values.fullnameOverride -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end }}

{{- define "otel-collector.serviceAccountName" -}}
{{ include "otel-collector.fullname" . }}
{{- end }}

{{- define "otel-collector.labels" -}}
app.kubernetes.io/name: {{ include "otel-collector.fullname" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{- define "otel-collector.selectorLabels" -}}
app.kubernetes.io/name: {{ include "otel-collector.fullname" . }}
{{- end }}

{{- define "otel-collector.annotations" -}}
helm.sh/hook: pre-install,pre-upgrade
{{- end }}