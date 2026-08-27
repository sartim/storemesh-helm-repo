{{- define "storemesh-frontend.name" -}}
{{- default "storemesh-frontend" .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- define "storemesh-frontend.fullname" -}}
{{- default (include "storemesh-frontend.name" .) .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}
