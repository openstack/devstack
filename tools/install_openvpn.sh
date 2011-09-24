# rough history from wilk - need to cleanup
apt-get install -y openvpn bridge-utils
cp -R /usr/share/doc/openvpn/examples/easy-rsa/2.0/ /etc/openvpn/easy-rsa/
cd /etc/openvpn/easy-rsa
source vars
./clean-all
./build-dh
./pkitool --initca
./pkitool --server server
./pkitool client1
cd keys
openvpn --genkey --secret ta.key  ## Build a TLS key
cp server.crt server.key ca.crt dh1024.pem ta.key ../../
cd ../../

cat >/etc/openvpn/server.conf <<EOF
duplicate-cn
port 6081
proto tcp
dev tun
ca ca.crt
cert server.crt
key server.key  # This file should be kept secret
dh dh1024.pem
server 172.16.28.0 255.255.255.0
ifconfig-pool-persist ipp.txt
push "route 10.0.0.0 255.255.255.224"
comp-lzo
persist-key
persist-tun
status openvpn-status.log
EOF
/etc/init.d/openvpn restart

echo Use the following ca for your client:
cat /etc/openvpn/ca.crt

echo
echo Use the following cert for your client
cat /etc/openvpn/easy-rsa/keys/client1.crt 
echo
echo Use the following key for your client
cat /etc/openvpn/easy-rsa/keys/client1.key 
echo
echo Use the following client config:
cat <<EOF
ca ca.crt
cert client.crt
key client.key
client
dev tun
proto tcp
remote 50.56.12.212 6081
resolv-retry infinite
nobind
persist-key
persist-tun
comp-lzo
verb 3
EOF
