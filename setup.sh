apt update
apt-get -y install curl
apt-get -y install openjdk-11-jdk
apt-get -y install ruby-full
apt-get -y install build-essential
apt-get -y install python2.7
curl https://bootstrap.pypa.io/pip/2.7/get-pip.py -o get-pip.py
python2.7 get-pip.py
apt-get -y install software-properties-common
add-apt-repository -y ppa:deadsnakes/ppa
apt-get -y install python3.8
apt-get -y install python3-pip
python2.7 -m pip install networkx
python3.8 -m pip install networkx