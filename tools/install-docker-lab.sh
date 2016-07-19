#!/bin/bash
#
# install-docker-lab.sh -- need to run with sudo
#

image_name=tinylab/linux-lab

TOP_DIR=$(dirname `readlink -f $0`)

which docker 2>&1 > /dev/null
if [ $? -eq 1 ]; then
    sudo apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 58118E89F3A912897C070ADBF76221572C52609D
    version=`sed -n -e "/ main/p" /etc/apt/sources.list | grep -v ^# | head -1 | cut -d' ' -f3`
    sudo bash -c 'echo "deb https://apt.dockerproject.org/repo ubuntu-'${version}' main" > /etc/apt/sources.list.d/docker.list'
    sudo apt-get -y update
    sudo apt-get -y install docker-engine
    sudo usermod -aG docker $USER

    # The --bip works like https://gist.github.com/ismell/6689836
    sudo sed -i -e "/DOCKER HACK START 578327498237/,/DOCKER HACK END 789527394722/d" /etc/default/docker
    sudo bash -c 'cat <<EOF >> /etc/default/docker
# DOCKER HACK START 578327498237
DOCKER_OPTS="\$DOCKER_OPTS --insecure-registry=registry.mirrors.aliyuncs.com"
DOCKER_OPTS="\$DOCKER_OPTS --dns 8.8.8.8 --dns 8.8.4.4"
DOCKER_OPTS="\$DOCKER_OPTS --bip=10.66.33.10/24"
# DOCKER HACK END 789527394722
EOF'

fi

sudo docker build -t $image_name $TOP_DIR/

echo -e "\nNote: To let docker work without sudo, add $USER to docker group and restart the X session please.\n"

sure='n'
read -p '* Restart X to make sure docker work without sudo (Y/n): ' sure

if [ "$sure" = 'Y' -o "$sure" = 'y' ]; then
    sudo pkill X
fi
