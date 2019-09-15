#!/usr/bin/bash

# check pod and reboot if this controller is active controller
# otherwise wait

# make no password for current user when sudo
#set -x


# must specify kubeconfig, in a session where kubectl is running
export KUBECONFIG="/etc/kubernetes/admin.conf"
check_pod_status() {
    _tmp_file=/tmp/tmp_pod_status.txt
    cat /dev/null > ${_tmp_file}
    pod_prefix=$1
    kubectl -n openstack get pods | grep $pod_prefix > ${_tmp_file}
    while IFS= read -r line; do
        # tr -s ' ' remove many spaces but leave one
        pod_name=`echo $line | tr -s ' ' | awk '{print $1}'`
        pod_ready=`echo $line | tr -s ' ' | awk '{print $2}'`
        pod_state=`echo $line | tr -s ' ' | awk '{print $3}'`
        #echo "pod $pod_name is $pod_state"
        if [ $pod_state != "Running" ] || [ $pod_ready != "1/1" ] ; then
            # it means "return 1"
            echo $line
            break
        fi
        # while ... done
    done < "${_tmp_file}"
    # it means "return 0"
}
#echo $keystone_pods | awk '/keystone-api/{print $7}'


user=`whoami`
cat << EOF | sudo tee /etc/sudoers.d/${user}
${user} ALL = (root) NOPASSWD:ALL
EOF



host_name=`hostname`
echo "my name is $host_name"
while true; do
    rc=`check_pod_status "keystone-api"`
    kubectl -n openstack get pods | grep "keystone-api"
    if [[ x$rc == x"not_running" ]]; then
        sleep 10
        # not all running, so recheck after 10s
    else
        # all good, stop checking
        break
    fi
done

echo "all good"!
ret_string=`source /etc/platform/openrc`
if [[ $ret_string == *"only be loaded from the active controller"* ]]; then
    echo "I am standby, so I am checking how keystone-api K8S pods are going"
    pod_status=`kubectl -n openstack get pods | grep keystone-api | awk '/keystone-api/{print $2}'`
else
    echo "I am active, and let see how keystone-api pods are doing:"
    kubectl -n openstack get pods | grep keystone-api
    source /etc/platform/openrc
    system host-list
    # check the current contorller's role: standby or active
    my_role=`system host-show $host_name | awk '/capabilities/{print $7}' | cut -d "'" -f 2`
    echo "my role is $my_role"
    if [[ x$my_role == x"Controller-Active" ]]; then
        echo "I am $my_role and now check another controller's availability status"
        if [[ $host_name == "controller-0" ]]; then
            another_ctrl="controller-1"
        else
            another_ctrl="controller-0"
        fi
        echo "another controller is $another_ctrl"
        while true; do
            ctrl_avail=`system host-show $another_ctrl | grep availability | awk '/availability/{print $4}'`
            if [[ $ctrl_avail == "available" ]]; then
                echo "$another_ctrl is under $ctrl_avail state!"
                test_ready="ready"
                break
            fi
        done
    else
        echo "Error:I am not an active controller, though I can apply env /etc/platform/openrc"
    fi
fi

if [[ x$test_ready == x"ready" ]]; then
	echo "ready to kick the testing - restart the active controller"
	sudo init 6
fi
