#!/bin/bash
sudo yum update -y
sudo yum install -y nginx
sudo systemctl start nginx
sudo systemctl enable nginx
echo "<h1>Photo Sharing App - Deployed via Terraform</h1>" | sudo tee /usr/share/nginx/html/index.html
