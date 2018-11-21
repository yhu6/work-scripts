# update localrc if needed

# use Makefile to build a docker image based on your settings
# NOTES: in advance into Dockerfile, need to add http/https 
# proxies and "/etc/yum.conf", which will be used in CentOS 

make all

# after quite a while (depending on network), the docker
# image should be made, check it by:

docker images

# if the image is made successfully, to make a container:

./tb.sh run

# after the container is maded and running, to check by:

docker ps

# if the container is running, to login in shell in the 
# container, with user/path defined in your localrc

./tb.sh exec 

