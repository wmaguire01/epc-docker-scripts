#!/bin/bash
#init

set -e 

cd ~
DIR="oai-epc" 

while true; do
       read -p "Warnning !!! Entering Y will remove the OAI EPC docker containers from this system?  :  " yn
       case $yn in
           [Yy]* )
				if [[ $(docker images | grep 'trf-gen') ]]; then
					docker rmi $(docker images 'trf-gen' -q) --force
				fi

				if [[ $(docker images | grep 'oai-spgwu-tiny') ]]; then
				    docker rmi $(docker images 'oai-spgwu-tiny' -q) --force
				fi
				if [[ $(docker images | grep 'oai-spgwc') ]]; then
				    docker rmi $(docker images 'oai-spgwc' -q) --force
				fi
				if [[ $(docker images | grep 'oai-mme') ]]; then
				    docker rmi $(docker images 'oai-mme' -q) --force
				fi
				if [[ $(docker images | grep 'oai-hss') ]]; then
				    docker rmi $(docker images 'oai-hss' -q) --force
				fi
				if [[ $(docker images | grep 'cassandra') ]]; then
				    docker rmi $(docker images 'cassandra' -q) --force
				fi
				if [[ $(docker images | grep 'ubuntu') ]]; then
				    docker rmi $(docker images 'ubuntu' -q) --force
				fi				
				if [ -d "$DIR" ]; then
				  echo "Deleting ${DIR} ... "
				  rm -rf oai-epc
				fi 
				exit
                ;;
            
           [Nn]* ) exit;;
            * ) echo "Please answer yes or no.";;
    esac
done

docker image ls




