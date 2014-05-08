#!/bin/bash


PLUGINS_DIR="/usr/share/munin/plugins"
INSTALLED_PLUGINS_DIR="/etc/munin/plugins"
PLUGINS_CONF_DIR="/usr/share/munin/plugin-conf.d"
BOSH_JOBS_DIR="/var/vcap/jobs"
PID_FILE="/var/run/munin/munin-node.pid"

force_link_plugin() {
  LINK_FROM_NAME=$1
  LINK_FROM_DIR=$4
  LINK_TO_NAME=$2
  LINK_TO_DIR=$3
  ln -sf $LINK_FROM_DIR$LINK_FROM_NAME $LINK_TO_DIR$LINK_TO_NAME
}

force_link_plugin_iterate() {
  TO_LINK_ARRAY=("$@")
  for k in "${TO_LINK_ARRAY[@]}"
  do
      basedirname=`basename $k`

      if [[ $k == *plugins* ]]; then
      todirname="/etc/munin/plugins/"
      else
      todirname="/etc/munin/plugin-conf.d/"
      fi	
      	
      force_link_plugin $k $basedirname $todirname
  done

}

start_munin_node() {
  rm -f $PID_FILE
  if [ `ps -ef | grep munin-node | grep -v grep | wc -l` = 1 ]
  then
    killall munin-node
  fi
  /usr/sbin/munin-node
}

stop_munin_node() {
  if [ `ps -ef | grep munin-node | grep -v grep | wc -l` = 1 ]
  then
    killall munin-node
  fi
}

restart_munin_node() {
  stop_munin_node
  start_munin_node
}

if [ -f "${PLUGINS_DIR}/done" ]; then

VM_JOBS_LENGTH_OLD=`cat "${PLUGINS_DIR}/done"`

else 

VM_JOBS_LENGTH_OLD=0

fi

VM_JOBS=`ls ${BOSH_JOBS_DIR}`


VM_JOBS_LENGTH=`ls ${BOSH_JOBS_DIR} | wc -l`


echo $VM_JOBS_LENGTH > ${PLUGINS_DIR}/done



if [ $VM_JOBS_LENGTH -gt $VM_JOBS_LENGTH_OLD ]; then
  # ensure that all of the plugins are enabled and ready to run...
  PLUGINS=( "cpu" "df" "df_inode" "diskstats" "entropy" "forks" "interrupts" "irqstats" "load" "lpstat" "memory" "open_files" "open_inodes" "processes" "proc_pri" "swap" "threads"
 "uptime" "users" "vmstat" )
  for i in "${PLUGINS[@]}"
  do
      force_link_plugin $i $i "$INSTALLED_PLUGINS_DIR/" "$PLUGINS_DIR/"
  done

for i in ${VM_JOBS}; 
  do 
     if [ -d "${PLUGINS_DIR}/$i" ]; then 
       VM_PLUGINS=`ls ${PLUGINS_DIR}/$i/*`; 
       force_link_plugin_iterate ${VM_PLUGINS};
     fi; 
  done

for j in ${VM_JOBS}; 
  do 
    if [ -d "${PLUGINS_CONF_DIR}/$j" ]; then 
      VM_PLUGINS_CONF=`ls ${PLUGINS_CONF_DIR}/$j/*`; 
    fi; 
    force_link_plugin_iterate ${VM_PLUGINS_CONF}; 
  done

restart_munin_node


fi
