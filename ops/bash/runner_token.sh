#!/usr/bin/env bash

# Request an RUNNER_TOKEN to be used to register runner
#
# Environment variable that need to be set up:
# * ACCESS_TOKEN: PAT token
# * RUNNER_SCOPE: 'org' | 'ent' | 'repo'
# * SCOPE_TARGET: Organization name | Enterprise name | Repository URL
#

RUNNER_SCOPE=$1
SCOPE_TARGET=$2


_GITHUB_HOST=${GITHUB_HOST:="github.com"}

# If URL is not github.com then use the enterprise api endpoint
if [[ ${GITHUB_HOST} = "github.com" ]]; then
  URI="https://api.${_GITHUB_HOST}"
else
  URI="https://${_GITHUB_HOST}/api/v3"
fi

API_VERSION=v3
API_HEADER="Accept: application/vnd.github.${API_VERSION}+json"
AUTH_HEADER="Authorization: token ${ACCESS_TOKEN}"
CONTENT_LENGTH_HEADER="Content-Length: 0"

case ${RUNNER_SCOPE} in
  org*)
    _FULL_URL="${URI}/orgs/${SCOPE_TARGET}/actions/runners/registration-token"
    ;;

  ent*)
    _FULL_URL="${URI}/enterprises/${SCOPE_TARGET}/actions/runners/registration-token"
    ;;

  *)
    _PROTO="https://"
    # shellcheck disable=SC2116
    _URL="$(echo "${SCOPE_TARGET/${_PROTO}/}")"
    _PATH="$(echo "${_URL}" | grep / | cut -d/ -f2-)"
    _ACCOUNT="$(echo "${_PATH}" | cut -d/ -f1)"
    _REPO="$(echo "${_PATH}" | cut -d/ -f2)"
    _FULL_URL="${URI}/repos/${_ACCOUNT}/${_REPO}/actions/runners/registration-token"
    ;;
esac

#https post ${_FULL_URL} \
#  Authorization:"token $ACCESS_TOKEN" \
#  Accept:"application/vnd.github.${API_VERSION}+json" \
#  Content-Length:"0" \
#  --check-status \
#  --timeout=2.5 \
#  --print 'b' 1> /tmp/http_runner_token 2> /tmp/http_runner_token_error
#statuscode_var=$(echo ${?})
#stdout_var=$( cat /tmp/http_runner_token )
#stderr_var=$( cat /tmp/http_runner_token_error )
#
#if [ $statuscode_var != 0 ]
#then
#  echo "Failed to get runner token!" >&2
#  echo $stderr_var >&2
#  echo $stdout_var >&2
#  exit $statuscode_var
#fi
#
#RUNNER_TOKEN="$(echo $stdout_var | jq -r '.token')"

RUNNER_TOKEN="$(curl -XPOST -fsSL \
  -H "${CONTENT_LENGTH_HEADER}" \
  -H "${AUTH_HEADER}" \
  -H "${API_HEADER}" \
  "${_FULL_URL}" \
| jq -r '.token')"

echo "{\"token\": \"${RUNNER_TOKEN}\", \"full_url\": \"${_FULL_URL}\"}"
