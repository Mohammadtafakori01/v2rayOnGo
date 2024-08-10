#!/bin/bash

GO_VERSION="1.20.5"

wget https://go.dev/dl/go$GO_VERSION.linux-amd64.tar.gz

sudo rm -rf /usr/local/go

sudo tar -C /usr/local -xzf go$GO_VERSION.linux-amd64.tar.gz

echo "export PATH=\$PATH:/usr/local/go/bin" >> ~/.profile

source ~/.profile

go version

rm go$GO_VERSION.linux-amd64.tar.gz

echo "Go $GO_VERSION has been installed successfully."
