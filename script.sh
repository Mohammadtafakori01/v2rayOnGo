#!/bin/bash

if [ "$EUID" -ne 0 ]
  then echo "Please run as root user or run with sudo"
  exit
fi

## Check for docker
docker --version
if [ $? -ne 0 ]
  then
    curl -fsSL https://get.docker.com | sh
fi

## Check for docker compose
docker-compose --version
if [ $? -ne 0 ]
  then
    curl -L "https://github.com/docker/compose/releases/download/$(curl --silent "https://api.github.com/repos/docker/compose/releases/latest" | grep -Po '"tag_name": "\K.*?(?=")')/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
    ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose
fi


mkdir log_$1


## Get an UUID
UUID=$(cat /proc/sys/kernel/random/uuid)
if [ $? -ne 0 ]
  then 
  UUID= $(curl -s "https://www.uuidgenerator.net/api/version4" )
fi

## Write config file
cat <<EOF > ./config_$1.json
{
  "log": {
    "access": "/var/log/v2ray/access.log",
    "error": "/var/log/v2ray/error.log",
    "loglevel": "warning"
  },
  "inbounds": [
      {
      "listen": "0.0.0.0",
      "port": 8080,
      "protocol": "vmess",
      "settings": {
        "clients": [
          {
           "id": "$UUID",
          "alterId": 64,
          "security": "chacha20-poly1305"
          }
        ]
      },
      "streamSettings": {
        "network": "tcp",
        "tcpSettings": {
          "header": {
            "type": "http",
            "response": {
              "version": "1.1",
              "status": "200",
              "reason": "OK",
              "headers": {
                "Content-Type": ["application/octet-stream", "application/x-msdownload", "text/html", "application/x-shockwave-flash"],
                "Transfer-Encoding": ["chunked"],
                "Connection": ["keep-alive"],
                "Pragma": "no-cache"
              }
            }
          }
        }
      }
    },{
    "listen": "0.0.0.0",
    "port": $1,
    "protocol": "vmess",
    "settings": {
      "clients": [
        {
          "id": "$UUID",
          "alterId": 0,
          "security": "chacha20-poly1305"
        }
      ]
    },
    "streamSettings": {
      "network": "ws"
    }
  }],
  "outbound": {
    "protocol": "freedom",
    "tag": "freedom"
  },
  "inboundDetour": null,
  "outboundDetour": [
    {
      "protocol": "blackhole",
      "tag": "blackhole"
    }
  ],
  "routing": {
    "domainStrategy": "IPIfNonMatch",
    "settings": {
      "rules": [
        {
          "type": "field",
          "outboundTag": "blackhole",
          "ip": [
            "geoip:private"
          ]
        }
      ]
    }
  }
}
EOF


## Write compose file
cat <<EOF > ./docker-compose_$1.yml
version: "3"
services:
  v2ray_$1:
    image: v2fly/v2fly-core@sha256:51934d93f10451ed416725943e804038fccf18e1756456bacdecdafb3e84486b 
    container_name: v2ray_$1
    restart: always
    ports:
      - $1:$1
      
    volumes:
      - ./config_$1.json:/etc/v2ray/config.json
      - ./log_$1/:/var/log/v2ray/
EOF



docker-compose -f  docker-compose_$1.yml up -d

IP=$(curl -s "https://api.ipify.org/" )

VMESS=$(echo "{\"add\":\"$IP\",\"aid\":\"0\",\"host\":\"digikala.com\",\"id\":\"$UUID\",\"net\":\"ws\",\"path\":\"\",\"port\":\"$1\",\"ps\":\"Foreign-$IP\",\"scy\":\"chacha20-poly1305\",\"sni\":\"\",\"tls\":\"\",\"type\":\"none\",\"v\":\"2\"}" | base64)
VMESS=$(sed "s/\=//g" <<<"$VMESS")
VMESS=$(sed ':a; N; s/[[:space:]]//g; ta' <<<"$VMESS")


VMESSOBFS=$(echo "{\"add\":\"$IP\",\"aid\":\"64\",\"host\":\"\",\"id\":\"$UUID\",\"net\":\"tcp\",\"path\":\"\",\"port\":\"8080\",\"ps\":\"OBFS-Foreign-$IP\",\"scy\":\"auto\",\"sni\":\"\",\"tls\":\"\",\"type\":\"http\",\"v\":\"2\"}" | base64)
VMESSOBFS=$(sed "s/\=//g" <<<"$VMESSOBFS")
VMESSOBFS=$(sed ':a; N; s/[[:space:]]//g; ta' <<<"$VMESSOBFS")

cat <<EOF > ./bridge-install-by-curl-$1.log
  ## Run this command on your bridge(interanet) server:
  sudo curl -s https://gist.githubusercontent.com/mahmoud-eskandari/960899f3494a1bffa1a29631dbaf0aee/raw/f0b012c43e68468e7683c3e4c2a104dd11841eb7/install-bridge.sh | bash -s $IP $1 $UUID
  
  ## If your internal server hasn't access to foreign internet you can also use internal mirror:
   sudo curl -s https://v2rayv2ray.s3.ir-thr-at1.arvanstorage.ir/run.sh | bash -s $IP $1 $UUID
   
   ####### External Vmess connections ######
   
   ============ Diffrent vmess for diffrent ISPs.
   WS foreign vmess (v2ray):
   
   vmess://$VMESS
   
   Server: $IP
   Port: $1
   ID: $UUID
   alterId: 0
   security: chacha20-poly1305
   head type: none
   network: ws
   domain: [An internal website domain like: digikala.com]
   
   ======== ======== ======== ======== 
   
   Obfoscated TCP foreign vmess (v2ray):
   
   vmess://$VMESSOBFS
   
   
   Server: $IP
   Port: 8080
   ID: $UUID
   alterId: 64
   security: chacha20-poly1305
   network: tcp
   head type: http
   domain: [An internal website domain like: digikala.com]
EOF

config_json=$(cat <<EOF
{
  "log": {
    "access": "",
    "error": "",
    "loglevel": "warning"
  },
  "inbounds": [
    {
      "tag": "socks",
      "port": 10808,
      "listen": "127.0.0.1",
      "protocol": "socks",
      "sniffing": {
        "enabled": true,
        "destOverride": [
          "http",
          "tls"
        ]
      },
      "settings": {
        "auth": "noauth",
        "udp": true,
        "allowTransparent": false
      }
    },
    {
      "tag": "http",
      "port": 10809,
      "listen": "127.0.0.1",
      "protocol": "http",
      "sniffing": {
        "enabled": true,
        "destOverride": [
          "http",
          "tls"
        ]
      },
      "settings": {
        "auth": "noauth",
        "udp": true,
        "allowTransparent": false
      }
    }
  ],
  "outbounds": [
    {
      "tag": "proxy",
      "protocol": "vmess",
      "settings": {
        "vnext": [
          {
            "address": "$IP",
            "port": $1,
            "users": [
              {
                "id": "$UUID",
                "alterId": 0,
                "email": "t@t.tt",
                "security": "chacha20-poly1305"
              }
            ]
          }
        ]
      },
      "streamSettings": {
        "network": "ws",
        "wsSettings": {
          "headers": {
            "Host": "digikala.com"
          }
        }
      },
      "mux": {
        "enabled": false,
        "concurrency": -1
      }
    },
    {
      "tag": "direct",
      "protocol": "freedom",
      "settings": {}
    },
    {
      "tag": "block",
      "protocol": "blackhole",
      "settings": {
        "response": {
          "type": "http"
        }
      }
    }
  ],
  "routing": {
    "domainStrategy": "IPIfNonMatch",
    "rules": [
      {
        "type": "field",
        "inboundTag": [
          "api"
        ],
        "outboundTag": "api",
        "enabled": true
      },
      {
        "type": "field",
        "outboundTag": "direct",
        "domain": [
          "domain:example-example.com",
          "domain:example-example2.com"
        ],
        "enabled": true
      },
      {
        "type": "field",
        "outboundTag": "block",
        "domain": [
          "geosite:category-ads-all"
        ],
        "enabled": true
      },
      {
        "type": "field",
        "outboundTag": "direct",
        "domain": [
          "geosite:cn"
        ],
        "enabled": true
      },
      {
        "type": "field",
        "outboundTag": "direct",
        "ip": [
          "geoip:private",
          "geoip:cn"
        ],
        "enabled": true
      },
      {
        "type": "field",
        "port": "0-65535",
        "outboundTag": "proxy",
        "enabled": true
      }
    ]
  }
}
EOF
)

#cat ./bridge-install-by-curl.log
echo "##START##"

echo $config_json | base64


echo "##END##"
