#!/usr/bin/env bash

set -euo pipefail

context="${1:-}"
namespace="${2:-}"
style="safe"
prompt=""
lower_context=""

if [[ -z "${context}" ]]; then
	if ! command -v kubectl >/dev/null 2>&1; then
		exit 0
	fi
	context="$(kubectl config current-context 2>/dev/null || true)"
	namespace="$(kubectl config view --minify --output 'jsonpath={..namespace}' 2>/dev/null || true)"
fi

if [[ -z "${context}" ]]; then
	exit 0
fi

if [[ -n "${namespace}" ]]; then
	prompt="${context}/${namespace}"
else
	prompt="${context}"
fi

lower_context="$(printf '%s' "${context}" | tr '[:upper:]' '[:lower:]')"

case "${lower_context}" in
*prod* | *prd* | *live* | *online*) style="danger" ;;
*stage* | *stg* | *pre*) style="warn" ;;
esac

printf 'ZSH_SETUP_KUBE_CONTEXT=%q\n' "${context}"
printf 'ZSH_SETUP_KUBE_NAMESPACE=%q\n' "${namespace}"
printf 'ZSH_SETUP_KUBE_PROMPT=%q\n' "${prompt}"
printf 'ZSH_SETUP_KUBE_STYLE=%q\n' "${style}"
