# Port Configuration Summary

## Current Port Configuration

- **Backend**: Port `3000`
- **Frontend**: Port `8081`

## Files Updated

✅ `ecosystem.config.js` - PM2 configuration updated to port 8081  
✅ `DEPLOYMENT.md` - All references updated  
✅ `QUICK_DEPLOY_UBUNTU.md` - Port references updated  
✅ `README.md` - Port documentation updated  
✅ `VM_SETUP_COMMANDS.md` - Port references updated  
✅ `deploy.sh` - Deployment script updated  

## Firewall Configuration

On Ubuntu VM, ensure these ports are open:

```bash
sudo ufw allow 3000/tcp  # Backend
sudo ufw allow 8081/tcp  # Frontend
sudo ufw allow 22/tcp    # SSH
sudo ufw enable
```

## Access URLs

After deployment:
- **Backend API**: `http://YOUR_VM_IP:3000`
- **Frontend**: `http://YOUR_VM_IP:8081`
- **Health Check**: `http://YOUR_VM_IP:3000/health`

## Verification Commands

```bash
# Check if ports are listening
sudo netstat -tulpn | grep 3000  # Backend
sudo netstat -tulpn | grep 8081  # Frontend

# Test backend
curl http://localhost:3000/health

# Test frontend (should return HTML)
curl http://localhost:8081
```

