#!/bin/bash

echo " _______                    _            "
echo "|__   __|                  | |           "
echo "   | | __ _ _ __   __ _  __| | ___  ___ "
echo "   | |/ _' | '_ \ / _' |/ _' |/ _ \/ __| "
echo "   | | (_| | | | | (_| | (_| | (_) \__ \ "
echo "   |_|\__,_|_| |_|\__,_|\__,_|\___/|___/ "
echo "                                     "                                                                

echo -n "=> 0%  "
for i in {1..100}
do
  # Create a string with the current loading percentage
  percent="$(printf "=>%3d%%" "$i")"
  
  # Overwrite the current line with the updated percentage
  echo -ne "$percent\r"
  
  # Sleep for a short interval to simulate some processing
  sleep 0.10
done

# Realm Configuration
current_date=$(date +'%Y-%m-%d_%H:%M')
realm1_auth_log="logs/realms/realm1/Auth.log"
realm1_dberrors_log="logs/realms/realm1/DBErrors.log"
realm1_server_log="logs/realms/realm1/Server.log"
realm1_auth_tmux="auth"
realm1_auth_command="/root/wow/acore.sh run-authserver"
realm1_auth_log_path="logs/AutoCheck/realm1/Auth.log"
realm1_auth_log_path_error="logs/AutoCheck/realm1/Auth-$(date +'%Y-%m-%d_%H:%M').log"

realm1_server_log="logs/realms/realm1/Server.log"
realm1_world_tmux="world"
realm1_world_command="/root/wow/acore.sh run-worldserver"
realm1_world_log_path="logs/AutoCheck/realm1/Realm1.log"
realm1_world_log_path_error="logs/AutoCheck/realm1/Realm1-$(date +'%Y-%m-%d_%H:%M').log"

realm2_server_log="logs/realms/realm2/Server.log"
realm2_dberrors_log="logs/realms/realm2/DBErrors.log"
realm2_world_tmux="world2"
realm2_world_command="/root/wow2/acore.sh run-worldserver"
realm2_world_log_path="logs/AutoCheck/realm2/Realm2.log"
realm2_world_log_path_error="logs/AutoCheck/realm2/Realm2-$(date +'%Y-%m-%d_%H:%M').log"

external_ip="your.logon.com" #your external ip or dns
auth_port="3724"
realm1_port="8085"
realm2_port="8086"
mysql_ip="127.0.0.1"
mysql_port="3306"
realm1_name="Realm1"
realm2_name="Realm2"

noerror="/root/wow/logs/AutoCheck/NoErrorFound.log"
WEBHOOK="https://discord.com/api/webhooks/" #A discord configuration for WebHooks

# Check Auth Log for Errors
if grep -q 'ERROR' $realm1_auth_log; then
  ping -c 3 $external_ip -p $auth_port &>/dev/null
  if [ $? -ne 0 ]; then
    if grep -q 'Lost connection' $realm1_dberrors_log; then
      ping -c 3 $mysql_ip -p $mysql_port &>/dev/null
      if [ $? -ne 0 ]; then
        systemctl restart mysql
      fi
    fi
    tmux kill-session -t $realm1_auth_tmux
    tmux new-session -s $realm1_auth_tmux -d $realm1_auth_command
  fi
  echo "Auth log check complete, Error log located at $realm1_auth_log_path" &>> $realm1_auth_log_path_error
else
  echo "No errors found in Auth log." &>> $realm1_auth_log_path
fi
sleep 5
# Check World Log for Errors
if grep -q 'ERROR' $realm1_server_log; then
  ping -c 3 $external_ip -p $realm1_port &>/dev/null
  if [ $? -ne 0 ]; then
    if grep -q 'Lost connection' $realm1_dberrors_log; then
      ping -c 3 $mysql_ip -p $mysql_port &>/dev/null
      if [ $? -ne 0 ]; then
        systemctl restart mysql
      fi
    fi
    tmux kill-session -t $realm1_world_tmux
    tmux new-session -s $realm1_world_tmux -d $realm1_world_command
  fi
  echo "$realm1_name log check complete, Error log located at $realm1_world_log_path" &>> $realm1_world_log_path_error
else
  echo "No errors found in $realm1_name log." &>> $realm1_world_log_path
fi
sleep 5
# Check World2 Log for Errors
if grep -q 'ERROR' $realm2_server_log; then
  ping -c 3 $external_ip -p $realm2_port &>/dev/null
  if [ $? -ne 0 ]; then
    if grep -q 'Lost connection' $realm2_dberrors_log; then
      ping -c 3 $mysql_ip -p $mysql_port &>/dev/null
      if [ $? -ne 0 ]; then
        systemctl restart mysql
      fi
    fi
    tmux kill-session -t $realm2_world_tmux
    tmux new-session -s $realm2_world_tmux -d $realm2_world_command
  fi
  echo "$realm2_name log check complete, log located at $realm2_world_log_path" &>> $realm2_world_log_path_error
else
  echo "No errors found in $realm2_name log." &>> $realm2_world_log_path
fi

#Discord send only Error files
listfiles=($realm1_auth_log_path_error $realm1_world_log_path_error $realm2_world_log_path_error)
existing_files=()
for file in "${listfiles[@]}"; do
  if [ -f "$file" ]; then
    existing_files+=( "$file" )
  fi
done

if [ ${#existing_files[@]} -eq 0 ]; then
  existing_files=($noerror)
fi

cd ~/wow/discord
for existing_file in "${existing_files[@]}"; do
  ./discord.sh \
    --webhook-url=$WEBHOOK \
    --file $existing_file \
    --username "The Watcher" \
    --text "AutoCheck Service for $current_date\nPlece take a look for errors!"
done
echo "AutoCheck Service for $current_date is complete"