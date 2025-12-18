{{/*
Helper to get secret value - supports both direct values and secret references
Usage: {{ include "control-plane.getSecretValue" (dict "value" .Values.controlPlane.secrets.openaiApiKey "secretName" "my-secret" "secretKey" "OPENAI_API_KEY" "context" $) }}
*/}}
{{- define "control-plane.getSecretValue" -}}
{{- $value := .value }}
{{- $secretName := .secretName }}
{{- $secretKey := .secretKey }}
{{- $context := .context }}
{{- $preserveSecrets := $context.Values.controlPlane.preserveExistingSecrets }}

{{- if kindIs "map" $value }}
  {{- /* Value is a secret reference object */}}
  {{- if and (hasKey $value "secretName") (hasKey $value "secretKey") }}
    {{- $refSecretName := $value.secretName }}
    {{- $refSecretKey := $value.secretKey }}
    {{- $refSecret := (lookup "v1" "Secret" $context.Release.Namespace $refSecretName) }}
    {{- if and $refSecret (hasKey $refSecret.data $refSecretKey) }}
      {{- /* Use value from referenced secret */}}
      {{- index $refSecret.data $refSecretKey | quote }}
    {{- else }}
      {{- /* Referenced secret doesn't exist, use empty string */}}
      {{- "" | b64enc | quote }}
    {{- end }}
  {{- else }}
    {{- /* Invalid secret reference format */}}
    {{- "" | b64enc | quote }}
  {{- end }}
{{- else }}
  {{- /* Value is a direct string - check if we should preserve existing secret */}}
  {{- $existingSecret := (lookup "v1" "Secret" $context.Release.Namespace $secretName) }}
  {{- if and $preserveSecrets $existingSecret (hasKey $existingSecret.data $secretKey) }}
    {{- /* Preserve existing value */}}
    {{- index $existingSecret.data $secretKey | quote }}
  {{- else if $value }}
    {{- /* Use provided value */}}
    {{- $value | b64enc }}
  {{- else }}
    {{- /* Empty value */}}
    {{- "" | b64enc | quote }}
  {{- end }}
{{- end }}

{{/*
Helper to render imagePullSecrets - supports string, array of strings, or array of objects
Usage: {{ include "control-plane.imagePullSecrets" (dict "value" .Values.controlPlane.imagePullSecrets) }}
*/}}
{{- define "control-plane.imagePullSecrets" -}}
{{- $value := .value }}
{{- if $value }}
{{- if kindIs "string" $value }}
{{- if ne $value "" }}
imagePullSecrets:
  - name: {{ $value }}
{{- end }}
{{- else if kindIs "slice" $value }}
{{- if gt (len $value) 0 }}
imagePullSecrets:
{{- range $value }}
  {{- if kindIs "string" . }}
  {{- if ne . "" }}
  - name: {{ . }}
  {{- end }}
  {{- else if kindIs "map" . }}
  {{- if hasKey . "name" }}
  {{- if ne .name "" }}
  - name: {{ .name }}
  {{- end }}
  {{- end }}
  {{- end }}
{{- end }}
{{- end }}
{{- else if kindIs "map" $value }}
{{- if hasKey $value "name" }}
{{- if ne $value.name "" }}
imagePullSecrets:
  - name: {{ $value.name }}
{{- end }}
{{- end }}
{{- end }}
{{- end }}
{{- end }}
{{- end }}

