#!/bin/bash

# docker installation
sudo apt update -y
sudo apt upgrade -y
sudo apt-get install net-tools -y
sudo apt-get install curl -y
sudo apt-get install unzip -y
ping -c 5 127.0.0.1
echo "PING COMPLETE" > /var/log/myapp-init.log
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
echo "TODAY HAS FINALLY COME" >> /var/log/myapp-init.log
sudo apt update -y
sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin -y
echo "Install Done" >> /var/log/myapp-init.log
sudo service docker start
sudo usermod -a -G docker gage

# commands to deploy DVWA, demoapp, and juice-shop
#sudo docker run -d --restart unless-stopped -p 10.245.3.100:80:8080 stockdemo/demoapp
#sudo docker run -d --restart unless-stopped -p 10.245.3.101:80:3000 bkimminich/juice-shop
#sudo docker run -d --restart unless-stopped -p 10.245.3.102:80:80 vulnerables/web-dvwa

# Create secure directory and write credential files
sudo mkdir -p /etc/ssl/nginx
echo "${jwt_token}" | sudo tee /etc/ssl/nginx/license.jwt > /dev/null
sudo chmod 0644 /etc/ssl/nginx/license.jwt

echo "${ssl_cert}" | sudo tee /etc/ssl/nginx/nginx-repo.crt > /dev/null
sudo chmod 0644 /etc/ssl/nginx/nginx-repo.crt

echo "${ssl_key}" | sudo tee /etc/ssl/nginx/nginx-repo.key > /dev/null
sudo chmod 0644 /etc/ssl/nginx/nginx-repo.key

echo "Secrets Copy Complete" >> /var/log/myapp-init.log

# Add NGINX repository
sudo apt update && \
sudo apt install -y apt-transport-https \
                 lsb-release \
                 ca-certificates \
                 wget \
                 gnupg2 \
                 ubuntu-keyring

sudo wget -qO - https://cs.nginx.com/static/keys/nginx_signing.key \
    | gpg --dearmor \
    | sudo tee /usr/share/keyrings/nginx-archive-keyring.gpg >/dev/null


printf "deb [signed-by=/usr/share/keyrings/nginx-archive-keyring.gpg] \
https://pkgs.nginx.com/plus/ubuntu `lsb_release -cs` nginx-plus\n" \
| sudo tee /etc/apt/sources.list.d/nginx-plus.list

sudo wget -P /etc/apt/apt.conf.d https://cs.nginx.com/static/files/90pkgs-nginx

# Create apt configuration for NGINX-Agent
echo Acquire::https::pkgs.nginx.com::Verify-Peer "true"; >> /etc/apt/apt.conf.d/90pkgs-nginx
echo Acquire::https::pkgs.nginx.com::Verify-Host "true"; >> /etc/apt/apt.conf.d/90pkgs-nginx
echo Acquire::https::pkgs.nginx.com::SslCert     "/etc/ssl/nginx/nginx-repo.crt"; >> /etc/apt/apt.conf.d/90pkgs-nginx
echo Acquire::https::pkgs.nginx.com::SslKey      "/etc/ssl/nginx/nginx-repo.key"; >> /etc/apt/apt.conf.d/90pkgs-nginx

# Add NGINX-Agent repository
echo "deb [signed-by=/usr/share/keyrings/nginx-archive-keyring.gpg] https://pkgs.nginx.com/nginx-agent/ubuntu/ `lsb_release -cs` agent" \
  | sudo tee /etc/apt/sources.list.d/nginx-agent.list


# Add App Protect repository
wget -qO - https://cs.nginx.com/static/keys/app-protect-security-updates.key | \
gpg --dearmor | sudo tee /usr/share/keyrings/app-protect-security-updates.gpg > /dev/null

printf "deb [signed-by=/usr/share/keyrings/nginx-archive-keyring.gpg] \
https://pkgs.nginx.com/app-protect/ubuntu `lsb_release -cs` nginx-plus\n" | \
sudo tee /etc/apt/sources.list.d/nginx-app-protect.list

printf "deb [signed-by=/usr/share/keyrings/app-protect-security-updates.gpg] \
https://pkgs.nginx.com/app-protect-security-updates/ubuntu `lsb_release -cs` nginx-plus\n" | \
sudo tee /etc/apt/sources.list.d/app-protect-security-updates.list

# Install NGINX Plus and App Protect
sudo apt-get update -y
sudo apt install -y nginx-plus
sudo apt-get install app-protect -y

# Copy JWT license file
sudo cp /etc/ssl/nginx/license.jwt /etc/nginx/license.jwt
echo "JWT copied" >> /var/log/myapp-init.log

# Copy api.conf file
echo "${api_conf}" | sudo tee /etc/nginx/conf.d/api.conf > /dev/null

sudo systemctl enable nginx
sudo systemctl start nginx

ping -c 5 127.0.0.1
sudo curl https://agent.connect.nginx.com/nginx-agent/install | DATA_PLANE_KEY="${dp_token}" sh -s -- -y >> /var/log/myapp-init.log 2>&1

echo "\n NGINX Agent Installed" >> /var/log/myapp-init.log

echo "End of Line, Man." >> /var/log/myapp-init.log

# Configure NGINX to listen on specific IP addresses
#sudo sed -i 's/80\ 8080\ default_server/i' /etc/nginx/conf.d/default.conf
#sudo sed -i 's/80\ default_server/10.245.2.105:80\ default_server/i' /etc/nginx/conf.d/default.conf
sudo systemctl restart nginx

sudo systemctl status nginx >> /var/log/myapp-init.log

# Install spa-demo-app 
mkdir /etc/nginx/spa-demo-app
git init ~/spa-demo-app
cd ~/spa-demo-app
git remote add origin "https://github.com/gkullio/spa-demo-app.git"
git fetch origin main
git checkout main

mv ~/spa-demo-app /etc/nginx/spa-demo-app
# Deploy spa-demo-app using Docker Compose
sudo docker compose -f /etc/nginx/spa-demo-app/spa-demo-app/docker-compose.yml up -d

# Include the spa-app.conf in NGINX configuration to /etc/nginx/conf.d/
echo "${spa_conf}" | sudo tee /etc/nginx/conf.d/spa-app.conf > /dev/null

sudo systemctl restart nginx

# Install Certbot and obtain SSL certificates
sudo apt-get install certbot python3-certbot-nginx -y