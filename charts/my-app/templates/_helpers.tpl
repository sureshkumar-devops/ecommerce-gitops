{{/*
Expand the name of the chart.
*/}}
{{- define "my-app.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "my-app.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "my-app.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels (Standard Prefix)
*/}}
{{- define "my-app.labels" -}}
helm.sh/chart: {{ include "my-app.chart" . }}
{{ include "my-app.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- if .Values.env }}
environment: {{ .Values.env }}
{{- end }}
{{- end }}

{{/*
Common labels (Alias for your HTTPRoute template)
*/}}
{{- define "chart.labels" -}}
{{ include "my-app.labels" . }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "my-app.selectorLabels" -}}
app.kubernetes.io/name: {{ include "my-app.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "my-app.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "my-app.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}



{{/* Service name for active deployment */}}
{{- define "my-app.serviceNameActive" -}}
{{ .Values.env }}-{{ include "my-app.name" . }}-svc-active
{{- end }}

{{/* Service name for preview deployment */}}
{{- define "my-app.serviceNamePreview" -}}
{{ .Values.env }}-{{ include "my-app.name" . }}-svc-preview
{{- end }}




{{/*
Return the jobName used in Prometheus queries.
*/}}
{{- define "my-app.jobName" -}}
{{- if eq .Values.env "prod" -}}
{{ index .Values.httpRoute.hostnames 0 }}
{{- else if eq .Values.env "staging" -}}
{{ .Values.analysis.prometheus.job }}
{{- else if eq .Values.env "dev" -}}
{{ .Values.analysis.prometheus.job | default (include "my-app.fullname" .) }}
{{- else -}}
{{ include "my-app.fullname" . }}
{{- end -}}
{{- end -}}
