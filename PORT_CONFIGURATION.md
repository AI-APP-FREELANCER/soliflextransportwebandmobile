# Port Configuration Summary

## Current Port Configuration

- **Backend**: Port `3000`
- **Frontend**: Port `4000`

## Files Updated

✅ `ecosystem.config.js` - PM2 configuration updated to port 4000  
✅ `DEPLOYMENT.md` - All references updated  
✅ `QUICK_DEPLOY_UBUNTU.md` - Port references updated  
✅ `README.md` - Port documentation updated  
✅ `VM_SETUP_COMMANDS.md` - Port references updated  
✅ `deploy.sh` - Deployment script updated  

## Firewall Configuration

On Ubuntu VM, ensure these ports are open:

```bash
sudo ufw allow 3000/tcp  # Backend
sudo ufw allow 4000/tcp  # Frontend
sudo ufw allow 22/tcp    # SSH
sudo ufw enable
```

## Access URLs

After deployment:
- **Backend API**: `http://YOUR_VM_IP:3000`
- **Frontend**: `http://YOUR_VM_IP:4000`
- **Health Check**: `http://YOUR_VM_IP:3000/health`

## Verification Commands

```bash
# Check if ports are listening
sudo netstat -tulpn | grep 3000  # Backend
sudo netstat -tulpn | grep 4000  # Frontend

# Test backend
curl http://localhost:3000/health

# Test frontend (should return HTML)
curl http://localhost:4000
```

