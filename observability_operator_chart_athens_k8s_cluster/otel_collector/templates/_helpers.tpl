{{- define "otel-collector.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "otel-collector.fullname" -}}
{{- $name := default .Chart.Name .Values.fullnameOverride -}}
{{- if .Values.nameOverride }}{{- $name = .Values.nameOverride -}}{{- end -}}
{{- printf "%s-%s" $name .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "otel-collector.chart" -}}
{{ .Chart.Name }}-{{ .Chart.Version }}
{{- end -}}
