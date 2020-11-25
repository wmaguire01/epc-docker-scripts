#!/bin/bash
#init
function pause(){
   read -p "$*"
}

DEPLOY=0
START_CNF=0
STOP_CNF=0
RETRIEVE_LOGS=0
UNDEPLOY=0

if [ -z "$1" ]
  then
    echo "No argument supplied"
    echo "Usage ./oai-epc-nsa-launch --option,   Options are ..."
    echo "--deploy, --start, --undeploy, --retrieve-logs --help"
    exit 0
fi

while [[ $# -gt 0 ]]
do
    key="$1"

    case $key in
    --deploy)
    DEPLOY=1
    shift
    ;;
    --start)
    START_CNF=1
    shift
    ;;
    --stop)
    STOP_CNF=1
    shift
    ;;
    --retrieve-logs)
    RETRIEVE_LOGS=1
    shift
    ;;
    --undeploy)
    UNDEPLOY=1
    shift
    ;;
    *| --help)  # unknown argument
    echo "Usage ./oai-epc-nsa-launch --option,   Options are ..."
    echo "--deploy, --start, --undeploy, --retrieve-logs --help"
    exit 0
    ;;
    esac

done

if [ $DEPLOY -eq 1 ]
then
    # ADAPT TO YOUR ENV
    #./scripts/syncComponents.sh --mme-branch samsumg-s10-5g-g977u-merged > /dev/null 2>&1
    sudo sysctl net.ipv4.conf.all.forwarding=1
    sudo iptables -P FORWARD ACCEPT

    FILE=./hss-cfg.sh
    if [ -f "$FILE" ]; then
      echo "Deleting $FILE..."
      rm ./hss-cfg.sh
    fi 

    FILE=./mme-cfg.sh
    if [ -f "$FILE" ]; then
      echo "Deleting $FILE..."
      rm ./mme-cfg.sh
    fi 
    FILE=./spgwc-cfg.sh
    if [ -f "$FILE" ]; then
      echo "Deleting $FILE..."
      rm ./spgwc-cfg.sh
    fi 
    FILE=./spgwu-cfg.sh
    if [ -f "$FILE" ]; then
      echo "Deleting $FILE..."
      rm ./spgwu-cfg.sh
    fi 


    if [ `docker network ls | grep -c prod-oai-public-net` -eq 0 ]
    then
    	echo "Setting Up the EPC Network ..."
        #docker network create --attachable --subnet 192.168.61.100/26 --ip-range 192.168.61.100/26 prod-oai-public-net
        docker network create --attachable --subnet 192.168.61.0/26 --ip-range 192.168.61.0/26 prod-oai-public-net

    fi

    echo "Deploying the EPC docker containers, please wait ..."
    docker run --name prod-cassandra -d -e CASSANDRA_CLUSTER_NAME="OAI HSS Cluster" -e CASSANDRA_ENDPOINT_SNITCH=GossipingPropertyFileSnitch cassandra:2.1
    docker run --privileged --name prod-oai-hss -d --entrypoint /bin/bash oai-hss:production -c "sleep infinity"
    docker network connect prod-oai-public-net prod-oai-hss
    docker run --privileged --name prod-oai-mme --network prod-oai-public-net -d --entrypoint /bin/bash oai-mme:production -c "sleep infinity"
    docker run --privileged --name prod-oai-spgwc --network prod-oai-public-net -d --entrypoint /bin/bash oai-spgwc:production -c "sleep infinity"
    docker run --privileged --name prod-oai-spgwu-tiny --network prod-oai-public-net -d --entrypoint /bin/bash oai-spgwu-tiny:production -c "sleep infinity"
    docker run --privileged --name prod-trf-gen --network prod-oai-public-net -d trf-gen:production /bin/bash -c "sleep infinity"
    
    sleep 10
    echo "Waiting for container deployment to complete ..."
	
	echo
	echo "Configuring Cassandra container ..."
    docker cp component/oai-hss/src/hss_rel14/db/oai_db.cql prod-cassandra:/home
    docker exec -it prod-cassandra /bin/bash -c "nodetool status"
    sleep 2
    Cassandra_IP=`docker inspect --format="{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}" prod-cassandra`
    docker exec -it prod-cassandra /bin/bash -c "cqlsh --file /home/oai_db.cql ${Cassandra_IP}"
    echo "Cassandra_IP:= ${Cassandra_IP}"


  	echo
	echo "Configuring HSS container ..."
    sleep 2
	
    HSS_IP=`docker exec -it prod-oai-hss /bin/bash -c "ifconfig eth1 | grep inet" | sed -f ./ci-scripts/convertIpAddrFromIfconfig.sed`
    #python3 component/oai-hss/ci-scripts/generateConfigFiles.py --kind=HSS --cassandra=${Cassandra_IP} --hss_s6a=${HSS_IP} \
    #	--apn1=wap.tim.it --apn2=internet  \
    #	--users=200 --imsi=222010100000001 \
    #	--ltek=fec86ba6eb707ed08905757b1bb44b8f --op=1006020f0a478bf6b699f15c062e42b3 --from_docker_file

    python3 component/oai-hss/ci-scripts/generateConfigFiles.py --kind=HSS --cassandra=${Cassandra_IP} \
        --hss_s6a=${HSS_IP} --apn1=apn1.carrier.com --apn2=apn2.carrier.com \
        --users=200 --imsi=505010100000001 \
        --ltek=0c0a34601d4f07677303652c0462535b --op=63bfa50ee6523365ff14c1f45f88737d \
        --nb_mmes=1 --from_docker_file

    docker cp ./hss-cfg.sh prod-oai-hss:/openair-hss/scripts
    pause 'Press [Enter] key to continue...'
    sleep 2
    docker exec -it prod-oai-hss /bin/bash -c "cd /openair-hss/scripts && chmod 777 hss-cfg.sh && ./hss-cfg.sh"
    echo "Configuring HSS container complete, HSS_IP:= ${HSS_IP}"
    sleep 2
    pause 'Press [Enter] key to continue...'

 	echo
	echo "Configuring MME container ..."
    MME_IP=`docker inspect --format="{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}" prod-oai-mme`
    SPGW0_IP=`docker inspect --format="{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}" prod-oai-spgwc`
    #python3 component/oai-mme/ci-scripts/generateConfigFiles.py --kind=MME \
    #        --hss_s6a=${HSS_IP} --mme_s6a=${MME_IP} \
    #		--mme_s1c_IP=${MME_IP} --mme_s1c_name=eth0 \
    #		--mme_s10_IP=${MME_IP} --mme_s10_name=eth0 \
    #		--mme_s11_IP=${MME_IP} --mme_s11_name=eth0 --spgwc0_s11_IP=${SPGW0_IP} \
    #		--mcc=222 --mnc=01 --tac_list="1 2 3" --from_docker_file
   

	python3 component/oai-mme/ci-scripts/generateConfigFiles.py --kind=MME \
        --hss_s6a=${HSS_IP} --mme_s6a=${MME_IP} \
        --mme_s1c_IP=${MME_IP} --mme_s1c_name=eth0 \
        --mme_s10_IP=${MME_IP} --mme_s10_name=eth0 \
        --mme_s11_IP=${MME_IP} --mme_s11_name=eth0 --spgwc0_s11_IP=${SPGW0_IP} \
        --mcc=505 --mnc=01 --tac_list="1" --from_docker_file

 	docker cp ./mme-cfg.sh prod-oai-mme:/openair-mme/scripts
    sleep 2
    docker exec -it prod-oai-mme /bin/bash -c "cd /openair-mme/scripts && chmod 777 mme-cfg.sh && ./mme-cfg.sh"
    echo "Configuring MME container complete, MME_IP:= ${MME_IP}, SPGW0_IP:= ${SPGW0_IP}"

    echo
    echo "Configuring SPGW-C container"
    #python3 component/oai-spgwc/ci-scripts/generateConfigFiles.py --kind=SPGW-C \
    #        --s11c=eth0 --sxc=eth0 --apn=wap.tim.it --from_docker_file
	python3 component/oai-spgwc/ci-scripts/generateConfigFiles.py --kind=SPGW-C --s11c=eth0 --sxc=eth0 --apn=apn1.carrier.com --dns1_ip=8.8.8.8 --dns2_ip=8.8.4.4 --from_docker_file
    docker cp ./spgwc-cfg.sh prod-oai-spgwc:/openair-spgwc
    docker exec -it prod-oai-spgwc /bin/bash -c "cd /openair-spgwc && chmod 777 spgwc-cfg.sh && ./spgwc-cfg.sh"
    echo "Configuring  SPGW-C container complete."

    echo
    echo "Configuring SPGW-U container"
    #python3 component/oai-spgwu-tiny/ci-scripts/generateConfigFiles.py --kind=SPGW-U \
    #      --sxc_ip_addr=${SPGW0_IP} --sxu=eth0 --s1u=eth0 --from_docker_file
    python3 component/oai-spgwu-tiny/ci-scripts/generateConfigFiles.py --kind=SPGW-U --sxc_ip_addr=${SPGW0_IP} --sxu=eth0 --s1u=eth0 --from_docker_file
    docker cp ./spgwu-cfg.sh prod-oai-spgwu-tiny:/openair-spgwu-tiny
    docker exec -it prod-oai-spgwu-tiny /bin/bash -c "cd /openair-spgwu-tiny && chmod 777 spgwu-cfg.sh && ./spgwu-cfg.sh"
    echo "Configuring  SPGW-U container complete."

    # adding a route for the UE IP pool to SPGW-U container
    SPGWU_IP=`docker inspect --format="{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}" prod-oai-spgwu-tiny`
    docker exec -it prod-trf-gen /bin/bash -c "ip route add 12.1.1.0/24 via ${SPGWU_IP} dev eth0"
    echo "Configuring SPGW-U complete, SPGWU_IP:= ${SPGWU_IP}"
fi

if [ $START_CNF -eq 1 ]
then
	echo "Setting up wireshark capture, Please wait ..."
    docker exec -d prod-oai-hss /bin/bash -c "nohup tshark -i eth0 -i eth1 -w /tmp/hss_check_run.pcap 2>&1 > /dev/null"
    docker exec -d prod-oai-mme /bin/bash -c "nohup tshark -i eth0 -i lo:s10 -w /tmp/mme_check_run.pcap 2>&1 > /dev/null"
    docker exec -d prod-oai-spgwc /bin/bash -c "nohup tshark -i eth0 -i lo:p5c -i lo:s5c -w /tmp/spgwc_check_run.pcap 2>&1 > /dev/null"
    docker exec -d prod-oai-spgwu-tiny /bin/bash -c "nohup tshark -i eth0 -w /tmp/spgwu_check_run.pcap 2>&1 > /dev/null"
    sleep 20

    echo "Starting up the EPC Components, please wait ..."

    echo "Starting HSS ..."
    docker exec -d prod-oai-hss /bin/bash -c "nohup ./bin/oai_hss -j ./etc/hss_rel14.json --reloadkey true > hss_check_run.log 2>&1"
    sleep 5
    echo "Starting MME ..."
    docker exec -d prod-oai-mme /bin/bash -c "nohup ./bin/oai_mme -c ./etc/mme.conf > mme_check_run.log 2>&1"
    sleep 5
    echo "Starting SPGW-C ..."
    docker exec -d prod-oai-spgwc /bin/bash -c "nohup ./bin/oai_spgwc -o -c ./etc/spgw_c.conf > spgwc_check_run.log 2>&1"
    sleep 5
    echo "Starting SPGW-U ..."
    docker exec -d prod-oai-spgwu-tiny /bin/bash -c "nohup ./bin/oai_spgwu -o -c ./etc/spgw_u.conf > spgwu_check_run.log 2>&1"
    MME_IP=`docker inspect --format="{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}" prod-oai-mme`
    echo "##########################################################################################################"
    echo "Please make sure that your enb/gnb conf file uses $MME_IP as MME IP ADDRESS"
    echo "##########################################################################################################"
fi

if [ $STOP_CNF -eq 1 ]
then
    docker exec -it prod-oai-hss /bin/bash -c "killall --signal SIGINT oai_hss tshark"
    docker exec -it prod-oai-mme /bin/bash -c "killall --signal SIGINT oai_mme tshark"
    docker exec -it prod-oai-spgwc /bin/bash -c "killall --signal SIGINT oai_spgwc tshark"
    docker exec -it prod-oai-spgwu-tiny /bin/bash -c "killall --signal SIGINT oai_spgwu tshark"
fi

if [ $RETRIEVE_LOGS -eq 1 ]
then
    #cd /tmp/CI-CN-FED
    rm -Rf archives
    mkdir -p archives/oai-hss-cfg archives/oai-mme-cfg archives/oai-spgwc-cfg archives/oai-spgwu-cfg
    docker cp prod-oai-hss:/openair-hss/etc/. archives/oai-hss-cfg
    docker cp prod-oai-mme:/openair-mme/etc/. archives/oai-mme-cfg
    docker cp prod-oai-spgwc:/openair-spgwc/etc/. archives/oai-spgwc-cfg
    docker cp prod-oai-spgwu-tiny:/openair-spgwu-tiny/etc/. archives/oai-spgwu-cfg
    docker cp prod-oai-hss:/openair-hss/hss_check_run.log archives
    docker cp prod-oai-mme:/openair-mme/mme_check_run.log archives
    docker cp prod-oai-spgwc:/openair-spgwc/spgwc_check_run.log archives
    docker cp prod-oai-spgwu-tiny:/openair-spgwu-tiny/spgwu_check_run.log archives
    docker cp prod-oai-hss:/tmp/hss_check_run.pcap archives
    docker cp prod-oai-mme:/tmp/mme_check_run.pcap archives
    docker cp prod-oai-spgwc:/tmp/spgwc_check_run.pcap archives
    docker cp prod-oai-spgwu-tiny:/tmp/spgwu_check_run.pcap archives
fi

if [ $UNDEPLOY -eq 1 ]
then
	echo "Stopping all EPC Containers "
	docker container stop -f prod-cassandra prod-oai-hss prod-oai-mme prod-oai-spgwc prod-oai-spgwu-tiny prod-trf-gen
    docker container rm -f prod-cassandra prod-oai-hss prod-oai-mme prod-oai-spgwc prod-oai-spgwu-tiny prod-trf-gen
    # ADAPT --> YOU MAY WANT TO COMMENT FOR YOUR ENV
    if [ `docker network ls | grep -c prod-oai-public-net` -eq 1 ]
    then
    	echo "Removing all EPC docker networks.."
        docker network rm prod-oai-public-net
    fi
fi

