#!/bin/bash -e

if [ $# -ne 5 ]; then
	echo "$0 <bmc_node_ipmi_ip> <rd_img_uuid> <kernel_img_uuid> <bm_nic_mac> <node_name>"
	echo "    bmc_node_ipmi_ip: IPMI IP from BIOS setting, statically set or from DHCP."
	echo "    rd_img_uuid: ramdisk image UUID from # glance image-list"
	echo "    kernel_img_uuid: kernel image UUID from # glance image-list"
	echo "    bm_nic_mac: BM NIC MAC address, which connects to ironic_provisioning_network"
	echo "    node_name: whatever name you set for this BM node"
	exit
fi

bmc_node_ipmi_ip=$1
rd_img_uuid=$2
kernel_img_uuid=$3
bm_nic_mac=$4 # a4:bf:01:2b:3b:c9 
node_name=$5

# mandatory - confirm the images in Glance for ramdisk and kernel image
ramdisk_img=`glance image-list | grep -w ${rd_img_uuid} | awk '{print $2}'`
kernel_img=`glance image-list | grep -w ${kernel_img_uuid} | awk '{print $2}'`

bmc_node_ipmi_port=623
# these parameters could be modified according to the actual BM setting
ipmi_driver=pxe_ipmitool_socat
ipmi_user=root
ipmi_password="test123"
bm_cpu_arch=x86_64
bm_cpus=4
bm_caps="boot_option:local"
bm_ram_mb=8192
bm_disk_gb=400

export IRONIC_API_VERSION=latest

# NOTE: mandatory - need to do some settings in BIOS in Bare Metal host, to make IPMI work
# test IPMI works on bare metal host.
sudo ipmitool -I lan -H ${bmc_node_ipmi_ip} -p ${bmc_node_ipmi_port} -L ADMINISTRATOR -U ${ipmi_user} -P ${ipmi_password}  sdr list

# mandatory - create an ironic node
# specify a few important items, such as ipmi_address, ipmi user name, password (all were set in BIOS in advance)
node_uuid=`ironic node-create -d${ipmi_driver} -i ipmi_address=${bmc_node_ipmi_ip} -i ipmi_username=${ipmi_user} -i ipmi_password=${ipmi_password} | grep  -w "uuid" | awk '{print $4}'`

# optional - show the ironic node which was created just now
echo "------ show  node ${node_uuid}-------------"
ironic node-show ${node_uuid}

# set the name for the newly created ironic node
ironic node-update ${node_uuid} add name=${node_name}

# mandatory - set ramdisk and kernel in driver_info for the node
ironic node-update ${node_uuid} add driver_info/deploy_kernel=${kernel_img} driver_info/deploy_ramdisk=${ramdisk_img}

# mandatory - set ipmi terminal port  in driver_info for the node
ironic node-update ${node_uuid} add driver_info/ipmi_terminal_port=${bmc_node_ipmi_port}

# mandatory - set properties for the node 
ironic node-update ${node_uuid} add properties/cpu_arch=${bm_cpu_arch} properties/cpus=${bm_cpus} properties/capabilities=${bm_caps} properties/memory_mb=${bm_ram_mb} properties/local_gb=${bm_disk_gb}

# optional - enable the console mode for the node, for debugging purpose mainly
ironic node-set-console-mode ${node_uuid} true


# mandatry - create an ethernet port by adding MAC (a4:bf:01:2b:3b:c9) for the node. 
# NOTE: this port is *different* from the BMC management port which is set in BIOS for IPMI
# This port connects to ironic-provisioning-net and it will be used for IPA at deploy stage
ironic port-create -n ${node_uuid} -a ${bm_nic_mac} --pxe-enabled True

# mandatory - change the provision state to “manageable” from “enroll” state, by “manage” event
# details refer to https://docs.openstack.org/ironic/pike/contributor/states.html
ironic node-set-provision-state ${node_uuid} manage

echo "--------- check node ${node_uuid} is under *manageable* state -------------"
ironic node-show ${node_uuid} | grep "state"

# mandatory - change the provision state to “available” from “manageable” state, by “provide” event.
# there could be a few intermediate states, such as “cleaning”, “clean-wait”, or “clean-fail” if something bad happened.
# details refer to https://docs.openstack.org/ironic/pike/contributor/states.html
# to debug the failure, check /var/log/ironic/ironic-conduct.log.
ironic node-set-provision-state ${node_uuid} provide

echo "------ check node ${node_uuid} is going to be under *available* state ------"
ironic node-show ${node_uuid} | grep "state"
echo "Note: it takes a couple minutes before turning to *available* state, given no erros!!\n"
echo "In the middle, you need to manually check the state by: ironic node-show ${node_uuid}\n"


