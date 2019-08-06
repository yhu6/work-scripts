#!/bin/bash

echo "Note: This script runs active-ctrl-reboot-test.sh on Controllers forever!"
echo "      Anytime you can use ctrl+c to stop the loop!"
echo "      We start from controller-0, so ensure controller-0 is active!!"

detect_and_wait() {
    target_host=$1
    wait_mins=$2
    detect_pod=${3:-"ALL"}
    wait_loop=0
    while [ $wait_loop -lt $wait_mins ]; do
        ssh sysadmin@$target_host "/home/sysadmin/kos-probe.sh $detect_pod"
        wait_loop=$((wait_loop+1))
        # wait for 1 min each loop
        sleep 60
        echo "---> $wait_loop mins passed ..."
    done
}

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
host=`ssh sysadmin@10.10.10.3 "hostname"`
detect_and_wait 10.10.10.3  1 "ALL"
while [ $var -lt $loop_num ]; do
    var=$((var+1))
    echo "---------------------$var on $host---------------------------------"
    # $host seems ready to reboot
    ssh sysadmin@10.10.10.3 "/home/sysadmin/active-ctrl-reboot-test.sh"

    echo "switching to another controller ..."
    host=`ssh sysadmin@10.10.10.4 "hostname"`
    var=$((var+1))
    echo "---------------------$var on $host---------------------------------"
    detect_and_wait 10.10.10.4  15 "ALL"
    # $host seems ready to reboot
    ssh sysadmin@10.10.10.4 "/home/sysadmin/active-ctrl-reboot-test.sh" 

    echo "switching to another controller ..."
    host=`ssh sysadmin@10.10.10.3 "hostname"`
    echo "detect pods on $host and wait for 15 mins"
    detect_and_wait 10.10.10.3  15 "ALL"
done
echo "<-----"

