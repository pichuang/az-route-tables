#!/bin/bash

#
# Global variables
#
RESOURCE_GROUP_NAME="Network"
# ROUTE_TABLE_NAME="sdwan" # Change this to your route table name
ORIGINAL_NEXT_HOP_IP="10.250.255.4"
NEW_NEXT_HOP_IP="10.255.248.132"

# Show usage
if [ "$#" -ne 1 ]; then
    echo "Fix the next hop IP address in the specific route table"
    echo "Usage: ./2-fixed-nexthop.sh <ROUTE_TABLE_NAME>"
    echo "Example: ./2-fixed-nexthop.sh sdwan"
    exit 1
fi

ROUTE_TABLE_NAME=$1

# Do not change below this line
TIMESTAMP=$(date +%Y%m%d-%H%M%S)

# Fetch the route table and save it to a file
az network route-table route list \
    --resource-group ${RESOURCE_GROUP_NAME} \
    --route-table-name ${ROUTE_TABLE_NAME} \
    --query "[].{Name:name, AddressPrefix:addressPrefix, NextHopType:nextHopType, NextHopIpAddress:nextHopIpAddress}" \
    -o json > fix-${ROUTE_TABLE_NAME}-${TIMESTAMP}.json

# Temporary Replace the original next hop IP with the new next hop IP
jq --arg originalNextHopIp "$ORIGINAL_NEXT_HOP_IP" \
   --arg newNextHopIp "$NEW_NEXT_HOP_IP" \
   'map(if .NextHopIpAddress == $originalNextHopIp and (.Name | test("Ali.*|GCP.*") | not) then .NextHopIpAddress = $newNextHopIp else . end)' \
   "fix-${ROUTE_TABLE_NAME}-${TIMESTAMP}.json" > "fix-${ROUTE_TABLE_NAME}-${TIMESTAMP}-replaced.json"

#
# Human review
#
# Display the diff between the original and the replaced route table
jq -r '.[] | [.AddressPrefix, .Name, .NextHopIpAddress, .NextHopType] | @tsv' fix-${ROUTE_TABLE_NAME}-${TIMESTAMP}.json > fix-${ROUTE_TABLE_NAME}-${TIMESTAMP}.tsv
jq -r '.[] | [.AddressPrefix, .Name, .NextHopIpAddress, .NextHopType] | @tsv' fix-${ROUTE_TABLE_NAME}-${TIMESTAMP}-replaced.json > fix-${ROUTE_TABLE_NAME}-${TIMESTAMP}-replaced.tsv

echo "======================================================"
echo "Diff between the original and the replaced route table"
echo "======================================================"
# if the diff is empty, then  exit
if diff fix-${ROUTE_TABLE_NAME}-${TIMESTAMP}.tsv fix-${ROUTE_TABLE_NAME}-${TIMESTAMP}-replaced.tsv; then
    echo "No changes needed. Exiting..."
    exit 0
fi

# Wait for user confirmation
echo "=============================="
echo "Do you want to continue? [y/N]"
echo "=============================="

read CONTINUE
CONTINUE=${CONTINUE:-N}
if [[ "$CONTINUE" == "Y" || "$CONTINUE" == "y" || "$CONTINUE" == "1" ]]; then
    echo "Continuing..."
else
    echo "Exiting..."
    exit 1
fi

# Read the json file, then read route name and update the next-hop-ip-address
while IFS=$'\t' read -r _ name nextHopIpAddress nextHopType; do
    # Skip the Ali and GCP string
    if [[ "${name}" == *"Ali"* || "${name}" == *"GCP"* ]]; then
        continue
    fi
    #XXX: Hardcoded to skip the Internet
    if [[ "${nextHopIpAddress}" == "Internet" ]]; then
        continue
    fi
    # Skip nextHopType if it is not VirtualAppliance
    if [[ "${nextHopType}" != "VirtualAppliance" ]]; then
        continue
    fi
    echo "Name: ${name}"
    echo "NextHopIpAddress: ${nextHopIpAddress}"
    echo "NextHopType: ${nextHopType}"
    echo "--------------------------"

    az network route-table route update \
        -g ${RESOURCE_GROUP_NAME} \
        --route-table-name ${ROUTE_TABLE_NAME} \
        --name ${name} \
        --next-hop-ip-address ${nextHopIpAddress}

done < fix-${ROUTE_TABLE_NAME}-${TIMESTAMP}-replaced.tsv

echo "======================================================"
echo "Add 10.0.0.0/8 172.17.0.0/16 192.168.223.0/24 100.64.0.0/10 route to the new next hop IP"
echo "======================================================"
az network route-table route create \
    -g ${RESOURCE_GROUP_NAME} \
    --route-table-name ${ROUTE_TABLE_NAME} \
    --name route-to-10.0.0.0_8 \
    --next-hop-type VirtualAppliance \
    --address-prefix 10.0.0.0/8 \
    --next-hop-ip-address ${NEW_NEXT_HOP_IP}

az network route-table route create \
    -g ${RESOURCE_GROUP_NAME} \
    --route-table-name ${ROUTE_TABLE_NAME} \
    --name route-to-172.17.0.0_16 \
    --next-hop-type VirtualAppliance \
    --address-prefix 172.17.0.0/16 \
    --next-hop-ip-address ${NEW_NEXT_HOP_IP}

az network route-table route create \
    -g ${RESOURCE_GROUP_NAME} \
    --route-table-name ${ROUTE_TABLE_NAME} \
    --name route-to-192.168.223.0_24 \
    --next-hop-type VirtualAppliance \
    --address-prefix 192.168.223.0/24 \
    --next-hop-ip-address ${NEW_NEXT_HOP_IP}

az network route-table route create \
    -g ${RESOURCE_GROUP_NAME} \
    --route-table-name ${ROUTE_TABLE_NAME} \
    --name route-to-100.64.0.0_10 \
    --next-hop-type VirtualAppliance \
    --address-prefix 100.64.0.0/10 \
    --next-hop-ip-address ${NEW_NEXT_HOP_IP}