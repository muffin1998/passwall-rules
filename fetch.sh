#!/bin/sh

SHELL_FOLDER=$(cd "$(dirname "$0")";pwd)

. ${SHELL_FOLDER}/config

rm -rf ${SHELL_FOLDER}/tmp
mkdir ${SHELL_FOLDER}/tmp
curl https://cdn.jsdelivr.net/gh/Loyalsoldier/surge-rules@release/ruleset/direct.txt -o ${SHELL_FOLDER}/tmp/direct.txt
curl https://cdn.jsdelivr.net/gh/Loyalsoldier/surge-rules@release/ruleset/apple.txt -o ${SHELL_FOLDER}/tmp/apple.txt
curl https://cdn.jsdelivr.net/gh/Loyalsoldier/surge-rules@release/ruleset/icloud.txt -o ${SHELL_FOLDER}/tmp/icloud.txt
curl https://cdn.jsdelivr.net/gh/Loyalsoldier/surge-rules@release/ruleset/cncidr.txt -o ${SHELL_FOLDER}/tmp/cncidr.txt

DIRECT_DOMAINS=$SHELL_FOLDER/$DIRECT_DOMAINS
DIRECT_IP_LIST=$SHELL_FOLDER/$DIRECT_IP_LIST

:> ${DIRECT_DOMAINS}
awk -F, '{ if($1 == "DOMAIN") print $2; else if($1 == "DOMAIN-SUFFIX") print "*-."$2; }' ${SHELL_FOLDER}/tmp/direct.txt >> ${DIRECT_DOMAINS}
awk -F, '{ if($1 == "DOMAIN") print $2; else if($1 == "DOMAIN-SUFFIX") print "*-."$2; }' ${SHELL_FOLDER}/tmp/apple.txt >> ${DIRECT_DOMAINS}
awk -F, '{ if($1 == "DOMAIN") print $2; else if($1 == "DOMAIN-SUFFIX") print "*-."$2; }' ${SHELL_FOLDER}/tmp/icloud.txt >> ${DIRECT_DOMAINS}

:> ${DIRECT_IP_LIST}
awk -F, '{ if($1 == "IP-CIDR") print $2; }' ${SHELL_FOLDER}/tmp/cncidr.txt >> ${DIRECT_IP_LIST}
