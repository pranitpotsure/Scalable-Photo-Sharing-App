# 📸 Scalable Photo Sharing App — AWS | Terraform | Jenkins | React | Node.js

> 🚀 A complete **cloud-native photo sharing platform** built from scratch using AWS services, Infrastructure as Code (Terraform), and an automated CI/CD pipeline with Jenkins.  
> This guide explains **how to recreate the entire project**, including infrastructure provisioning, backend setup, frontend deployment, and automation.

---

## 🌎 Overview

This project demonstrates how to deploy a **real-world, scalable web application** using AWS cloud infrastructure.

Users can:
- Upload photos via a React web UI  
- Store images in Amazon S3  
- Save photo metadata (filename, timestamp, URL) in Amazon RDS (MySQL)  
- View uploaded photos dynamically with analytics  
- Enjoy global speed through CloudFront CDN  

All infrastructure is built automatically using **Terraform**, and the frontend deployment is handled through **Jenkins CI/CD**.

---

## 🧩 Architecture Overview

```
[ User Browser ]
        │
        ▼
[ CloudFront CDN ]
        │
        ▼
[ S3 (Frontend React App) ]
        │
        ▼ (API call: /upload, /photos)
[ Application Load Balancer (ALB) ]
        │
        ▼
[ EC2 Backend (Node.js + Express + PM2) ]
        │               │
        │               └────────────► [ S3 Bucket (Uploaded Images) ]
        ▼
[ RDS MySQL Database ]
                (Stores filename, URL, metadata)
```

```
graph TD
A[User Browser] -->|HTTPS| B[CloudFront CDN]
B --> C[S3 Bucket (Frontend)]
B --> D[Application Load Balancer]
D --> E[EC2 Instance (Backend - Node.js)]
E --> F[RDS Database (MySQL)]
E --> G[S3 Bucket (Photo Storage)]
```
---

### 🧠 Key Components
```
| Layer          | Technology                     | Purpose                                       |
| -------------- | ------------------------------ | --------------------------------------------- |
| **Frontend**   | React + Tailwind CSS           | User interface for uploading & viewing photos |
| **Backend**    | Node.js + Express              | REST API to handle uploads and metadata       |
| **Database**   | Amazon RDS (MySQL)             | Store image information                       |
| **Storage**    | Amazon S3                      | Host uploaded images                          |
| **CDN**        | CloudFront                     | Distribute frontend globally                  |
| **Compute**    | EC2 + ALB + Auto Scaling Group | Scalable backend infrastructure               |
| **IaC**        | Terraform                      | Automates AWS resource creation               |
| **CI/CD**      | Jenkins                        | Automatically builds & deploys frontend to S3 |
| **Monitoring** | PM2 + CloudWatch               | Keep backend online and observable            |
```
---

### 🏗️ PHASE 1 — Infrastructure Setup with Terraform
 🧰 Prerequisites
 ✅ AWS account
 ✅ IAM user with AdministratorAccess
 ✅ Terraform installed (terraform -v)
 ✅ AWS CLI configured (aws configure)

---
### 📁 Project Structure
```
photo-sharing-app/
│
├── terraform/
│   ├── main.tf
│   ├── user_data.sh
│   └── .terraform.lock.hcl
│
├── photo-frontend/
│   ├── src/
│   ├── public/
│   ├── package.json
│   ├── Jenkinsfile
│   └── tailwind.config.js
│
└── README.md
```
---
**⚙️ Step 1: Initialize Terraform**
```
cd terraform
terraform init
```
**⚙️ Step 2: Plan Infrastructure**
```terraform plan```

**⚙️ Step 3: Apply Changes**
```terraform apply```
Confirm with yes.
Terraform will automatically create:
 - VPC, Subnets, Route Tables, Internet Gateway
 - EC2 (Node.js backend instance)
 - Auto Scaling Group + Load Balancer
 - RDS MySQL Database
 - S3 Bucket for storing images
 - CloudFront CDN for frontend
 - IAM roles and security groups

**⚙️ Step 4: Verify AWS Resources**
After terraform apply, verify in your AWS console:
- EC2 Instance → running
- RDS Database → accessible
- S3 Bucket → created
- CloudFront Distribution → deployed
---

### ⚙️ PHASE 2 — Backend Setup (Node.js + MySQL)
🧠 Purpose
The backend receives photo uploads, saves them to S3, and records metadata into MySQL (RDS).

**📦 Step 1: Connect to EC2**
ssh -i "photo-app-key.pem" ubuntu@<EC2_PUBLIC_IP>

**📦 Step 2: Install Node.js & PM2**
sudo apt update -y
sudo apt install -y nodejs npm
sudo npm install -g pm2

**📦 Step 3: Setup Project Directory**
mkdir photo-backend && cd photo-backend
nano app.js

Paste your backend code (Express app) that handles upload to S3 and MySQL insertions.

**📦 Step 4: Create .env File**
```
DB_HOST=photo-db.czkokeyqgq7l.ap-south-1.rds.amazonaws.com
DB_USER=admin
DB_PASS=PhotoApp123!
DB_NAME=photo_db
AWS_ACCESS_KEY_ID=<your-key>
AWS_SECRET_ACCESS_KEY=<your-secret>
AWS_REGION=ap-south-1
AWS_BUCKET_NAME=photo-app-<unique-id>
PORT=80
```

**📦 Step 5: Start the App**
npm install
pm2 start app.js --name photo-backend

✅ Check logs:
pm2 logs
---

### 💻 PHASE 3 — Frontend Setup (React + Tailwind)
🧠 Purpose
The frontend is an Instagram-style dashboard that connects to the backend API and displays uploaded photos dynamically.

**⚙️ Step 1: Setup React**
cd photo-frontend
npm install
npm start

Your app should now run on:

```http://localhost:3000```

**⚙️ Step 2: Configure .env**
REACT_APP_API_URL=https://photos.keypress.shop

**⚙️ Step 3: Build for Production**
npm run build
---

### 🚀 PHASE 4 — Jenkins CI/CD Setup
🧠 Purpose
Whenever new code is pushed to GitHub, Jenkins automatically:
- Builds the React frontend
- Uploads to the S3 bucket
- Invalidates CloudFront cache (for instant updates)

**⚙️ Step 1: Install Jenkins on EC2 (if not already)**
```
sudo apt update
sudo apt install openjdk-17-jdk -y
curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io.key | sudo tee \
  /usr/share/keyrings/jenkins-keyring.asc > /dev/null
echo deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] \
  https://pkg.jenkins.io/debian-stable binary/ | sudo tee \
  /etc/apt/sources.list.d/jenkins.list > /dev/null
sudo apt update
sudo apt install jenkins -y
```

Then access Jenkins at:

```http://<jenkins-ec2-public-ip>:8080```

**⚙️ Step 2: Configure AWS CLI on Jenkins Server**
sudo apt install awscli -y
aws configure

**⚙️ Step 3: Jenkins Pipeline**

Create a Pipeline job named photo-frontend-cicd.

Paste this Jenkinsfile content:
```
pipeline {
    agent any
    environment {
        AWS_REGION = 'ap-south-1'
        S3_BUCKET = 'photo-frontend-pranit'
        CLOUDFRONT_ID = 'E2BPJRH3GUIOSG'
    }

    stages {
        stage('Checkout Code') {
            steps {
                git branch: 'main', url: 'https://github.com/pranitpotsure/photo-frontend.git'
            }
        }

        stage('Install Dependencies') {
            steps {
                sh 'npm ci'
            }
        }

        stage('Build React App') {
            steps {
                sh 'npm run build'
            }
        }

        stage('Deploy to S3') {
            steps {
                sh 'aws s3 sync build/ s3://$S3_BUCKET --delete --region $AWS_REGION'
            }
        }

        stage('Invalidate CloudFront Cache') {
            steps {
                sh 'aws cloudfront create-invalidation --distribution-id $CLOUDFRONT_ID --paths "/*"'
            }
        }
    }

    post {
        success { echo '✅ Frontend deployment successful!' }
        failure { echo '❌ Deployment failed. Check logs.' }
    }
}
```

**⚙️ Step 4: Run Jenkins Pipeline**

Click Build Now
✅ Jenkins pulls your frontend repo → builds React app → deploys to S3 → refreshes CDN.

---

### 🌐 PHASE 5 — Verify Deployment
Component	Service	URL
Frontend (UI)	CloudFront	https://dzewjfie62mf2.cloudfront.net
Backend API	EC2 (ALB)	https://photos.keypress.shop
Database	RDS	photo-db.czkokeyqgq7l.ap-south-1.rds.amazonaws.com
Image Storage	S3	photo-app-229e7fc1

---

### 📊 Architecture Highlights
Feature	Implementation
High Availability	Load Balancer + Auto Scaling
CI/CD Automation	Jenkins + GitHub Webhook
Security	IAM Roles + Security Groups
Performance	CloudFront CDN
Cost Optimization	S3 static hosting, t2.micro instances
Monitoring	CloudWatch & PM2

---

### 🧠 Key Learnings
- Design and deploy a multi-tier AWS architecture
- Implement Infrastructure as Code with Terraform
- Create a Jenkins pipeline for automated builds
- Secure apps with IAM + OAC + Security Groups
- Optimize frontend with S3 + CloudFront
- Integrate CI/CD in a real-world cloud project

---

## 📸 Project Screenshots

| Step | Description | Preview |
|------|-------------|---------|
| 1️⃣ | **CI/CD Pipeline Diagram** | ![CICD](https://raw.githubusercontent.com/pranitpotsure/Scalable-Photo-Sharing-App/main/image/CICD.png) |
| 2️⃣ | **CloudFront Distribution** | ![CloudFront](https://raw.githubusercontent.com/pranitpotsure/Scalable-Photo-Sharing-App/main/image/cloudfront.png) |
| 3️⃣ | **EC2 Backend Instance** | ![EC2](https://raw.githubusercontent.com/pranitpotsure/Scalable-Photo-Sharing-App/main/image/ec2.png) |
| 4️⃣ | **Uploaded Images – S3 Bucket** | ![Uploaded Images](https://raw.githubusercontent.com/pranitpotsure/Scalable-Photo-Sharing-App/main/image/uploaded%20imges.png) |
| 5️⃣ | **RDS MySQL Database** | ![RDS](https://raw.githubusercontent.com/pranitpotsure/Scalable-Photo-Sharing-App/main/image/rds.png) |
| 6️⃣ | **S3 Bucket (Uploads)** | ![S3 Upload Bucket](https://raw.githubusercontent.com/pranitpotsure/Scalable-Photo-Sharing-App/main/image/s3%20bucket%20for%20upload.png) |
| 7️⃣ | **S3 Bucket (Frontend Hosting)** | ![S3 Frontend Bucket](https://raw.githubusercontent.com/pranitpotsure/Scalable-Photo-Sharing-App/main/image/s3%20bucket%20frontend.png) |
| 8️⃣ | **All Images Preview** | ![Images](https://raw.githubusercontent.com/pranitpotsure/Scalable-Photo-Sharing-App/main/image/imges.png) |

---

### 👨‍💻 Author
Pranit Potsure
💼 Cloud & DevOps Engineer | AWS | Terraform | Jenkins | React | Node.js
📍 India
🔗 [GitHub](https://github.com/pranitpotsure)  [linkedin](https://www.linkedin.com/in/pranit-potsure)
