#!/bin/sh

SHELL_FOLDER=$(cd "$(dirname "$0")";pwd)
echo "shell foler: $SHELL_FOLDER"

. ${SHELL_FOLDER}/config

echo "config:"
echo "  - PROXY_GATEWAY = $PROXY_GATEWAY"
echo "  - DIRECT_IPSET = $DIRECT_IPSET"
echo "  - DIRECT_DNS_GROUP = $DIRECT_DNS_GROUP"
echo "  - PROXY_MARK = $PROXY_MARK"
echo "  - PROXY_ROUTE_TABLE = $PROXY_ROUTE_TABLE"
echo "  - DNS_PROXY_PROT = $DNS_PROXY_PROT"
echo "  - DNS_DIRECT_PORT = $DNS_DIRECT_PORT"
echo "  - DNS_SPEED_CHECK_MODE = $DNS_SPEED_CHECK_MODE"
echo "  - ALLOW_PROXY_DEVICE = $ALLOW_PROXY_DEVICE"
echo "  - FIREWALL_USER_CONFIG = $FIREWALL_USER_CONFIG"
echo "  - DNS_USER_CONF = $DNS_USER_CONF"
echo "  - DIRECT_IPSET_RULES = $DIRECT_IPSET_RULES"
echo "  - IPTABLES_RULES = $IPTABLES_RULES"
echo "  - IP_ROUTE_RULES = $IP_ROUTE_RULES"
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
IP_ROUTE_RULES=$SHELL_FOLDER/$IP_ROUTE_RULES
DIRECT_DNS_SERVERS=$SHELL_FOLDER/$DIRECT_DNS_SERVERS
PROXY_DNS_SERVERS=$SHELL_FOLDER/$PROXY_DNS_SERVERS
DNS_DIRECT_DOMAIN_RULES=$SHELL_FOLDER/$DNS_DIRECT_DOMAIN_RULES
DNS_DIRECT_ADDRESS_RULES=$SHELL_FOLDER/$DNS_DIRECT_ADDRESS_RULES
DNS_DIRECT_SERVER_RULES=$SHELL_FOLDER/$DNS_DIRECT_SERVER_RULES
DNS_PROXY_SERVER_RULES=$SHELL_FOLDER/$DNS_PROXY_SERVER_RULES
DNS_CONF=$SHELL_FOLDER/$DNS_CONF

#[ -n "\"\$\(ipset list $china_ipset\)\"" ] && 

# generate ipset rules
echo "generate ipset rules"
echo "#!/bin/sh" > ${DIRECT_IPSET_RULES}
echo "ipset destroy $DIRECT_IPSET" >> ${DIRECT_IPSET_RULES}
echo "ipset create $DIRECT_IPSET hash:net hashsize 16384 maxelem 262144" >> ${DIRECT_IPSET_RULES}
# add direct ip to ipset
cat ${DIRECT_IP_LIST} | awk -v DIRECT_IPSET=$DIRECT_IPSET '{print "ipset add " DIRECT_IPSET " " $0}' >> ${DIRECT_IPSET_RULES}
# add reserved ip to ipset
cat ${RESERVED_IP_LIST} | awk -v DIRECT_IPSET=$DIRECT_IPSET '{print "ipset add " DIRECT_IPSET " " $0}' >> ${DIRECT_IPSET_RULES}
chmod +x ${DIRECT_IPSET_RULES}
echo "generate ipset rules done"

#server 192.168.1.1 -group home -exclude-default-group

# generate smartdns rules
echo "generate smartdns rules"
# add direct domains to group
sed -e "s|\(.*\)|domain-rules /\1/ -speed-check-mode $DNS_SPEED_CHECK_MODE -nameserver $DIRECT_DNS_GROUP|" ${DIRECT_DOMAINS} > ${DNS_DIRECT_DOMAIN_RULES}
# add direct domains to group and insert resolve result to ipset (mainly for improve steam download speed)
sed -e "s|\(.*\)|domain-rules /\1/ -speed-check-mode $DNS_SPEED_CHECK_MODE -nameserver $DIRECT_DNS_GROUP -ipset $DIRECT_IPSET|" ${FORCE_DIRECT_DOMAINS} >> ${DNS_DIRECT_DOMAIN_RULES}
# enable ipv6 resolve for direct domains
sed -e "s|\(.*\)|address /\1/-6|" ${DIRECT_DOMAINS} > ${DNS_DIRECT_ADDRESS_RULES}
sed -e "s|\(.*\)|server \1 -group $DIRECT_DNS_GROUP --exclude-default-group|" ${DIRECT_DNS_SERVERS} > ${DNS_DIRECT_SERVER_RULES}
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

# generate iptables rules:
# 1. forwarding traffic with overseas destination to proxy gateway
# 2. forwarding dns request from specific mac address to proxy gateway
IPTABLES_PROXY_RULE_TEMPLATE="-A PREROUTING -t mangle \\
    -m mac --mac-source MAC_ADDRESS \\
    -m set ! --match-set DIRECT_IPSET dst \\
    -j MARK --set-mark PROXY_MARK"
DNS_UDP_PROXY_RULE_TEMPLATE="-t nat -A PREROUTING \\
    -m mac --mac-source MAC_ADDRESS \\
    -p udp --dport SRC_PORT \\
    -j REDIRECT \\
    --to-ports DST_PORT"
DNS_TCP_PROXY_RULE_TEMPLATE="-t nat -A PREROUTING \\
    -m mac --mac-source MAC_ADDRESS \\
    -p tcp --dport SRC_PORT \\
    -j REDIRECT \\
    --to-ports DST_PORT"
echo "generate iptables rules"
echo "#!/bin/sh" > ${IPTABLES_RULES}
while read MAC_ADDRESS
do
    echo "iptables $IPTABLES_PROXY_RULE_TEMPLATE" | \
        sed 's/MAC_ADDRESS/'$MAC_ADDRESS'/' | \
        sed 's/DIRECT_IPSET/'$DIRECT_IPSET'/' | \
        sed 's/PROXY_MARK/'$PROXY_MARK'/' >> ${IPTABLES_RULES}
done < $ALLOW_PROXY_DEVICE
while read MAC_ADDRESS
do
    echo "iptables $DNS_UDP_PROXY_RULE_TEMPLATE" | \
        sed 's/MAC_ADDRESS/'$MAC_ADDRESS'/' | \
        sed 's/SRC_PORT/'$DNS_DIRECT_PORT'/' | \
        sed 's/DST_PORT/'$DNS_PROXY_PROT'/' >> ${IPTABLES_RULES}
    echo "iptables $DNS_TCP_PROXY_RULE_TEMPLATE" | \
        sed 's/MAC_ADDRESS/'$MAC_ADDRESS'/' | \
        sed 's/SRC_PORT/'$DNS_DIRECT_PORT'/' | \
        sed 's/DST_PORT/'$DNS_PROXY_PROT'/' >> ${IPTABLES_RULES}
    if [ $ENABLE_IPV6_DNS_SERVER == 'true' ]; then
        echo "ip6tables $DNS_UDP_PROXY_RULE_TEMPLATE" | \
            sed 's/MAC_ADDRESS/'$MAC_ADDRESS'/' | \
            sed 's/SRC_PORT/'$DNS_DIRECT_PORT'/' | \
            sed 's/DST_PORT/'$DNS_PROXY_PROT'/' >> ${IPTABLES_RULES}
        echo "ip6tables $DNS_TCP_PROXY_RULE_TEMPLATE" | \
            sed 's/MAC_ADDRESS/'$MAC_ADDRESS'/' | \
            sed 's/SRC_PORT/'$DNS_DIRECT_PORT'/' | \
            sed 's/DST_PORT/'$DNS_PROXY_PROT'/' >> ${IPTABLES_RULES}
    fi
done < $ALLOW_PROXY_DEVICE
chmod +x ${IPTABLES_RULES}
echo "generate iptables rules done"

# generate ip route rules
echo "generate ip route rules"
echo "#!/bin/sh" > ${IP_ROUTE_RULES}
echo "ip rule flush table $PROXY_ROUTE_TABLE" >> ${IP_ROUTE_RULES}
echo "ip rule add fwmark $PROXY_MARK lookup $PROXY_ROUTE_TABLE" >> ${IP_ROUTE_RULES}
echo "ip route flush table $PROXY_ROUTE_TABLE" >> ${IP_ROUTE_RULES}
echo "ip route add default via $PROXY_GATEWAY dev $FORWARD_INTERFACE table $PROXY_ROUTE_TABLE" >> ${IP_ROUTE_RULES}
chmod +x ${IP_ROUTE_RULES}
echo "generate ip route rules done"

# generate startup script
:> ${STARTUP_SCRIPT}
echo "#execute ipset rules" >> ${STARTUP_SCRIPT}
echo "sh $DIRECT_IPSET_RULES" >> ${STARTUP_SCRIPT}
echo "#execute iproute rules" >> ${STARTUP_SCRIPT}
echo "sh $IP_ROUTE_RULES" >> ${STARTUP_SCRIPT}
echo "#execute iptables rules" >> ${STARTUP_SCRIPT}
echo "[ -z \"\$(cat $FIREWALL_USER_CONFIG | grep \"sh $IPTABLES_RULES\")\" ] \\
    && echo \"\" >> $FIREWALL_USER_CONFIG \\
    && echo \"sh $IPTABLES_RULES\" >> $FIREWALL_USER_CONFIG
    && fw3 restart" >> ${STARTUP_SCRIPT}
echo "fw3 restart" >> ${STARTUP_SCRIPT}
echo "#smartdns conf" >> ${STARTUP_SCRIPT}
# echo "cp $SHELL_FOLDER/smartdns.conf /var/etc/smartdns/" >> ${STARTUP_SCRIPT}
# echo "[ -z \"\$(cat $DNS_USER_CONF | grep \"conf-file $DNS_CONF\")\" ] \\
#     && echo \"\" >> $DNS_USER_CONF \\
#     && echo \"conf-file $DNS_CONF\" >> $DNS_USER_CONF" >> ${STARTUP_SCRIPT}
echo "killall -q smartdns" >> ${STARTUP_SCRIPT} 
echo "smartdns -c $DNS_CONF" >> ${STARTUP_SCRIPT} 
chmod +x ${STARTUP_SCRIPT}

