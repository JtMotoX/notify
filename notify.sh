#!/bin/sh

# IF YOU GET AN ERROR 'notify: Argument list too long', TRY THIS METHOD:
# printf '%s\n' "${recent_logs}" | tee -a /tmp/backup.log | notify --title "SD Card Import Complete" --tail-lines 10 cat

#########################

# Initialize flags
LOCAL_ONLY=false
TAIL_LINES=3

# Parse flags
while [ $# -gt 0 ]; do
    case "$1" in
        -l|--local-only)
            LOCAL_ONLY=true
            shift
            ;;
		-t|--title)
			if [ -z "$2" ] || [ "${2#-}" != "$2" ]; then
				echo "Error: --title requires an argument"
				exit 1
			fi
			CUSTOM_TITLE="$2"
			shift 2
			;;
        -n|--tail-lines)
            if [ -z "$2" ] || [ "${2#-}" != "$2" ]; then
                echo "Error: --tail-lines requires a numeric argument"
                exit 1
            fi
            TAIL_LINES="$2"
            shift 2
            ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS] command"
            echo "Options:"
            echo "  -l, --local-only    Only play sound notification, don't send pushover notification"
			echo "  -t, --title TITLE   Set custom title for the notification"
            echo "  -n, --tail-lines NUMBER  Number of lines to tail from output (default: 3)"
            echo "  -h, --help          Show this help message"
            exit 0
            ;;
        -*)
            echo "Unknown option: $1"
            echo "Usage: $0 [OPTIONS] command"
            exit 1
            ;;
        *)
            # This is not a flag, so it's the start of the command
            break
            ;;
    esac
done

# Check if a command was provided
if [ $# -eq 0 ]; then
    echo "Usage: $0 [OPTIONS] command"
    echo "Use -h or --help for more information"
    exit 1
fi

# GET VARIABLES
SCRIPTDIR="$(dirname "$(readlink -f "$0")")"
ENV_FILE="${SCRIPTDIR}/.env"
touch "${ENV_FILE}"
if ! grep 'PUSHOVER_USER=' "${ENV_FILE}" >/dev/null 2>&1; then { echo "PUSHOVER_USER=" >>"${ENV_FILE}"; } fi
if ! grep 'PUSHOVER_TOKEN=' "${ENV_FILE}" >/dev/null 2>&1; then { echo "PUSHOVER_TOKEN=" >>"${ENV_FILE}"; } fi
. "${SCRIPTDIR}/.env"

# Only check Pushover credentials if not running in local-only mode
if [ "${LOCAL_ONLY}" = "false" ]; then
    if [ "${PUSHOVER_USER}" = "" ]; then { echo "Please set the PUSHOVER_USER value: '${ENV_FILE}'"; FAILED=true; } fi
    if [ "${PUSHOVER_TOKEN}" = "" ]; then { echo "Please set the PUSHOVER_TOKEN value: '${ENV_FILE}'"; FAILED=true; } fi
    if [ "${FAILED}" = "true" ]; then { exit 1; } fi
fi

# DETERMINE OUTPUT FILE
OUTFILE=/tmp/pushover_$(date +%s).txt

# RUN COMMAND
started=$(date +%s)
ret_file=$(mktemp -t)
#set -x
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
if [ "${CUSTOM_TITLE}" != "" ]; then
	CUSTOM_TITLE_STRING="- ${CUSTOM_TITLE} "
fi
if [ "${EXITCODE}" = "0" ]; then
	TITLE="Success ${CUSTOM_TITLE_STRING}: ${runtime}"
else
	TITLE="Failed ${CUSTOM_TITLE_STRING}: ${runtime}"
fi

# GET LAST LINES FROM OUTPUT
OUTLINES=$(cat "${OUTFILE}" | grep -v '^\s*$' | grep -v '^\x1b]' 2>/dev/null | tail -n "${TAIL_LINES}")

# SET MESSAGE
MESSAGE="${OUTLINES}"

# CLEANUP
rm -f "${OUTFILE}"

# SEND NOTIFICATION
if [ "${LOCAL_ONLY}" = "true" ]; then
	echo "Running in local-only mode, not sending push notification" >/dev/null
elif [ "${PUSHOVER}" = "0" ] || [ "$(echo "${PUSHOVER}" | tr '[:upper:]' '[:lower:]')" = "false" ]; then
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
