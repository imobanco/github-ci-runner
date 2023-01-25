#!/usr/bin/env bash
# shellcheck shell=bash

export RUNNER_ALLOW_RUNASROOT=1
export PATH=${PATH}:/home/runner_user/runner-cli

# Un-export these, so that they must be passed explicitly to the environment of
# any command that needs them.  This may help prevent leaks.
export -n ACCESS_TOKEN
export -n RUNNER_TOKEN


get_runner_token() {
  ACCESS_TOKEN="${ACCESS_TOKEN}" bash /home/runner_user/runner_token.sh ${RUNNER_SCOPE} ${SCOPE_TARGET}  1> /tmp/runner_token 2> /tmp/runner_token_error
  statuscode_var=$(echo ${?})
  stdout_var=$( cat /tmp/runner_token )
  stderr_var=$( cat /tmp/runner_token_error )
  if [ $statuscode_var != 0 ]
  then
    echo "runner_token.sh has failed!"
    echo $stdout_var
    echo $stderr_var
    exit 1
  fi
  echo "${stdout_var}" | jq -r .token
  return 0
}

deregister_runner() {
  echo "Caught SIGTERM. Deregistering runner"
  if [[ -n "${ACCESS_TOKEN}" ]]; then
    echo "Obtaining the token of the runner"
    RUNNER_TOKEN=$(get_runner_token)
    echo "got token $RUNNER_TOKEN"
  fi
  ./config.sh remove --token "${RUNNER_TOKEN}"
  exit
}

_RUNNER_NAME=${RUNNER_NAME:-${RUNNER_NAME_PREFIX:-github-runner}-$(cat /etc/hostname)}
_RUNNER_WORKDIR=${RUNNER_WORKDIR:-/home/runner_user/_work-${_RUNNER_NAME}}
_LABELS=${LABELS:-default}
_RUNNER_GROUP=${RUNNER_GROUP:-Default}
_GITHUB_HOST=${GITHUB_HOST:="github.com"}
_RUN_AS_ROOT=${RUN_AS_ROOT:="false"}
RUNNER_SCOPE="${RUNNER_SCOPE,,}" # to lowercase

case ${RUNNER_SCOPE} in
  org*)
    [[ -z ${SCOPE_TARGET} ]] && ( echo "SCOPE_TARGET required for org runners"; exit 1 )
    _SHORT_URL="https://${_GITHUB_HOST}/${SCOPE_TARGET}"
    RUNNER_SCOPE="org"
    ;;

  ent*)
    [[ -z ${SCOPE_TARGET} ]] && ( echo "SCOPE_TARGET required for enterprise runners"; exit 1 )
    _SHORT_URL="https://${_GITHUB_HOST}/enterprises/${ENTERPRISE_NAME}"
    RUNNER_SCOPE="enterprise"
    ;;

  *)
    [[ -z ${SCOPE_TARGET} ]] && ( echo "SCOPE_TARGET required for repo runners"; exit 1 )
    _SHORT_URL=${SCOPE_TARGET}
    RUNNER_SCOPE="repo"
    ;;
esac

configure_runner() {
  ARGS=()

  if [[ -n "${ACCESS_TOKEN}" ]]; then
    echo "Obtaining the token of the runner"
    RUNNER_TOKEN=$(get_runner_token)
    echo "got token $RUNNER_TOKEN"
  fi

  # shellcheck disable=SC2153
  if [ -n "${EPHEMERAL}" ]; then
    echo "Ephemeral option is enabled"
    ARGS+=("--ephemeral")
  fi

  if [ -n "${DISABLE_AUTO_UPDATE}" ]; then
    echo "Disable auto update option is enabled"
    ARGS+=("--disableupdate")
  fi

  echo "Configuring"
  ./config.sh \
      --url "${_SHORT_URL}" \
      --token "${RUNNER_TOKEN}" \
      --name "${_RUNNER_NAME}" \
      --work "${_RUNNER_WORKDIR}" \
      --labels "${_LABELS}" \
      --runnergroup "${_RUNNER_GROUP}" \
      --unattended \
      --replace \
      "${ARGS[@]}"

  [[ ! -d "${_RUNNER_WORKDIR}" ]] && mkdir "${_RUNNER_WORKDIR}"

}


# Opt into runner reusage because a value was given
if [[ -n "${CONFIGURED_ACTIONS_RUNNER_FILES_DIR}" ]]; then
  echo "Runner reusage is enabled"

  # directory exists, copy the data
  if [[ -d "${CONFIGURED_ACTIONS_RUNNER_FILES_DIR}" ]]; then
    echo "Copying previous data"
    cp -p -r "${CONFIGURED_ACTIONS_RUNNER_FILES_DIR}/." "/home/runner_user/runner-cli"
  fi

  if [ -f "/home/runner_user/runner-cli/.runner" ]; then
    echo "The runner has already been configured"
  else
    configure_runner
  fi
else
  echo "Runner reusage is disabled"
  configure_runner
fi

if [[ -n "${CONFIGURED_ACTIONS_RUNNER_FILES_DIR}" ]]; then
  echo "Reusage is enabled. Storing data to ${CONFIGURED_ACTIONS_RUNNER_FILES_DIR}"
  # Quoting (even with double-quotes) the regexp brokes the copying
  cp -p -r "/home/runner_user/runner-cli/_diag" "/home/runner_user/runner-cli/svc.sh" /home/runner_user/runner-cli/.[^.]* "${CONFIGURED_ACTIONS_RUNNER_FILES_DIR}"
fi


trap deregister_runner SIGINT SIGQUIT SIGTERM INT TERM QUIT

# Container's command (CMD) execution as runner user
if [[ ${_RUN_AS_ROOT} == "true" ]]; then
  if [[ $(id -u) -eq 0 ]]; then
    "$@"
  else
    echo "ERROR: RUN_AS_ROOT env var is set to true but the user has been overridden and is not running as root, but UID '$(id -u)'"
    exit 1
  fi
else
  if [[ $(id -u) -eq 0 ]]; then
    echo "ERROR: RUN_AS_ROOT env var is set to false but the user has been overridden and is running as root with UID '$(id -u)'"
    exit 1
  else
    "$@"
  fi
fi
