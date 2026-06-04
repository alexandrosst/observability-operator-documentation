{{- define "otel-collector.fullname" -}}
{{ printf "%s-%s" .Release.Name "otel-collector" }}
{{- end -}}