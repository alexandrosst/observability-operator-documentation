{{- define "helm.fullname" -}}
{{- if .Values.fullnameOverride }}
{{ .Values.fullnameOverride }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end -}}

{{- define "helm.labels" -}}
{{- $labels := dict 
  "helm.sh/chart" (printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" )
  "app.kubernetes.io/name" .Chart.Name
  "app.kubernetes.io/instance" .Release.Name
  "app.kubernetes.io/version" .Chart.AppVersion
  "app.kubernetes.io/managed-by" "Helm" }}
{{- toYaml $labels | nindent 0 }}
{{- end -}}

{{- define "helm.selectorLabels" -}}
{{- $labels := dict 
  "app.kubernetes.io/name" .Chart.Name
  "app.kubernetes.io/instance" .Release.Name }}
{{- toYaml $labels | nindent 0 }}
{{- end -}}

{{- define "otel-collector.fullname" -}}
{{ include "helm.fullname" . }}
{{- end -}}

{{- define "otel-collector.labels" -}}
{{ include "helm.labels" . | nindent 4 }}
{{- end -}}

{{- define "otel-collector.selectorLabels" -}}
{{ include "helm.selectorLabels" . | nindent 4 }}
{{- end -}}

{{- define "otel-collector.serviceAccountName" -}}
{{ default (include "otel-collector.fullname" .) .Values.serviceAccount.name }}
{{- end -}}