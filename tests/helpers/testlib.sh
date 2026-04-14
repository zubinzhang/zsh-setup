#!/usr/bin/env bash

set -euo pipefail
TEST_TMPDIRS=()

cleanup() {
	local dir
	for dir in "${TEST_TMPDIRS[@]:-}"; do
		if [[ -n "${dir}" && -d "${dir}" ]]; then
			rm -rf "${dir}"
		fi
	done
}

trap cleanup EXIT

mk_test_tmpdir() {
	local dir
	dir="$(mktemp -d)"
	TEST_TMPDIRS+=("${dir}")
	printf '%s\n' "${dir}"
}

fail() {
	printf 'FAIL: %s\n' "$*" >&2
	return 1
}

assert_file_exists() {
	local path="$1"
	[[ -e "${path}" ]] || fail "expected file to exist: ${path}"
}

assert_not_exists() {
	local path="$1"
	[[ ! -e "${path}" ]] || fail "expected path to be absent: ${path}"
}

assert_equals() {
	local expected="$1"
	local actual="$2"
	[[ "${expected}" == "${actual}" ]] || fail "expected [${expected}] but got [${actual}]"
}

assert_contains() {
	local haystack="$1"
	local needle="$2"
	[[ "${haystack}" == *"${needle}"* ]] || fail "expected output to contain [${needle}]"
}

run_test() {
	local name="$1"
	shift

	printf '== %s ==\n' "${name}"
	"$@"
}
