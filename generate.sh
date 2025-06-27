#!/bin/sh

SHELL_FOLDER=$(cd "$(dirname "$0")";pwd)

. ${SHELL_FOLDER}/config

echo "config:"
echo "  - PROXY_GATEWAY = $PROXY_GATEWAY"
echo "  - PROXY_MARK = $PROXY_MARK"
echo "  - PROXY_ROUTE_TABLE = $PROXY_ROUTE_TABLE"
echo "  - DNS_PROXY_PROT = $DNS_PROXY_PROT"
echo "  - DNS_SPEED_CHECK_MODE = $DNS_SPEED_CHECK_MODE"
echo "  - ALLOW_PROXY_DEVICE = $ALLOW_PROXY_DEVICE"
echo "  - FIREWALL_CONFIG = $FIREWALL_CONFIG"
echo "  - DNS_USER_CONF = $DNS_USER_CONF"
echo "  - DIRECT_IPSET_RULES = $DIRECT_IPSET_RULES"
echo "  - IPTABLES_RULES = $IPTABLES_RULES"
echo "  - IP_ROUTE_RULES = $IP_ROUTE_RULES"
echo "  - FIREWALL_RULES = $FIREWALL_RULES"
echo "  - DIRECT_IP_LIST = $DIRECT_IP_LIST"
echo "  - RESERVED_IP_LIST = $RESERVED_IP_LIST"
echo "  - DIRECT_DOMAINS = $DIRECT_DOMAINS"
echo "  - FORCE_DIRECT_DOMAINS = $FORCE_DIRECT_DOMAINS"
echo "  - DIRECT_DNS_SERVERS = $DIRECT_DNS_SERVERS"
echo "  - PROXY_DNS_SERVERS = $PROXY_DNS_SERVERS"
echo "  - DNS_DIRECT_DOMAIN_RULES = $DNS_DIRECT_DOMAIN_RULES"
echo "  - DNS_DIRECT_ADDRESS_RULES = $DNS_DIRECT_ADDRESS_RULES"
echo "  - DNS_DIRECT_SERVER_RULES = $DNS_DIRECT_SERVER_RULES"
echo "  - DNS_PROXY_SERVER_RULES = $DNS_PROXY_SERVER_RULES"
echo "  - DNS_CONF = $DNS_CONF"
echo "  - STARTUP_SCRIPT = $STARTUP_SCRIPT"
echo "  - FORWARD_INTERFACE = $FORWARD_INTERFACE"
echo "  - ENABLE_IPV6_DNS_SERVER = $ENABLE_IPV6_DNS_SERVER"

# file path
DIRECT_IP_LIST=$SHELL_FOLDER/$DIRECT_IP_LIST
RESERVED_IP_LIST=$SHELL_FOLDER/$RESERVED_IP_LIST
DIRECT_DOMAINS=$SHELL_FOLDER/$DIRECT_DOMAINS
FORCE_DIRECT_DOMAINS=$SHELL_FOLDER/$FORCE_DIRECT_DOMAINS
ALLOW_PROXY_DEVICE=$SHELL_FOLDER/$ALLOW_PROXY_DEVICE
DIRECT_IPSET_RULES=$SHELL_FOLDER/$DIRECT_IPSET_RULES
IPTABLES_RULES=$SHELL_FOLDER/$IPTABLES_RULES
IPSET_RULES=$SHELL_FOLDER/$IPSET_RULES
IP_ROUTE_RULES=$SHELL_FOLDER/$IP_ROUTE_RULES
NFT_RULES=$SHELL_FOLDER/output/proxy.nft
FIREWALL_RULES=$SHELL_FOLDER/output/proxy.sh
DIRECT_DNS_SERVERS=$SHELL_FOLDER/$DIRECT_DNS_SERVERS
PROXY_DNS_SERVERS=$SHELL_FOLDER/$PROXY_DNS_SERVERS
DNS_DIRECT_DOMAIN_RULES=$SHELL_FOLDER/$DNS_DIRECT_DOMAIN_RULES
DNS_DIRECT_ADDRESS_RULES=$SHELL_FOLDER/$DNS_DIRECT_ADDRESS_RULES
DNS_DIRECT_SERVER_RULES=$SHELL_FOLDER/$DNS_DIRECT_SERVER_RULES
DNS_PROXY_SERVER_RULES=$SHELL_FOLDER/$DNS_PROXY_SERVER_RULES
DNS_CONF=$SHELL_FOLDER/$DNS_CONF

#[ -n "\"\$\(ipset list $china_ipset\)\"" ] && 

rm -r ${SHELL_FOLDER}/output
mkdir ${SHELL_FOLDER}/output

# generate ipset rules
echo "generate firewall rules"
:> ${NFT_RULES}
# echo "delete table ip proxy" >> ${FIREWALL_RULES}
echo "delete table ip proxy" >> ${NFT_RULES}
echo "add table ip proxy" >> ${NFT_RULES}
echo "add chain ip proxy prerouting_mark { type filter hook prerouting priority -100; policy accept; }" >> ${NFT_RULES}
echo "add chain ip proxy prerouting_redirect { type nat hook prerouting priority -100; policy accept; }" >> ${NFT_RULES}
echo "add set ip proxy direct { type ipv4_addr; flags interval; auto-merge; }" >> ${NFT_RULES}
echo "add set ip proxy allow_proxy_device { type ether_addr; }" >> ${NFT_RULES}
# add direct ip to ipset
cat ${DIRECT_IP_LIST} | sort -u | awk '{print "add element ip proxy direct { " $0 " }"}' >> ${NFT_RULES}
# add reserved ip to ipset
cat ${RESERVED_IP_LIST} | awk '{print "add element ip proxy direct { " $0 " }"}' >> ${NFT_RULES}

# generate iptables rules:
# 1. forwarding traffic with overseas destination to proxy gateway
# 2. forwarding dns request from specific mac address to proxy gateway
while IFS= read MAC_ADDRESS || [ -n "$MAC_ADDRESS" ]
do
    echo "add element ip proxy allow_proxy_device { " MAC_ADDRESS " }" | \
        sed 's/MAC_ADDRESS/'$MAC_ADDRESS'/' >> ${NFT_RULES}

done < $ALLOW_PROXY_DEVICE
echo "add rule ip proxy prerouting_mark ip daddr != @direct ether saddr @allow_proxy_device counter meta mark set PROXY_MARK" | \
    sed 's/PROXY_MARK/'$PROXY_MARK'/' >> ${NFT_RULES}
echo "add rule ip proxy prerouting_redirect ether saddr @allow_proxy_device udp dport 53 counter redirect to DST_PORT" | \
    sed 's/DST_PORT/'$DNS_PROXY_PROT'/' >> ${NFT_RULES}
echo "add rule ip proxy prerouting_redirect ether saddr @allow_proxy_device tcp dport 53 counter redirect to DST_PORT" | \
    sed 's/DST_PORT/'$DNS_PROXY_PROT'/' >> ${NFT_RULES}

:> ${FIREWALL_RULES}
echo "nft -f ${NFT_RULES}" >> ${FIREWALL_RULES}
chmod +x ${FIREWALL_RULES}
echo "generate firewall rules done"

# generate ip route rules
echo "generate ip route rules"
echo "#!/bin/sh" > ${IP_ROUTE_RULES}
echo "ip rule flush table $PROXY_ROUTE_TABLE" >> ${IP_ROUTE_RULES}
echo "ip rule add fwmark $PROXY_MARK lookup $PROXY_ROUTE_TABLE" >> ${IP_ROUTE_RULES}
echo "ip route flush table $PROXY_ROUTE_TABLE" >> ${IP_ROUTE_RULES}
echo "ip route add default via $PROXY_GATEWAY dev $FORWARD_INTERFACE table $PROXY_ROUTE_TABLE" >> ${IP_ROUTE_RULES}
chmod +x ${IP_ROUTE_RULES}
echo "generate ip route rules done"

#server 192.168.1.1 -group home -exclude-default-group

# generate smartdns rules
echo "generate smartdns rules"
# add direct domains to group
sed -e "s|\(.*\)|domain-rules /\1/ -speed-check-mode $DNS_SPEED_CHECK_MODE -nameserver direct|" ${DIRECT_DOMAINS} > ${DNS_DIRECT_DOMAIN_RULES}
# add direct domains to group and insert resolve result to ipset (mainly for improve steam download speed)
sed -e "s|\(.*\)|domain-rules /\1/ -speed-check-mode $DNS_SPEED_CHECK_MODE -nameserver direct -nftset '#4:ip#proxy#direct'|" ${FORCE_DIRECT_DOMAINS} >> ${DNS_DIRECT_DOMAIN_RULES}
# enable ipv6 resolve for direct domains
sed -e "s|\(.*\)|address /\1/-6|" ${DIRECT_DOMAINS} > ${DNS_DIRECT_ADDRESS_RULES}
sed -e "s|\(.*\)|server \1 -group direct --exclude-default-group|" ${DIRECT_DNS_SERVERS} > ${DNS_DIRECT_SERVER_RULES}
# sed -e "s|\(.*\)|server \1|" ${PROXY_DNS_SERVERS} > ${DNS_PROXY_SERVER_RULES}
echo "server ${PROXY_GATEWAY}" > ${DNS_PROXY_SERVER_RULES}
:> ${DNS_CONF}
echo \
'server-name smartdns
serve-expired yes
dnsmasq-lease-file /tmp/dhcp.leases
rr-ttl-min 600
log-size 64K
log-num 1
log-level error
cache-persist yes
cache-file /etc/smartdns/smartdns.cache
force-qtype-SOA  65
resolv-file /tmp/resolv.conf.d/resolv.conf.auto' >> ${DNS_CONF}
# echo "bind :$DNS_DIRECT_PORT -group $DIRECT_DNS_GROUP" >> ${DNS_CONF}
# echo "bind :$DNS_PROXY_PROT" >> ${DNS_CONF}
echo "" >> ${DNS_CONF}
if [ $ENABLE_IPV6_DNS_SERVER == 'true' ]; then
    echo "bind [::]:$DNS_PROXY_PROT" >> ${DNS_CONF}
    echo "bind-tcp [::]:$DNS_PROXY_PROT" >> ${DNS_CONF}
else
    echo "bind :$DNS_PROXY_PROT" >> ${DNS_CONF}
    echo "bind-tcp :$DNS_PROXY_PROT" >> ${DNS_CONF}
fi
# disable ipv6 resolve by default
echo "force-AAAA-SOA yes" >> ${DNS_CONF}
echo "conf-file $DNS_DIRECT_ADDRESS_RULES" >> ${DNS_CONF}
echo "conf-file $DNS_DIRECT_SERVER_RULES" >> ${DNS_CONF}
echo "conf-file $DNS_PROXY_SERVER_RULES" >> ${DNS_CONF}
echo "conf-file $DNS_DIRECT_DOMAIN_RULES" >> ${DNS_CONF}
# generate smartdns rules done

# generate startup script
:> ${STARTUP_SCRIPT}
echo "#execute ipset rules" >> ${STARTUP_SCRIPT}
# echo "sh $DIRECT_IPSET_RULES" >> ${STARTUP_SCRIPT}
echo "#execute iproute rules" >> ${STARTUP_SCRIPT}
echo "sh $IP_ROUTE_RULES" >> ${STARTUP_SCRIPT}
echo "#execute iptables rules" >> ${STARTUP_SCRIPT}
echo "[ -z \"\$(cat $FIREWALL_CONFIG | grep \"$FIREWALL_RULES\")\" ] \\
    && echo \"\" >> $FIREWALL_CONFIG \\
    && echo \"config include 'proxy'\" >> $FIREWALL_CONFIG \\
    && echo -e \"\toption type 'script'\" >> $FIREWALL_CONFIG \\
    && echo -e \"\toption path '$FIREWALL_RULES'\" >> $FIREWALL_CONFIG" >> ${STARTUP_SCRIPT}
echo "fw4 restart" >> ${STARTUP_SCRIPT}
echo "#smartdns conf" >> ${STARTUP_SCRIPT}
# echo "cp $SHELL_FOLDER/smartdns.conf /var/etc/smartdns/" >> ${STARTUP_SCRIPT}
# echo "[ -z \"\$(cat $DNS_USER_CONF | grep \"conf-file $DNS_CONF\")\" ] \\
#     && echo \"\" >> $DNS_USER_CONF \\
#     && echo \"conf-file $DNS_CONF\" >> $DNS_USER_CONF" >> ${STARTUP_SCRIPT}
echo "killall -q smartdns" >> ${STARTUP_SCRIPT} 
echo "smartdns -c $DNS_CONF" >> ${STARTUP_SCRIPT} 
chmod +x ${STARTUP_SCRIPT}

