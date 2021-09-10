#!/bin/bash
# wget -q -O polkadex.sh https://api.nodes.guru/polkadex.sh && chmod +x polkadex.sh && sudo /bin/bash polkadex.sh



exists()
{
  command -v "$1" >/dev/null 2>&1
}
if exists curl; then
	echo ''
else
  sudo apt install curl -y < "/dev/null"
fi
bash_profile=$HOME/.bash_profile
if [ -f "$bash_profile" ]; then
    . $HOME/.bash_profile
fi
sleep 1 && curl -s https://api.nodes.guru/logo.sh | bash && sleep 3

function setupVars {
	if [ ! $POLKADEX_NODENAME ]; then
		read -p "Enter your node name: " POLKADEX_NODENAME_ORIGINAL
		echo 'export POLKADEX_NODENAME="'${POLKADEX_NODENAME_ORIGINAL}' | NASAN NODES"' >> $HOME/.bash_profile
		echo 'export POLKADEX_NODENAME_ORIGINAL='${POLKADEX_NODENAME_ORIGINAL} >> $HOME/.bash_profile
	fi
	echo -e '\n\e[42mYour node name:' $POLKADEX_NODENAME_ORIGINAL '\e[0m\n'
	. $HOME/.bash_profile
	sleep 1
}

function setupSwap {
	echo -e '\n\e[42mSet up swapfile\e[0m\n'
	curl -s https://api.nodes.guru/swap4.sh | bash
}

function installRust {
	echo -e '\n\e[42mInstall Rust\e[0m\n' && sleep 1
	sudo curl https://sh.rustup.rs -sSf | sh -s -- -y
	# curl https://getsubstrate.io -sSf | bash -s -- --fast 
	. $HOME/.cargo/env
	rustup toolchain add nightly-2021-05-11
	rustup target add wasm32-unknown-unknown --toolchain nightly-2021-05-11
	rustup target add x86_64-unknown-linux-gnu --toolchain nightly-2021-05-11
}

function installDeps {
	echo -e '\n\e[42mPreparing to install\e[0m\n' && sleep 1
	cd $HOME
	sudo apt update
	sudo apt install make clang pkg-config libssl-dev build-essential git jq llvm libudev-dev -y < "/dev/null"
	installRust
}

function installSoftware {
	echo -e '\n\e[42mInstall software\e[0m\n' && sleep 1
	cd $HOME
	git clone https://github.com/Polkadex-Substrate/Polkadex.git
	# curl -O -L https://github.com/Polkadex-Substrate/Polkadex/releases/download/v0.4.0/customSpecRaw.json
	curl -O -L https://github.com/Polkadex-Substrate/Polkadex/releases/download/v0.4.1-rc5/customSpecRaw.json
	cd Polkadex
	# git checkout v0.4.0
	# git checkout 33f3826bb73e84884caaf44a5d651f6d32d52031
	git checkout v0.4.1-rc5
	cargo build --release
}

function updateSoftware {
	echo -e '\n\e[42mUpdate software\e[0m\n' && sleep 1
	sudo systemctl stop polkadexd
	cd $HOME
	$HOME/Polkadex/target/release/polkadex-node purge-chain --chain=$HOME/customSpecRaw.json -y
	curl -O -L https://github.com/Polkadex-Substrate/Polkadex/releases/download/v0.4.1-rc5/customSpecRaw.json
	cd $HOME/Polkadex
	git reset --hard
	git pull origin main
	git checkout v0.4.1-rc5
	cargo build --release
}

function installService {
echo -e '\n\e[42mRunning\e[0m\n' && sleep 1
echo -e '\n\e[42mCreating a service\e[0m\n' && sleep 1

sudo tee <<EOF >/dev/null $HOME/polkadexd.service
[Unit]
Description=Polkadex Node
After=network-online.target
[Service]
User=$USER
ExecStart=$HOME/Polkadex/target/release/polkadex-node --chain=$HOME/customSpecRaw.json --rpc-cors=all --bootnodes /ip4/13.235.190.203/tcp/30333/p2p/12D3KooWC7VKBTWDXXic5yRevk8WS8DrDHevvHYyXaUCswM18wKd --pruning=archive --validator --name '${POLKADEX_NODENAME}'
Restart=always
RestartSec=3
LimitNOFILE=10000
[Install]
WantedBy=multi-user.target
EOF

sudo mv $HOME/polkadexd.service /etc/systemd/system
sudo tee <<EOF >/dev/null /etc/systemd/journald.conf
Storage=persistent
EOF
sudo systemctl restart systemd-journald
sudo systemctl daemon-reload
echo -e '\n\e[42mRunning a service\e[0m\n' && sleep 1
sudo systemctl enable polkadexd
sudo systemctl restart polkadexd
echo -e '\n\e[42mCheck node status\e[0m\n' && sleep 1
if [[ `service polkadexd status | grep active` =~ "running" ]]; then
  echo -e "Your Polkadex node \e[32minstalled and works\e[39m!"
  echo -e "You can check node status by the command \e[7mservice polkadexd status\e[0m or \e[7mjournalctl -u polkadexd -f\e[0m"
  # echo -e "Your node identity is: \e[7m" && journalctl -u polkadexd | grep "Local node identity is: " | awk -F "[, ]+" '/Local node identity is: /{print $NF}' && echo -e "\e[0m"
  echo -e "Rotate your keys by the following command:"
  echo -e "\e[7mcurl -s -H \"Content-Type: application/json\" -d '{\"id\":1, \"jsonrpc\":\"2.0\", \"method\": \"author_rotateKeys\", \"params\":[]}' http://127.0.0.1:9933 | jq .result | sed 's/\"//g'\e[0m"
  echo -e "Press \e[7mQ\e[0m for exit from status menu"
else
  echo -e "Your Polkadex node \e[31mwas not installed correctly\e[39m, please reinstall."
fi
. $HOME/.bash_profile
}

function deletePolkadex {
	sudo systemctl disable polkadexd
	sudo systemctl stop polkadexd
}

PS3='Please enter your choice (input your option number and press enter): '
options=("Install" "Update" "Disable" "Quit")
select opt in "${options[@]}"
do
    case $opt in
        "Install")
            echo -e '\n\e[42mYou choose install...\e[0m\n' && sleep 1
			setupVars
			setupSwap
			installDeps
			installSoftware
			installService
			break
            ;;
        "Update")
            echo -e '\n\e[33mYou choose update...\e[0m\n' && sleep 1
			updateSoftware
			installService
			echo -e '\n\e[33mYour node was updated!\e[0m\n' && sleep 1
			break
            ;;
		"Disable")
            echo -e '\n\e[31mYou choose disable...\e[0m\n' && sleep 1
			deletePolkadex
			echo -e '\n\e[42mPolkadex was disabled!\e[0m\n' && sleep 1
			break
            ;;
        "Quit")
            break
            ;;
        *) echo -e "\e[91minvalid option $REPLY\e[0m";;
    esac
done