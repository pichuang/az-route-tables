#!/bin/bash

RESOURCE_GROUP_NAME="Network"

# Show usage
if [ "$#" -ne 1 ]; then
    echo "Restore specific route tables in the specific resource group"
    echo "Usage: ./3-restore-specific-routetables.sh <tsv_file>"
    echo "Example: ./3-restore-specific-routetables.sh backup-routetables-Network-20240920-134503/sdwan-20240920-134503.tsv"
    exit 1
fi

TSV_FILE=$1
FILE_NAME=$(basename "$TSV_FILE")
ROUTE_TABLE_NAME=$(echo "$FILE_NAME" | cut -d'-' -f1)

echo "===================="
echo "The Route Table Name: ${ROUTE_TABLE_NAME}"
echo "===================="

while IFS=$'\t' read -r col1 col2 col3 col4; do
    echo "===================="
    echo "Name: ${col1}"
    echo "AddressPrefix: ${col2}"
    echo "NextHopType: ${col3}"
    echo "NextHopIpAddress: ${col4}"
    echo "===================="

    if [ "$col3" == "Internet" ]; then
        az network route-table route create \
            --resource-group ${RESOURCE_GROUP_NAME} \
            --route-table-name ${ROUTE_TABLE_NAME} \
            --name ${col1} \
            --address-prefix ${col2} \
            --next-hop-type ${col3}
        continue
    fi

    az network route-table route create \
        --resource-group ${RESOURCE_GROUP_NAME} \
        --route-table-name ${ROUTE_TABLE_NAME} \
        --name ${col1} \
        --address-prefix ${col2} \
        --next-hop-type ${col3} \
        --next-hop-ip-address ${col4}

done < "$TSV_FILE"