{{- define "storemesh-bff.name" -}}
{{- default "storemesh-bff" .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- define "storemesh-bff.fullname" -}}
{{- default (include "storemesh-bff.name" .) .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}
