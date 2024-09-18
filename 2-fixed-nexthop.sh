#!/bin/bash

RESOURCE_GROUP_NAME="Network"
ROUTE_TABLE_NAME="sdwan" # Change this to your route table name
ORIGINAL_NEXT_HOP_IP="10.250.255.4"
NEW_NEXT_HOP_IP="1.1.1.1"




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



