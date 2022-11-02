resourceGroup=rg_rosmith1
location=westeurope
vm_name=ccf4
vm_dns=rosmith-ccf4
vm_size=Standard_DC1s_v2
vnetName=ccf
subnetName=nodes
vnetAddressPrefix=10.0.0.0/16
nodeAddressPrefix=10.0.0.0/24
bastionAddressPrefix=10.0.1.0/26

az group create --name $resourceGroup --location $location

az network vnet create \
  --name $vnetName \
  --resource-group $resourceGroup \
  --address-prefixes $vnetAddressPrefix \
  --subnet-name $subnetName \
  --subnet-prefixes $nodeAddressPrefix

az network vnet subnet create \
    --address-prefixes $bastionAddressPrefix \
    --name "AzureBastionSubnet" \
    --vnet-name $vnetName \
    --resource-group $resourceGroup

az network public-ip create \
    --resource-group $resourceGroup \
    --name "BastionIp" \
    --sku Standard \
    --location $location

az vm create \
    --resource-group $resourceGroup \
    --name $vm_name \
    --image canonical:0001-com-ubuntu-server-focal:20_04-lts-gen2:20.04.202210180 \
    --vnet-name $vnetName \
    --subnet $subnetName \
    --generate-ssh-keys \
    --size $vm_size \
    --public-ip-sku Standard \
    --public-ip-address-dns-name $vm_dns \
    --assign-identity \
    --admin-username azureuser \
    --custom-data ccf.cloudinit \
    --output json

az ssh config \
    --resource-group $resourceGroup \
    --name $vm_name \
    --file ../ccf-sshconfig

az vm extension set \
    --publisher Microsoft.Azure.ActiveDirectory \
    --name AADSSHLoginForLinux \
    --resource-group $resourceGroup \
    --vm-name $vm_name

signed_in_user=$(az ad signed-in-user show --query id -o tsv)
az role assignment create \
    --role "virtual machine administrator login" \
    --resource-group $resourceGroup \
    --assignee $signed_in_user

# az network bastion create \
#     --name "ccf-bastion" \
#     --public-ip-address "BastionIp" \
#     --resource-group $resourceGroup \
#     --vnet-name $vnetName

# sub=$(az account show --query id -o tsv)
# vmId="/subscriptions/$sub/resourceGroups/$resourceGroup/providers/Microsoft.Compute/virtualMachines/$vm_name"

# az network bastion tunnel \
#     --name "ccf-bastion" \
#     --resource-group $resourceGroup \
#     --target-resource-id $vmId \
#     --resource-port 22 \
#     --port 9090


az ssh vm --resource-group $resourceGroup --name $vm_name

# az ssh config --resource-group rg_rosmith1 --name ccf2 --file ../ccf-sshconfig