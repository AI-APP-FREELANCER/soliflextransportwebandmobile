# Port 8081 Setup - Quick Reference

The frontend port has been changed from **4000** to **8081**.

## Changes Made

✅ `ecosystem.config.js` - Updated to port 8081  
✅ `PORT_CONFIGURATION.md` - Updated documentation  
✅ `AZURE_NSG_PORT_CONFIGURATION.md` - Updated Azure NSG commands

---

## Commands to Run on Ubuntu VM

### Step 1: Update Firewall (UFW)

```bash
# Allow port 8081
sudo ufw allow 8081/tcp

# Check firewall status
sudo ufw status
```

### Step 2: Restart PM2 Apps

```bash
cd ~/transport/transportwebandmobile/soliflexweb

# Stop apps
pm2 stop all
pm2 delete all

# Start apps (will use new port 8081 from ecosystem.config.js)
pm2 start ecosystem.config.js

# Save PM2 configuration
pm2 save

# Check status
pm2 list
pm2 logs
```

### Step 3: Verify Port is Listening

```bash
# Check if port 8081 is listening
sudo netstat -tulpn | grep 8081

# Test frontend
curl http://localhost:8081
```

---

## Azure NSG Configuration

You need to add an inbound rule for port 8081 in Azure Network Security Group.

### Quick Command (if you know your NSG name):

```bash
# Set variables
RESOURCE_GROUP="your-resource-group-name"
NSG_NAME="your-nsg-name"

# Create inbound rule for port 8081
az network nsg rule create \
  --resource-group $RESOURCE_GROUP \
  --nsg-name $NSG_NAME \
  --name Allow-Inbound-Port-8081 \
  --priority 1001 \
  --direction Inbound \
  --access Allow \
  --protocol Tcp \
  --destination-port-ranges 8081 \
  --description "Allow inbound traffic on port 8081 for frontend web app"
```

### Or use Azure Portal:

1. Go to Azure Portal → Virtual Machines
2. Click on your VM → **Networking**
3. Click on **Network Security Group**
4. Click **Inbound security rules** → **Add**
5. Set:
   - **Name**: `Allow-Inbound-Port-8081`
   - **Priority**: `1001`
   - **Port**: `8081`
   - **Protocol**: `TCP`
   - **Action**: `Allow`
6. Click **Add**

---

## Access URLs

After setup:
- **Backend API**: `http://YOUR_VM_IP:3000`
- **Frontend**: `http://YOUR_VM_IP:8081`
- **Health Check**: `http://YOUR_VM_IP:3000/health`

---

## Troubleshooting

### If port 8081 is not accessible:

1. **Check Azure NSG rule:**
   ```bash
   az network nsg rule list --resource-group $RESOURCE_GROUP --nsg-name $NSG_NAME --output table
   ```

2. **Check UFW firewall:**
   ```bash
   sudo ufw status
   sudo ufw allow 8081/tcp
   ```

3. **Check if PM2 is running:**
   ```bash
   pm2 list
   pm2 logs soliflex-frontend
   ```

4. **Check if port is listening:**
   ```bash
   sudo netstat -tulpn | grep 8081
   sudo lsof -i :8081
   ```

### If you need to remove old port 4000 rule:

```bash
# Remove old Azure NSG rule (if exists)
az network nsg rule delete \
  --resource-group $RESOURCE_GROUP \
  --nsg-name $NSG_NAME \
  --name Allow-Inbound-Port-4000
```

---

## Complete Setup Sequence

```bash
# On Ubuntu VM
cd ~/transport/transportwebandmobile/soliflexweb

# Update firewall
sudo ufw allow 8081/tcp

# Restart PM2
pm2 stop all
pm2 delete all
pm2 start ecosystem.config.js
pm2 save

# Verify
pm2 list
curl http://localhost:8081
```

Then add the Azure NSG rule for port 8081 (see above).

