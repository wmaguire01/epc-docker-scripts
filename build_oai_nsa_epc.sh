#!/bin/bash
#init

set -e 
#set -x
#set -n #Dry run

function pause(){
   read -p "$*"
}


cd ~
DIR="oai-epc" 
 
if [ ! -d "$DIR" ]; then
  echo "Setting up home directory for the EPC containers..."
  mkdir oai-epc
fi 

cd $DIR
echo $PWD

docker pull ubuntu:bionic
docker pull cassandra:2.1

git clone https://github.com/OPENAIRINTERFACE/openair-epc-fed.git
cd openair-epc-fed
git checkout master
git pull origin master
source ./scripts/syncComponents.sh 

docker build --target oai-hss --tag oai-hss:production --file component/oai-hss/ci-scripts/Dockerfile.ubuntu18.04 .
docker build --target oai-mme --tag oai-mme:production --file component/oai-mme/ci-scripts/Dockerfile.ubuntu18.04 .
docker build --target oai-spgwc --tag oai-spgwc:production --file component/oai-spgwc/ci-scripts/Dockerfile.ubuntu18.04 .
docker build --target oai-spgwu-tiny --tag oai-spgwu-tiny:production --file component/oai-spgwu-tiny/ci-scripts/Dockerfile.ubuntu18.04 .
cd ci-scripts
docker build --target trf-gen --tag trf-gen:production --file Dockerfile.traffic.generator.ubuntu18.04 .

docker image prune --force
docker image ls

cd openair-epc-fed 
cp ~/oai-epc-nsa-launch.sh .
chmod +x oai-epc-nsa-launch.sh



