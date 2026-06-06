{{- define "otel-collector.fullname" -}}
{{ .Release.Name }}-{{ .Chart.Name }}
{{- end -}}