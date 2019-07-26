#!/bin/bash

echo "Note: This script runs active-ctrl-reboot-test.sh on Controllers forever!"
echo "      Anytime you can use ctrl+c to stop the loop!"
echo "      We start from controller-0, so ensure controller-0 is active!!"

read -p "This script will reboot controllers, continue?[Yes|No]: " confirm
confirm=${confirm:-No}
if [[ $confirm != "Yes" ]]; then
    exit
fi

read -p "Enter test loop [40]: " loop_num
loop_num=${loop_num:-40}
echo "totally reboot $loop_num times on 2 controllers!"
echo "----->"
var=0
while [ $var -lt $loop_num ]; do
    var=$((var+1))
    host=`ssh sysadmin@10.10.10.3 "hostname"`
    echo "---------------------$var on $host---------------------------------"
    ssh sysadmin@10.10.10.3 "/home/sysadmin/active-ctrl-reboot-test.sh"
    #wait for 10 mins because it takes about 7 mins to recover a controller
    echo "switching to another controller ..."
    sleep 600
    var=$((var+1))
    host=`ssh sysadmin@10.10.10.4 "hostname"`
    echo "---------------------$var on $host---------------------------------"
    ssh sysadmin@10.10.10.4 "/home/sysadmin/active-ctrl-reboot-test.sh" 
    echo "switching to another controller ..."
    sleep 600
done
echo "<-----"
