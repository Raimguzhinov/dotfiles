#!/bin/bash

# BOLD=$(tput bold)
# NORMAL=$(tput sgr0)
#
# exec 2>&1  # Send stderr to stdout
#
# echo "${BOLD}[PASS SYNC]${NORMAL}"
# date
#
# # Remove old files
# rm -rf ~/.password-store.bak
# rm -rf /tmp/.password-store
# rm -f /tmp/pass.orig
# rm -f /tmp/pass.updated
#
# pass > /tmp/pass.orig
# HEAD=$(pass git log -1 --format=%H)
#
# # Create backup
# cp -r ~/.password-store ~/.password-store.bak &>/dev/null
#
# # Update local password store
# echo -e "\n${BOLD}Updating${NORMAL}"
# pushd . &>/dev/null
# cd ~/.password-store
# git pull --no-edit
#
# # If merge failed, revert
# if [ "$?" != 0 ]; then
#     echo "ERROR: Merge failed"
#     echo -e "\n${BOLD}Revert${NORMAL}"
#     git reset --hard $HEAD
# fi
#
# popd &>/dev/null
#
# # Save snapshot of updated store
# pass > /tmp/pass.updated
# UPDATED_HEAD=$(pass git log -1 --format=%H)
#
# # Compare changes in store
# echo -e "\n${BOLD}Summary${NORMAL}"
# diff -u /tmp/pass.orig /tmp/pass.updated
# if [ "$?" = "0" ]; then
#     if [ "${HEAD}" = "${UPDATED_HEAD}" ]; then
#         echo "No changes"
#     else
#         echo "Passwords updated"
#     fi
# fi

echo -e "\n${BOLD}Add new changes${NORMAL}"

changes=$(pass git status --porcelain)

if [ -n "$changes" ]; then
  message="Add password for $(echo $changes | cut -c 4-) to store using Sync-script"
  pass git add .
  pass git commit -m "$message"
  pass git push
else
  pass git push
  echo "No changes"
fi

