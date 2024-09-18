#!/bin/bash

# Show usage
if [ "$#" -ne 1 ]; then
    echo "Backup all route tables in the specific resource group"
    echo "Usage: $0 <resource_group_name>"
    exit 1
fi

RESOURCE_GROUP_NAME=$1
TIMESTAMP=$(date +%Y%m%d-%H%M%S)

# do not change
ROOT_DIR="backup-routetables-${RESOURCE_GROUP_NAME}-${TIMESTAMP}"
mkdir -p ${ROOT_DIR}

# List all route tables in the resource group, then backup each route table
echo "Backup all route tables in the resource group: ${RESOURCE_GROUP_NAME} - Start"
az network route-table list \
    --resource-group ${RESOURCE_GROUP_NAME} \
    --query "[].{Name:name}" \
    -o tsv > ${ROOT_DIR}/list-rt-${RESOURCE_GROUP_NAME}.tsv

while IFS= read -r line; do
    echo "Backup route table: $line - Start"
    az network route-table route list \
        --resource-group ${RESOURCE_GROUP_NAME} \
        --route-table-name $line \
        --query "[].{Name:name, AddressPrefix:addressPrefix, NextHopType:nextHopType, NextHopIpAddress:nextHopIpAddress}" \
        -o tsv > ${ROOT_DIR}/${line}-${TIMESTAMP}.tsv
    echo "Backup route table: $line - Done"
done < ${ROOT_DIR}/list-rt-${RESOURCE_GROUP_NAME}.tsv

# Then, zip the backup files
echo "Zip all backup files - Start"
zip -r ${ROOT_DIR}.zip ${ROOT_DIR}
echo "Zip all backup files in ${ROOT_DIR}.zip - Done"
echo "Backup all route tables in the resource group: ${RESOURCE_GROUP_NAME} - Done"