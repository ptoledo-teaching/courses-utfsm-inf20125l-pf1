#!/usr/bin/env bash

set -u

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
CODE_DIR="${WORKSPACE}/code"
TESTS_DIR="${WORKSPACE}/tests"
SOURCE="${CODE_DIR}/armamento.c"
PROGRAM="${CODE_DIR}/armamento"
TEMP_DIR="$(mktemp -d)"
VALIDATION_PROGRAM="${TEMP_DIR}/armamento"
PASSES=0
FAILURES=0

trap 'rm -rf -- "${TEMP_DIR}"' EXIT

pass() {
    printf 'PASS: %s\n' "$1"
    PASSES=$((PASSES + 1))
}

fail() {
    printf 'FAIL: %s\n' "$1"
    FAILURES=$((FAILURES + 1))
}

check() {
    local description="$1"
    shift

    if "$@"; then
        pass "${description}"
    else
        fail "${description}"
    fi
}

compiles_cleanly() {
    local description=""

    gcc -Wall -Wextra -Werror -std=c11 "${SOURCE}" \
        -o "${VALIDATION_PROGRAM}" >/dev/null 2>&1 || return 1

    [[ -f "${PROGRAM}" && -x "${PROGRAM}" ]] || return 1
    description="$(file -b -- "${PROGRAM}")"
    [[ "${description}" == ELF*executable* ]]
}

all_test_cases_exist() {
    local number=0
    local test_name=""

    for ((number = 1; number <= 10; number++)); do
        printf -v test_name 'test%03d' "${number}"
        [[ -f "${TESTS_DIR}/${test_name}.in" ]] || return 1
        [[ -f "${TESTS_DIR}/${test_name}.expected" ]] || return 1
    done
}

program_matches() {
    local input="$1"
    local expected="$2"
    local input_file="${TEMP_DIR}/case.in"
    local expected_file="${TEMP_DIR}/case.expected"
    local output_file="${TEMP_DIR}/case.out"

    [[ -x "${VALIDATION_PROGRAM}" ]] || return 1
    printf '%s' "${input}" > "${input_file}"
    printf '%s' "${expected}" > "${expected_file}"

    timeout 3 "${VALIDATION_PROGRAM}" < "${input_file}" \
        > "${output_file}" 2>/dev/null || return 1
    cmp -s "${expected_file}" "${output_file}"
}

decision_is_correct() {
    local input=""
    local expected=""

    input=$'6\n2\n2\n0\n0\n'
    expected=$'Torpedos requeridos: 4\nTorpedos restantes: 2\nDesviacion final: 0\nPunteria: LISTA\nMision: AUTORIZADA\n'
    program_matches "${input}" "${expected}"
}

required_torpedoes_are_correct() {
    local input=""
    local expected=""

    input=$'14\n4\n1\n0\n0\n'
    expected=$'Torpedos requeridos: 8\nTorpedos restantes: 6\nDesviacion final: 0\nPunteria: LISTA\nMision: AUTORIZADA\n'
    program_matches "${input}" "${expected}"
}

targeting_limit_is_correct() {
    local input=""
    local expected=""

    input=$'8\n2\n1\n2\n0\n'
    expected=$'Torpedos requeridos: 4\nTorpedos restantes: 4\nDesviacion final: 2\nPunteria: LISTA\nMision: AUTORIZADA\n'
    program_matches "${input}" "${expected}"
}

calibration_count_is_correct() {
    local input=""
    local expected=""

    input=$'4\n2\n1\n9\n4\n'
    expected=$'Torpedos requeridos: 4\nTorpedos restantes: 0\nDesviacion final: 5\nPunteria: PENDIENTE\nMision: CANCELADA\n'
    program_matches "${input}" "${expected}"
}

deviation_limit_is_correct() {
    local input=""
    local expected=""

    input=$'10\n2\n1\n1\n300\n'
    expected=$'Torpedos requeridos: 4\nTorpedos restantes: 6\nDesviacion final: 0\nPunteria: LISTA\nMision: AUTORIZADA\n'
    program_matches "${input}" "${expected}"
}

final_deviation_is_used() {
    local input=""
    local expected=""

    input=$'10\n2\n1\n3\n3\n'
    expected=$'Torpedos requeridos: 4\nTorpedos restantes: 6\nDesviacion final: 0\nPunteria: LISTA\nMision: AUTORIZADA\n'
    program_matches "${input}" "${expected}"
}

build_instrumented_program() {
    local object_file="${TEMP_DIR}/armamento.o"
    local harness_file="${TEMP_DIR}/instrumented.c"

    printf '%s\n' \
        'extern int debug_enabled;' \
        'int armamento_student_main(void);' \
        'int main(void)' \
        '{' \
        '    debug_enabled = 1;' \
        '    return armamento_student_main();' \
        '}' > "${harness_file}"

    gcc -Wall -Wextra -Werror -std=c11 -Dmain=armamento_student_main \
        -c "${SOURCE}" -o "${object_file}" >/dev/null 2>&1 || return 1
    gcc -Wall -Wextra -Werror -std=c11 "${harness_file}" "${object_file}" \
        -o "${TEMP_DIR}/armamento-instrumented" >/dev/null 2>&1
}

helper_works() {
    local object_file="${TEMP_DIR}/armamento-helper.o"
    local harness_file="${TEMP_DIR}/helper.c"
    local expected_file="${TEMP_DIR}/helper.expected"
    local output_file="${TEMP_DIR}/helper.out"
    local error_file="${TEMP_DIR}/helper.err"

    printf '%s\n' \
        'extern int debug_enabled;' \
        'void debug_valor(const char *nombre, int valor);' \
        'int main(void)' \
        '{' \
        '    debug_enabled = 0;' \
        '    debug_valor("oculto", 1);' \
        '    debug_enabled = 1;' \
        '    debug_valor("visible", 9);' \
        '    debug_enabled = 0;' \
        '    debug_valor("oculto", 2);' \
        '    return 0;' \
        '}' > "${harness_file}"

    gcc -Wall -Wextra -Werror -std=c11 -Dmain=armamento_student_main \
        -c "${SOURCE}" -o "${object_file}" >/dev/null 2>&1 || return 1
    gcc -Wall -Wextra -Werror -std=c11 "${harness_file}" "${object_file}" \
        -o "${TEMP_DIR}/helper-check" >/dev/null 2>&1 || return 1

    printf 'DEBUG: visible=9\n' > "${expected_file}"
    timeout 3 "${TEMP_DIR}/helper-check" > "${output_file}" \
        2> "${error_file}" || return 1

    [[ ! -s "${output_file}" ]] || return 1
    cmp -s "${expected_file}" "${error_file}"
}

reusable_traces_exist() {
    local input_file="${TEMP_DIR}/reusable.in"
    local output_file="${TEMP_DIR}/reusable.out"
    local error_file="${TEMP_DIR}/reusable.err"

    build_instrumented_program || return 1
    printf '10\n2\n2\n0\n0\n' > "${input_file}"
    timeout 3 "${TEMP_DIR}/armamento-instrumented" < "${input_file}" \
        > "${output_file}" 2> "${error_file}" || return 1

    grep -Fxq 'DEBUG: requeridos=4' "${error_file}" || return 1
    grep -Fxq 'DEBUG: restantes=6' "${error_file}" || return 1
    grep -Fxq 'DEBUG: desviacion_final=0' "${error_file}"
}

conditional_trace_is_limited() {
    local input_file="${TEMP_DIR}/conditional.in"
    local output_file="${TEMP_DIR}/conditional.out"
    local error_file="${TEMP_DIR}/conditional.err"
    local cycle_lines=0
    local total_lines=0

    build_instrumented_program || return 1
    printf '10\n2\n1\n1\n300\n' > "${input_file}"
    timeout 3 "${TEMP_DIR}/armamento-instrumented" < "${input_file}" \
        > "${output_file}" 2> "${error_file}" || return 1

    cycle_lines="$(grep -c '^DEBUG: ciclo=' "${error_file}" || true)"
    total_lines="$(grep -c '^DEBUG:' "${error_file}" || true)"

    (( cycle_lines >= 1 && cycle_lines <= 10 && total_lines <= 30 ))
}

instrumentation_is_disabled() {
    local input_file="${TEMP_DIR}/disabled.in"
    local output_file="${TEMP_DIR}/disabled.out"
    local error_file="${TEMP_DIR}/disabled.err"

    [[ -x "${VALIDATION_PROGRAM}" ]] || return 1
    printf '10\n2\n1\n1\n300\n' > "${input_file}"
    timeout 3 "${VALIDATION_PROGRAM}" < "${input_file}" \
        > "${output_file}" 2> "${error_file}" || return 1
    [[ ! -s "${error_file}" ]]
}

suite_passes() {
    all_test_cases_exist || return 1
    [[ -x "${SCRIPT_DIR}/tests-run.sh" ]] || return 1
    [[ -x "${VALIDATION_PROGRAM}" ]] || return 1
    "${SCRIPT_DIR}/tests-run.sh" "${VALIDATION_PROGRAM}" \
        "${TESTS_DIR}" >/dev/null 2>&1
}

printf '%s\n' '========================================='
printf '%s\n' '==   Verificación de laboratorio PF1   =='
printf '%s\n' '========================================='
printf '\n== Actividades ==========================\n\n'

check "[1.2] El programa compila sin warnings y armamento corresponde a un binario" compiles_cleanly
check "[1.3] tests-run.sh tiene permiso de ejecución" test -x "${SCRIPT_DIR}/tests-run.sh"
check "[1.3] Existen los diez pares de archivos de prueba" all_test_cases_exist
check "[2.3] La decisión de la misión es correcta" decision_is_correct
check "[3.3] El cálculo de torpedos requeridos es correcto" required_torpedoes_are_correct
check "[4.1] La función debug_valor responde al control global" helper_works
check "[4.2] Las trazas reutilizables fueron incorporadas" reusable_traces_exist
check "[5.1] El límite de la puntería es correcto" targeting_limit_is_correct
check "[5.2] La cantidad de ciclos ejecutados es correcta" calibration_count_is_correct
check "[6.1] La desviación permanece dentro del rango definido" deviation_limit_is_correct
check "[6.1] La traza condicional del ciclo está acotada" conditional_trace_is_limited
check "[6.2] La decisión utiliza la desviación final" final_deviation_is_used
check "[7.1] La instrumentación se encuentra deshabilitada" instrumentation_is_disabled
check "[7.2] La suite completa finaliza correctamente" suite_passes
check "[8.1] check.sh tiene permiso de ejecución" test -x "${SCRIPT_DIR}/check.sh"

printf '\n== Resumen ===============================\n\n'
TOTAL=$((PASSES + FAILURES))
COUNT_WIDTH=${#TOTAL}
printf '%-26s %*d\n' 'Comprobaciones exitosas:' "${COUNT_WIDTH}" "${PASSES}"
printf '%-26s %*d\n\n' 'Comprobaciones pendientes:' "${COUNT_WIDTH}" "${FAILURES}"

if (( FAILURES == 0 )); then
    exit 0
fi

exit 1
