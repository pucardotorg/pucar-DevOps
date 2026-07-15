{{/*
Merges the per-environment override block (keyed by chart name, e.g. the
"acme-challenge:" block in environments/*.yaml or *-config.yaml) over this
chart's own values, mutating the shared .Values in place - mirrors
common.name / es-curator's "name" helper so namespace, serviceAccount, etc.
can be overridden per environment without touching values.yaml.
Must be called (e.g. via metadata.name) before any .Values.* overridable
field is read later in the same template file.
*/}}
{{- define "acme-challenge.name" -}}
{{- $envOverrides := index .Values (tpl (default .Chart.Name .Values.name) .) | default dict -}}
{{- $baseValues := .Values | deepCopy -}}
{{- $values := dict "Values" (mustMergeOverwrite $baseValues $envOverrides) -}}
{{- with mustMergeOverwrite . $values -}}
{{- default .Chart.Name .Values.name -}}
{{- end }}
{{- end }}

{{- define "acme-challenge.labels" -}}
app: {{ include "acme-challenge.name" . }}
{{- end }}
