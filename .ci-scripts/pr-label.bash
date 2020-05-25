#!/bin/bash

# Announces a change in RFC status to based on label to LWIP
#
# Tools required in the environment that runs this:
#
# - bash
# - curl
# - jq

set -o errexit

# Verify ENV is set up correctly
# We validate all that need to be set in case, in an absolute emergency,
# we need to run this by hand. Otherwise the GitHub actions environment should
# provide all of these if properly configured
if [[ -z "${API_CREDENTIALS}" ]]; then
  echo -e "\e[31mAPI_CREDENTIALS needs to be set in env. Exiting.\e[0m"
  exit 1
fi

# no unset variables allowed from here on out
# allow above so we can display nice error messages for expected unset variables
set -o nounset

#
# Get label and see if it is a status label
# If it isn't a changelog label, let's exit.
#

LABEL=$(jq -r '.label.name' "${GITHUB_EVENT_PATH}")
STATUS_LABEL=$(
  jq -r '.label.name' "${GITHUB_EVENT_PATH}" |
  grep -o -E '1 - final comment period|2 - ready for vote' ||
  true
)

if [ -z "${STATUS_LABEL}" ];
then
  echo -e "\e[34m'${LABEL}' isn't a status label. Exiting.\e[0m"
  exit 0
fi

PR_TITLE=$(jq -r '.title' "${GITHUB_EVENT_PATH}")
PR_URL=$(jq -r '.url' "${GITHUB_EVENT_PATH}")

# Update Last Week in Pony
echo -e "\e[34mAdding RFC status change to Last Week in Pony...\e[0m"

result=$(curl https://api.github.com/repos/ponylang/ponylang-website/issues?labels=last-week-in-pony)

lwip_url=$(echo "${result}" | jq -r '.[].url')
if [ "$lwip_url" != "" ]; then
  body="
The '${PR_TITLE}' RFC has been updated to '${STATUS_LABEL}'
See the [RFC](https://github.com/ponylang/rfcs/pull/${PR_URL}) for more details.
"

  jsontemplate="
  {
    \"body\":\$body
  }
  "

  json=$(jq -n \
  --arg body "$body" \
  "${jsontemplate}")

  result=$(curl -s -X POST "$lwip_url/comments" \
    -H "Content-Type: application/x-www-form-urlencoded" \
    -u "${API_CREDENTIALS}" \
    --data "${json}")

  rslt_scan=$(echo "${result}" | jq -r '.id')
  if [ "$rslt_scan" != null ]; then
    echo -e "\e[34mRFC status update posted to LWIP\e[0m"
  else
    echo -e "\e[31mUnable to post to LWIP, here's the curl output..."
    echo -e "\e[31m${result}\e[0m"
  fi
else
  echo -e "\e[31mUnable to post to Last Week in Pony."
  echo -e "Can't find the issue.\e[0m"
fi
