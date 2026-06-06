{{- define \"otel-collector.fullname\" -}}
{{- if .Release.Name }}{{ .Release.Name }}-otel-collector{{ else }}otel-collector{{ end }}
{{- end -}}

{{- define \"otel-collector.name\" -}}otel-collector{{- end -}}

{{- define \"otel-collector.chart\" -}}otel-collector{{- end -}}

{{- define \"otel-collector.labels\" -}}
app.kubernetes.io/name: {{ include \"otel-collector.name\" . }}
helm.sh/chart: {{ include \"otel-collector.chart\" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}

{{- define \"otel-collector.serviceAccountName\" -}}
{{- default (include \"otel-collector.fullname\" .) .Values.serviceAccount.name }}
{{- end -}}
