# --------------------------------------------------
# Provider Configuration
# --------------------------------------------------
provider "aws" {
  region = "ap-south-1" # Mumbai
}

# --------------------------------------------------
# Random ID for unique bucket name
# --------------------------------------------------
resource "random_id" "bucket_id" {
  byte_length = 4
}

# --------------------------------------------------
# Networking (VPC, Subnets, IGW, Route Table)
# --------------------------------------------------
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "photo-app-vpc"
  }
}


resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "photo-app-igw"
  }
}

# Two public subnets in different AZs for ALB + EC2
resource "aws_subnet" "public_1" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "ap-south-1a"
  map_public_ip_on_launch = true
  tags                    = { Name = "photo-app-public-1" }
}

resource "aws_subnet" "public_2" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "ap-south-1b"
  map_public_ip_on_launch = true
  tags                    = { Name = "photo-app-public-2" }
}

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = { Name = "photo-app-rt" }
}

resource "aws_route_table_association" "public_assoc_1" {
  subnet_id      = aws_subnet.public_1.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "public_assoc_2" {
  subnet_id      = aws_subnet.public_2.id
  route_table_id = aws_route_table.public_rt.id
}

# --------------------------------------------------
# Security Group
# --------------------------------------------------
resource "aws_security_group" "ec2_sg" {
  name        = "photo-app-sg"
  description = "Allow HTTP and SSH"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "photo-app-sg" }
}

# --------------------------------------------------
# S3 Bucket for Photos
# --------------------------------------------------
resource "aws_s3_bucket" "photos" {
  bucket = "photo-app-${random_id.bucket_id.hex}"
  tags   = { Name = "photo-app-photos" }
}

# --------------------------------------------------
# Allow CloudFront OAC to access S3 bucket
# --------------------------------------------------
data "aws_cloudfront_origin_access_control" "photo_oac_lookup" {
  id = aws_cloudfront_origin_access_control.photo_oac.id
}

data "aws_iam_policy_document" "s3_policy" {
  statement {
    sid    = "AllowCloudFrontAccess"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.photos.arn}/*"]

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.photo_cdn.arn]
    }
  }
}

resource "aws_s3_bucket_policy" "photos_policy" {
  bucket = aws_s3_bucket.photos.id
  policy = data.aws_iam_policy_document.s3_policy.json
}

# --------------------------------------------------
# S3 Bucket Policy for CloudFront Access
# --------------------------------------------------
#data "aws_iam_policy_document" "s3_policy" {
# statement {
# actions   = ["s3:GetObject"]
# resources = ["${aws_s3_bucket.photos.arn}/*"]

#principals {
# type        = "AWS"
#identifiers = ["*"]
#}
#}
#}

#resource "aws_s3_bucket_policy" "photos_policy" {
#bucket = aws_s3_bucket.photos.id
#policy = data.aws_iam_policy_document.s3_policy.json
#}

# --------------------------------------------------
# RDS MySQL Database
# --------------------------------------------------
resource "aws_db_subnet_group" "photo_db_subnet" {
  name       = "photo-db-subnet"
  subnet_ids = [aws_subnet.public_1.id, aws_subnet.public_2.id]
}

resource "aws_db_instance" "photo_db" {
  identifier             = "photo-db"
  allocated_storage      = 20
  db_name                = "photoapp"
  engine                 = "mysql"
  engine_version         = "8.0"
  instance_class         = "db.t3.micro"
  username               = "admin"
  password               = "PhotoApp123!"
  publicly_accessible    = true
  skip_final_snapshot    = true
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]
  db_subnet_group_name   = aws_db_subnet_group.photo_db_subnet.name
  tags                   = { Name = "photo-app-db" }
}

# --------------------------------------------------
# EC2 Launch Template
# --------------------------------------------------
resource "aws_launch_template" "photo_app" {
  name_prefix   = "photo-app-"
  image_id      = "ami-0088a4dc01f0b276f" #Ubuntu 22.04, Oct 2025
  instance_type = "t2.micro"

  key_name = "photo-app-key"  #Add this line

  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [aws_security_group.ec2_sg.id]
  }

  user_data = base64encode(file("user_data.sh"))

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "photo-app-instance"
    }
  }
}

# --------------------------------------------------
# Load Balancer + Target Group + Listener
# --------------------------------------------------
resource "aws_lb" "app_alb" {
  name               = "photo-app-alb"
  load_balancer_type = "application"
  security_groups    = [aws_security_group.ec2_sg.id]
  subnets            = [aws_subnet.public_1.id, aws_subnet.public_2.id]
}

resource "aws_lb_target_group" "app_tg" {
  name     = "photo-app-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id
}

resource "aws_lb_listener" "app_listener" {
  load_balancer_arn = aws_lb.app_alb.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app_tg.arn
  }
}

# --------------------------------------------------
# Auto Scaling Group
# --------------------------------------------------
resource "aws_autoscaling_group" "app_asg" {
  name                = "photo-app-asg"
  max_size            = 2
  min_size            = 1
  desired_capacity    = 1
  vpc_zone_identifier = [aws_subnet.public_1.id, aws_subnet.public_2.id]
  target_group_arns   = [aws_lb_target_group.app_tg.arn]
  launch_template {
    id      = aws_launch_template.photo_app.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "photo-app-instance"
    propagate_at_launch = true
  }

  depends_on = [aws_lb_target_group.app_tg]
}

# --------------------------------------------------
# Grant CloudFront access to private S3 bucket securely via OAC
resource "aws_cloudfront_origin_access_control" "photo_oac" {
  name                              = "photo-app-oac"
  description                       = "OAC for CloudFront to access private S3 bucket"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_distribution" "photo_cdn" {
origin {
  domain_name = aws_s3_bucket.photos.bucket_regional_domain_name
  origin_id   = "S3-photo-app"
  origin_access_control_id = aws_cloudfront_origin_access_control.photo_oac.id
}

  enabled             = true
  default_root_object = "index.html"

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3-photo-app"

    viewer_protocol_policy = "redirect-to-https"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  tags = {
    Name = "photo-app-cdn"
  }
}
