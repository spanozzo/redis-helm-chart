{{/*
Chart name (for the app.kubernetes.io/name label).
*/}}
{{- define "redis.name" -}}
{{- .Chart.Name | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Release-qualified base name (e.g. "redis" when released as `redis`).
Truncated to 57 so the "-node" / "-headless" suffixes fit in 63.
*/}}
{{- define "redis.fullname" -}}
{{- .Release.Name | trunc 57 | trimSuffix "-" }}
{{- end }}

{{/*
StatefulSet / pod base name. Add "-node" suffix for Bitnami chart compatibility
*/}}
{{- define "redis.nodeName" -}}
{{- printf "%s-node" (include "redis.fullname" .) | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Headless service name.
*/}}
{{- define "redis.headlessName" -}}
{{- printf "%s-headless" (include "redis.fullname" .) | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "redis.serviceName" -}}
{{- printf "%s" (include "redis.fullname" .) | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "redis.metricsServiceName" -}}
{{- printf "%s-metrics" (include "redis.fullname" .) | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "redis.scriptsConfigMapName" -}}
{{- printf "%s-scripts" (include "redis.fullname" .) | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "redis.configConfigMapName" -}}
{{- printf "%s-config" (include "redis.fullname" .) | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Name of the user-provided Secret holding the redis password.
*/}}
{{- define "redis.secretName" -}}
{{- .Values.auth.existingSecret -}}
{{- end }}

{{- define "redis.secretPasswordKey" -}}
{{- .Values.auth.existingSecretPasswordKey -}}
{{- end }}

{{- define "redis.selectorLabels" -}}
app.kubernetes.io/name: {{ include "redis.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Standard labels.
*/}}
{{- define "redis.labels" -}}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{ include "redis.selectorLabels" . }}
{{- with .Values.commonLabels }}
{{ toYaml . }}
{{- end }}
{{- end }}

{{/*
FQDN of the headless service.
*/}}
{{- define "redis.headlessFQDN" -}}
{{- printf "%s.%s.svc.cluster.local" (include "redis.headlessName" .) .Release.Namespace }}
{{- end }}

{{/*
Validate replicaCount / quorum.
*/}}
{{- define "redis.validate" -}}
{{- if lt (int .Values.replicaCount) 3 -}}
{{- fail "replicaCount must be at least 3 for sentinel quorum" -}}
{{- end -}}
{{- if le (int .Values.replicaCount) (int .Values.pdb.minAvailable) -}}
{{- fail "pdb.minAvailable must be < than replicaCount" -}}
{{- end -}}
{{- if gt (int .Values.sentinel.quorum) (int .Values.replicaCount) -}}
{{- fail "sentinel.quorum cannot exceed replicaCount" -}}
{{- end -}}
{{- if and .Values.auth.enabled (not .Values.auth.existingSecret) -}}
{{- fail "auth.enabled requires auth.existingSecret to be set" -}}
{{- end -}}
{{- end }}
