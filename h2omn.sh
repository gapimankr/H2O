#!/bin/sh

NONE='\033[00m'
RED='\033[01;91m'
GREEN='\033[01;32m'

echo "${RED}Installing required packages, done in 3 steps. ${NONE}";

echo "${RED}1. Do you like install swap file? (y) or (n) ${NONE}";
read SWAPQ
if [ $SWAPQ = 'y' ] || [ $SWAPQ = 'Y' ]
	then
		#setup swap to make sure there's enough memory for compiling the daemon 
		dd if=/dev/zero of=/mnt/myswap.swap bs=1M count=4000
		mkswap /mnt/myswap.swap
		chmod 0600 /mnt/myswap.swap
		swapon /mnt/myswap.swap
		echo "/mnt/myswap.swap    none    swap    sw    0   0" >> /etc/fstab
fi

echo "${RED}2. Do you like install dependencies and updates? (y) or (n) ${NONE}";
read DATAQ
if [ $DATAQ = 'y' ] || [ $DATAQ = 'Y' ]
	then
		#download and install required packages
		sudo apt-get update -y
		sudo apt-get upgrade -y
		sudo apt-get dist-upgrade -y
		sudo apt-get install git -y
		sudo apt-get install curl -y
		sudo apt-get install nano -y
		sudo apt-get install wget -y
		sudo apt-get install htop bc -y
		sudo apt-get install -y pwgen
		sudo apt-get install build-essential libtool automake autoconf -y
		sudo apt-get install autotools-dev autoconf pkg-config libssl-dev -y
		sudo apt-get install libgmp3-dev libevent-dev bsdmainutils libboost-all-dev -y
		sudo apt-get install libzmq3-dev -y
		sudo apt-get install libminiupnpc-dev -y
		sudo add-apt-repository ppa:bitcoin/bitcoin -y
		sudo apt-get update -y
		sudo apt-get install libdb4.8-dev libdb4.8++-dev -y
fi

#get H2O client from github, compile the client
echo "${RED}3. How do you like install client? Download wallet from GitHub *Quicker, BUT use only of last wallet version is 0.12.1.8 (d) or Compiling wallet (c). (d) or (c) ${NONE}";
read INSTALLQ

cd $HOME
if [ $INSTALLQ = 'd' ] || [ $INSTALLQ = 'D' ]
	then
		sudo mkdir $HOME/wallet_h2o && cd wallet_h2o
		wget https://github.com/h2ocore/h2o/releases/download/v0.12.1.8/Linux64-H2O-cli-01218.tgz
		tar -xvf Linux64-H2O-cli-01218.tgz && rm Linux64-H2O-cli-01218.tgz
		chmod +x h2o* && mv h2o* /usr/local/bin && cd $HOME
		rm -r wallet_h2o
		h2od --daemon
		sleep 60
		killall h2od
elif [ $INSTALLQ = 'c' ] || [ $INSTALLQ = 'C' ]
	then
		sudo mkdir $HOME/h2o
		git clone https://github.com/h2ocore/h2o h2o
		cd $HOME/h2o
		chmod 777 autogen.sh
		./autogen.sh
		./configure --disable-tests --disable-gui-tests
		chmod 777 share/genbuild.sh
		sudo make
		sudo make install
		sudo mkdir $HOME/.h2ocore
fi

echo "${GREEN}Installation completed. ${NONE}";

echo "${RED}Paste here your masternode key (right mouse click) and confirm with Enter ${NONE}";
read MNKEY

YOURIP=`wget -qO- ident.me`
PSS=`pwgen -1 20 -n`

echo "rpcuser=user"                   > /$HOME/.h2ocore/h2o.conf
echo "rpcpassword=$PSS"              >> /$HOME/.h2ocore/h2o.conf
echo "rpcallowip=127.0.0.1"          >> /$HOME/.h2ocore/h2o.conf
echo "maxconnections=500"            >> /$HOME/.h2ocore/h2o.conf
echo "daemon=1"                      >> /$HOME/.h2ocore/h2o.conf
echo "server=1"                      >> /$HOME/.h2ocore/h2o.conf
echo "listen=1"                      >> /$HOME/.h2ocore/h2o.conf
echo "rpcport=13356"                 >> /$HOME/.h2ocore/h2o.conf
echo "externalip=$YOURIP:13355"      >> /$HOME/.h2ocore/h2o.conf
echo "bind=$YOURIP"      			 >> /$HOME/.h2ocore/h2o.conf
echo "masternodeprivkey=$MNKEY"      >> /$HOME/.h2ocore/h2o.conf
echo "masternode=1"                  >> /$HOME/.h2ocore/h2o.conf

h2od --daemon
sleep 30
echo "${RED}Waiting for your h2o client to fully sync with the network, this can take a while. ${NONE}";

block=1
while true
do
	realblock=`h2o-cli getblockcount` 
	explorerblock=`wget -qO- http://explorer.h2ocore.org/api/getblockcount` #explorer API 
	percent=`echo "scale=2 ; (100*$realblock/$explorerblock)" | bc`
	printf "\rBlock: $realblock/$explorerblock - Done: ${GREEN}$percent%% ${NONE}" #write block
	if [ $realblock -eq $block ] #check block if is done
	then 
		sleep 60
		realblock=$((`h2o-cli getblockcount`))
		if [ $realblock -eq $block ] #second check block if is done
		then 
			echo ""
			echo "${RED}Synced will be done in 4 steps. ${NONE}"
			break
		fi
	fi
	block=$((realblock))
	sleep 5	
done

echo "${RED}1. Blockchain sync start.${NONE}"
until h2o-cli mnsync status | grep -m 1 '"IsBlockchainSynced": true'; do sleep 1 ; done > /dev/null 2>&1
echo "${GREEN}BlockchainSynced done. ${NONE}"

echo "${RED}2. Masternode List sync start.${NONE}"
until h2o-cli mnsync status | grep -m 1 '"IsMasternodeListSynced": true'; do sleep 1 ; done > /dev/null 2>&1
echo "${GREEN}MasternodeListSynced done. ${NONE}"

echo "${RED}3. Winners List sync start.${NONE}"
until h2o-cli mnsync status | grep -m 1 '"IsWinnersListSynced": true'; do sleep 1 ; done > /dev/null 2>&1
echo "${GREEN}WinnersListSynced done. ${NONE}"

echo "${RED}4. Sync start.${NONE}"
until h2o-cli mnsync status | grep -m 1 '"IsSynced": true'; do sleep 1 ; done > /dev/null 2>&1
echo "${GREEN}Sync done. ${NONE}"

echo "${RED}Setting up your VPS is finish. You can now start MasterNode in your wallet. ${NONE}"; 

echo "${RED}Waiting that MasterNode start.${NONE}"
until h2o-cli masternode status | grep -m 1 '"status": "Masternode successfully started"'; do sleep 1 ; done > /dev/null 2>&1
echo "${GREEN}Done! Masternode successfully started, now you can close connection and wait until in your wallet will write ENABLED.${NONE}"

echo ""
echo "If this guild help you, then you can sent me some tips ;)"
echo "H2O HivcNFzyC6MeW9mUXDyQth4fTBV1JfoUmw"
echo "BTC 12nxh3nUTJHve3XGaXrh692xQZMVLJLFJm"
echo "DOGE DJbHoCkzwzqjyrJxT1hGwN1rzZdJFzBseG"