# epc-docker-scripts

Support Scripts to Install, Deploy and Remove the OAI EPC CN.

A special mention to Damodar Dharmaiah for supplying the original set of scripts from which these were derived.

The scripts assume docker has been installed and that the user has been added to the docker group as described on this website,  https://docs.docker.com/engine/install/ubuntu/

curl -fsSL https://get.docker.com -o get-docker.sh
$ sudo sh get-docker.sh


If you would like to use Docker as a non-root user, you should now consider adding your user to the “docker” group with something like:

  sudo usermod -aG docker your-user


The script build_oai_nsa_epc grabs all the necessary code and builds all the EPC containers as of the 09/10/2020. They will probably need to be altered to support more recent OAI CN commits as the design is under constant change.  If you update them, please share your changes. 

To use it just type ./build_oai_nsa_epc.sh from the user home directory.
Similarly, to remove the lot type ./remove_oai_nsa_epc.sh.   Caution, it will remove the lot.
Once the containers are built the build script copies the shell script oai-epc-nsa-launch.sh into the ~/oai-epc/openair-epc-fed directory and 
then users can use Damodar's original commands to deploy, start retrieve, undeploy the containers.

For example, to deploy and start the containers
cd ~/oai-epc/openair-epc-fed 
./oai-epc-nsa-launch.sh --deploy --start

Now, a few things to watch out for.

The launch script uses my settings for the mcc, mnc, apn1, apn2, key, op, imsi, imsi count.

These need to be changed to match the users desired settings.





