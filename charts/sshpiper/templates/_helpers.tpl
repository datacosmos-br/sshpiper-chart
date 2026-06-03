{{/*
Expand the name of the chart.
*/}}
{{- define "sshpiper.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "sshpiper.fullname" -}}
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
{{- define "sshpiper.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "sshpiper.labels" -}}
helm.sh/chart: {{ include "sshpiper.chart" . }}
{{ include "sshpiper.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "sshpiper.selectorLabels" -}}
app.kubernetes.io/name: {{ include "sshpiper.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "sshpiper.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- $name := printf "%s-reader" (include "sshpiper.fullname" .) }}
{{- default $name .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Whether the "full" image (all plugins) is required.
True when image.full is set, vault or failtoban is enabled, or any enabled plugin
is not part of the slim image (slim ships only kubernetes + workingdir).
Outputs the string "true" or "false".
*/}}
{{- define "sshpiper.needsFull" -}}
{{- $full := false -}}
{{- if .Values.image.full -}}{{- $full = true -}}{{- end -}}
{{- if .Values.sshpiper.vault.enabled -}}{{- $full = true -}}{{- end -}}
{{- if .Values.sshpiper.failtoban.enabled -}}{{- $full = true -}}{{- end -}}
{{- range .Values.sshpiper.plugins -}}
{{- if .enabled -}}
{{- if not (or (eq .name "kubernetes") (eq .name "workingdir")) -}}{{- $full = true -}}{{- end -}}
{{- end -}}
{{- end -}}
{{- $full -}}
{{- end -}}

{{/*
Image tag: explicit override wins, otherwise the chart appVersion, prefixed with
"full-" when the full image is required.
*/}}
{{- define "sshpiper.imageTag" -}}
{{- if .Values.image.tag -}}
{{- .Values.image.tag -}}
{{- else if eq (include "sshpiper.needsFull" .) "true" -}}
{{- printf "full-%s" .Chart.AppVersion -}}
{{- else -}}
{{- .Chart.AppVersion -}}
{{- end -}}
{{- end -}}

{{/*
Whether any enabled yaml plugin needs a mounted inline config (config or existingConfigMap).
Outputs "true" / "false".
*/}}
{{- define "sshpiper.yamlConfigEnabled" -}}
{{- $found := false -}}
{{- range .Values.sshpiper.plugins -}}
{{- if and .enabled (eq .name "yaml") (or .config .existingConfigMap) -}}{{- $found = true -}}{{- end -}}
{{- end -}}
{{- $found -}}
{{- end -}}

{{/*
Container arguments.
Honour argsOverride, otherwise build the declarative plugin pipeline: each enabled
plugin (in order) becomes its binary path plus its args, chained with "--".
The yaml plugin gets "--config <mounted path>" when it carries a config.
failtoban (legacy toggle) is appended last when enabled.
*/}}
{{- define "sshpiper.containerArgs" -}}
{{- if .Values.sshpiper.argsOverride -}}
{{- toYaml .Values.sshpiper.argsOverride -}}
{{- else -}}
{{- $args := list -}}
{{- $first := true -}}
{{- range .Values.sshpiper.plugins -}}
{{- if .enabled -}}
{{- if not $first -}}{{- $args = append $args "--" -}}{{- end -}}
{{- $first = false -}}
{{- $args = append $args (printf "/sshpiperd/plugins/%s" .name) -}}
{{- if and (eq .name "yaml") (or .config .existingConfigMap) -}}
{{- $args = append $args "--config" -}}
{{- $args = append $args "/etc/sshpiper/plugins/yaml/config.yaml" -}}
{{- /* ConfigMap mounts are 0644; skip the plugin's own perm check */ -}}
{{- $args = append $args "--no-check-perm" -}}
{{- end -}}
{{- range .args -}}{{- $args = append $args . -}}{{- end -}}
{{- end -}}
{{- end -}}
{{- if .Values.sshpiper.failtoban.enabled -}}
{{- if not $first -}}{{- $args = append $args "--" -}}{{- end -}}
{{- $args = append $args "/sshpiperd/plugins/failtoban" -}}
{{- end -}}
{{- toYaml $args -}}
{{- end -}}
{{- end -}}
