#!/bin/sh

# Check if a command was provided
if [ $# -eq 0 ]; then
    echo "Usage: $0 command"
    exit 1
fi

# GET VARIABLES
SCRIPTDIR="$(dirname "$(readlink -f "$0")")"
ENV_FILE="${SCRIPTDIR}/.env"
touch "${ENV_FILE}"
if ! grep 'PUSHOVER_USER=' "${ENV_FILE}" >/dev/null 2>&1; then { echo "PUSHOVER_USER=" >>"${ENV_FILE}"; } fi
if ! grep 'PUSHOVER_TOKEN=' "${ENV_FILE}" >/dev/null 2>&1; then { echo "PUSHOVER_TOKEN=" >>"${ENV_FILE}"; } fi
. "${SCRIPTDIR}/.env"
if [ "${PUSHOVER_USER}" = "" ]; then { echo "Please set the PUSHOVER_USER value: '${ENV_FILE}'"; FAILED=true; } fi
if [ "${PUSHOVER_TOKEN}" = "" ]; then { echo "Please set the PUSHOVER_TOKEN value: '${ENV_FILE}'"; FAILED=true; } fi
if [ "${FAILED}" = "true" ]; then { exit 1; } fi

# DETERMINE OUTPUT FILE
OUTFILE=/tmp/pushover_$(date +%s).txt

# RUN COMMAND
started=$(date +%s)
ret_file=$(mktemp -t)
set -x
{ "$@" 2>&1; echo "$?" >"${ret_file}"; } | tee "${OUTFILE}"
{ set +x; } 2>/dev/null
EXITCODE=$(cat "${ret_file}"; rm -f "${ret_file}")
ended=$(date +%s)
runtime_s=$((ended-started))

if [ "${runtime_s}" -lt 60 ]; then
	runtime=${runtime_s}" sec"
else
	runtime=$((${runtime_s} / 60))" min"
fi

# SET TITLE
if [ "${EXITCODE}" = "0" ]; then
	TITLE="Success : ${runtime}"
else
	TITLE="Failed : ${runtime}"
fi

# GET LAST LINES FROM OUTPUT
OUTLINES=$(cat "${OUTFILE}" | grep -v '^\s*$' | grep -v '^\x1b]' 2>/dev/null | tail -n 3)

# SET MESSAGE
MESSAGE="${OUTLINES}"

# CLEANUP
rm -f "${OUTFILE}"

# SEND NOTIFICATION
if [ "${PUSHOVER}" = "0" ] || [ "$(echo "${PUSHOVER}" | tr '[:upper:]' '[:lower:]')" = "false" ]; then
	echo "Not sending push notification since PUSHOVER=${PUSHOVER}"
else
	curl -s \
			--form-string "user=${PUSHOVER_USER}" \
			--form-string "token=${PUSHOVER_TOKEN}" \
			--form-string "title=${TITLE}" \
			--form-string "message=${MESSAGE}" \
			https://api.pushover.net/1/messages.json \
			>/dev/null 2>&1
fi

# FUNCTION TO PLAY SOUND
play_sound() {
	SOUNDCOUND=$1
	SOUNDSLEEP=$2
	for i in `seq 1 ${SOUNDCOUND}`; do
		printf "\a"
		if [ ${SOUNDCOUND} -ne ${i} ]; then
			sleep ${SOUNDSLEEP}
		fi
	done
}

# PLAY SOUND
if [ "${EXITCODE}" = "0" ]; then
	play_sound 3 1
else
	play_sound 2 0.5
	sleep 1
	play_sound 2 0.5
	sleep 1
	play_sound 2 0.5
	sleep 1
fi

exit ${EXITCODE}
