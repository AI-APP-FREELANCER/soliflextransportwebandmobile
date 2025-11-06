# Azure NSG Port Configuration - Ports 3000 and 4000

## Prerequisites
- Azure CLI installed (`az --version` to check)
- Logged into Azure (`az login`)
- Know your VM name and resource group name

---

## Step-by-Step Commands (Azure CLI)

### Step 1: Login to Azure (if not already logged in)
```bash
az login
```

### Step 2: Set Variables (Replace with your values)
```bash
# Set your resource group name
RESOURCE_GROUP="your-resource-group-name"

# Set your VM name
VM_NAME="your-vm-name"
```

### Step 3: Get VM Network Interface and NSG Name
```bash
# Get the network interface name
NIC_NAME=$(az vm show --resource-group $RESOURCE_GROUP --name $VM_NAME --query "networkProfile.networkInterfaces[0].id" -o tsv | cut -d'/' -f9)

# Get the NSG name associated with the VM
NSG_NAME=$(az network nic show --resource-group $RESOURCE_GROUP --name $NIC_NAME --query "networkSecurityGroup.id" -o tsv | cut -d'/' -f9)

# If NSG is not directly attached to NIC, get it from subnet
if [ -z "$NSG_NAME" ]; then
    SUBNET_ID=$(az vm show --resource-group $RESOURCE_GROUP --name $VM_NAME --query "networkProfile.networkInterfaces[0].id" -o tsv)
    VNET_NAME=$(az network nic show --ids $SUBNET_ID --query "ipConfigurations[0].subnet.id" -o tsv | cut -d'/' -f9)
    SUBNET_NAME=$(az network nic show --ids $SUBNET_ID --query "ipConfigurations[0].subnet.id" -o tsv | cut -d'/' -f11)
    NSG_NAME=$(az network vnet subnet show --resource-group $RESOURCE_GROUP --vnet-name $VNET_NAME --name $SUBNET_NAME --query "networkSecurityGroup.id" -o tsv | cut -d'/' -f9)
fi

# Display NSG name
echo "NSG Name: $NSG_NAME"
```

### Step 4: Create Inbound Rule for Port 3000
```bash
az network nsg rule create \
  --resource-group $RESOURCE_GROUP \
  --nsg-name $NSG_NAME \
  --name Allow-Inbound-Port-3000 \
  --priority 1000 \
  --direction Inbound \
  --access Allow \
  --protocol Tcp \
  --destination-port-ranges 3000 \
  --description "Allow inbound traffic on port 3000 for backend API"
```

### Step 5: Create Inbound Rule for Port 4000
```bash
az network nsg rule create \
  --resource-group $RESOURCE_GROUP \
  --nsg-name $NSG_NAME \
  --name Allow-Inbound-Port-4000 \
  --priority 1001 \
  --direction Inbound \
  --access Allow \
  --protocol Tcp \
  --destination-port-ranges 4000 \
  --description "Allow inbound traffic on port 4000 for frontend web app"
```

### Step 6: Create Outbound Rule for Port 3000 (if needed)
```bash
az network nsg rule create \
  --resource-group $RESOURCE_GROUP \
  --nsg-name $NSG_NAME \
  --name Allow-Outbound-Port-3000 \
  --priority 1002 \
  --direction Outbound \
  --access Allow \
  --protocol Tcp \
  --destination-port-ranges 3000 \
  --description "Allow outbound traffic on port 3000"
```

### Step 7: Create Outbound Rule for Port 4000 (if needed)
```bash
az network nsg rule create \
  --resource-group $RESOURCE_GROUP \
  --nsg-name $NSG_NAME \
  --name Allow-Outbound-Port-4000 \
  --priority 1003 \
  --direction Outbound \
  --access Allow \
  --protocol Tcp \
  --destination-port-ranges 4000 \
  --description "Allow outbound traffic on port 4000"
```

### Step 8: Verify Rules Created
```bash
# List all inbound rules
az network nsg rule list \
  --resource-group $RESOURCE_GROUP \
  --nsg-name $NSG_NAME \
  --query "[?direction=='Inbound'].[name,priority,destinationPortRange,access,protocol]" \
  --output table

# List all outbound rules
az network nsg rule list \
  --resource-group $RESOURCE_GROUP \
  --nsg-name $NSG_NAME \
  --query "[?direction=='Outbound'].[name,priority,destinationPortRange,access,protocol]" \
  --output table
```

---

## Alternative: Direct NSG Name Method (If you know your NSG name)

If you already know your NSG name, you can skip Step 3 and use these commands directly:

### Set Variables
```bash
RESOURCE_GROUP="your-resource-group-name"
NSG_NAME="your-nsg-name"
```

### Create Inbound Rules
```bash
# Port 3000 Inbound
az network nsg rule create \
  --resource-group $RESOURCE_GROUP \
  --nsg-name $NSG_NAME \
  --name Allow-Inbound-Port-3000 \
  --priority 1000 \
  --direction Inbound \
  --access Allow \
  --protocol Tcp \
  --destination-port-ranges 3000

# Port 4000 Inbound
az network nsg rule create \
  --resource-group $RESOURCE_GROUP \
  --nsg-name $NSG_NAME \
  --name Allow-Inbound-Port-4000 \
  --priority 1001 \
  --direction Inbound \
  --access Allow \
  --protocol Tcp \
  --destination-port-ranges 4000
```

### Create Outbound Rules
```bash
# Port 3000 Outbound
az network nsg rule create \
  --resource-group $RESOURCE_GROUP \
  --nsg-name $NSG_NAME \
  --name Allow-Outbound-Port-3000 \
  --priority 1002 \
  --direction Outbound \
  --access Allow \
  --protocol Tcp \
  --destination-port-ranges 3000

# Port 4000 Outbound
az network nsg rule create \
  --resource-group $RESOURCE_GROUP \
  --nsg-name $NSG_NAME \
  --name Allow-Outbound-Port-4000 \
  --priority 1003 \
  --direction Outbound \
  --access Allow \
  --protocol Tcp \
  --destination-port-ranges 4000
```

---

## PowerShell Alternative (Azure PowerShell)

If you prefer Azure PowerShell instead of Azure CLI:

### Step 1: Login
```powershell
Connect-AzAccount
```

### Step 2: Set Variables
```powershell
$ResourceGroupName = "your-resource-group-name"
$NsgName = "your-nsg-name"
```

### Step 3: Create Inbound Rules
```powershell
# Port 3000 Inbound
Add-AzNetworkSecurityRuleConfig `
  -ResourceGroupName $ResourceGroupName `
  -NetworkSecurityGroupName $NsgName `
  -Name "Allow-Inbound-Port-3000" `
  -Description "Allow inbound traffic on port 3000 for backend API" `
  -Access Allow `
  -Protocol Tcp `
  -Direction Inbound `
  -Priority 1000 `
  -SourceAddressPrefix * `
  -SourcePortRange * `
  -DestinationAddressPrefix * `
  -DestinationPortRange 3000

# Port 4000 Inbound
Add-AzNetworkSecurityRuleConfig `
  -ResourceGroupName $ResourceGroupName `
  -NetworkSecurityGroupName $NsgName `
  -Name "Allow-Inbound-Port-4000" `
  -Description "Allow inbound traffic on port 4000 for frontend web app" `
  -Access Allow `
  -Protocol Tcp `
  -Direction Inbound `
  -Priority 1001 `
  -SourceAddressPrefix * `
  -SourcePortRange * `
  -DestinationAddressPrefix * `
  -DestinationPortRange 4000
```

### Step 4: Create Outbound Rules
```powershell
# Port 3000 Outbound
Add-AzNetworkSecurityRuleConfig `
  -ResourceGroupName $ResourceGroupName `
  -NetworkSecurityGroupName $NsgName `
  -Name "Allow-Outbound-Port-3000" `
  -Description "Allow outbound traffic on port 3000" `
  -Access Allow `
  -Protocol Tcp `
  -Direction Outbound `
  -Priority 1002 `
  -SourceAddressPrefix * `
  -SourcePortRange * `
  -DestinationAddressPrefix * `
  -DestinationPortRange 3000

# Port 4000 Outbound
Add-AzNetworkSecurityRuleConfig `
  -ResourceGroupName $ResourceGroupName `
  -NetworkSecurityGroupName $NsgName `
  -Name "Allow-Outbound-Port-4000" `
  -Description "Allow outbound traffic on port 4000" `
  -Access Allow `
  -Protocol Tcp `
  -Direction Outbound `
  -Priority 1003 `
  -SourceAddressPrefix * `
  -SourcePortRange * `
  -DestinationAddressPrefix * `
  -DestinationPortRange 4000
```

### Step 5: Save NSG Configuration
```powershell
Set-AzNetworkSecurityGroup -NetworkSecurityGroup (Get-AzNetworkSecurityGroup -ResourceGroupName $ResourceGroupName -Name $NsgName)
```

---

## Quick Reference: Find Your NSG Name

### Method 1: Via Azure Portal
1. Go to Azure Portal → Virtual Machines
2. Click on your VM
3. Go to "Networking" tab
4. Click on the Network Security Group link
5. Note the NSG name

### Method 2: Via Azure CLI
```bash
# List all NSGs in your resource group
az network nsg list --resource-group your-resource-group-name --output table

# Get NSG for a specific VM
az vm show --resource-group your-resource-group-name --name your-vm-name --query "networkProfile.networkInterfaces[0].id" -o tsv
```

---

## Notes

1. **Priority**: Rules are evaluated by priority (lower numbers = higher priority). Make sure your priorities don't conflict with existing rules.

2. **Outbound Rules**: Usually not required for web servers, but included for completeness. Azure NSGs allow all outbound traffic by default unless explicitly denied.

3. **Source Address**: The commands above use `*` (any source). For better security, you can restrict to specific IP ranges:
   - Replace `--source-address-prefixes "*"` with specific IP ranges
   - Example: `--source-address-prefixes "203.0.113.0/24"`

4. **Verify**: After creating rules, test connectivity:
   ```bash
   # From your local machine
   curl http://YOUR_VM_IP:3000/health
   curl http://YOUR_VM_IP:4000
   ```

---

## Troubleshooting

### Check if rules exist
```bash
az network nsg rule list --resource-group $RESOURCE_GROUP --nsg-name $NSG_NAME --output table
```

### Delete a rule (if needed)
```bash
az network nsg rule delete \
  --resource-group $RESOURCE_GROUP \
  --nsg-name $NSG_NAME \
  --name Allow-Inbound-Port-3000
```

### Check NSG association
```bash
az network nsg show --resource-group $RESOURCE_GROUP --name $NSG_NAME --query "subnets" --output table
```

