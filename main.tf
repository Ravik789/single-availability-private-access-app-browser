terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Latest Amazon Linux 2023 AMI
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

# VPC
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "private-app-vpc"
  }
}

# One public subnet in one AZ
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = var.availability_zone
  map_public_ip_on_launch = true

  tags = {
    Name = "public-subnet"
  }
}

# One private subnet in the same AZ
resource "aws_subnet" "private" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = var.availability_zone
  map_public_ip_on_launch = false

  tags = {
    Name = "private-subnet"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "private-app-igw"
  }
}

# Public route table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "public-route-table"
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# Security group for public reverse proxy
resource "aws_security_group" "proxy" {
  name        = "public-proxy-sg"
  description = "Allow browser HTTP traffic"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP from browser"
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

  tags = {
    Name = "public-proxy-sg"
  }
}

# Security group for private application
resource "aws_security_group" "app" {
  name        = "private-app-sg"
  description = "Allow application traffic only from proxy"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "App traffic from proxy"
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.proxy.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "private-app-sg"
  }
}

# Private EC2 application
resource "aws_instance" "app" {
  ami                         = data.aws_ami.amazon_linux.id
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.private.id
  associate_public_ip_address = false
  vpc_security_group_ids      = [aws_security_group.app.id]

  user_data = <<-EOF
    #!/bin/bash
    mkdir -p /opt/private-app

    cat > /opt/private-app/index.html <<'HTML'
    <!DOCTYPE html>
    <html>
      <head><title>Private VPC Application</title></head>
      <body>
        <h1>Hello from Private EC2!</h1>
        <p>Application is running in a private subnet.</p>
        <p>Availability Zone: ${var.availability_zone}</p>
      </body>
    </html>
    HTML

    cat > /etc/systemd/system/private-app.service <<'SERVICE'
    [Unit]
    Description=Private VPC Demo Application
    After=network.target

    [Service]
    Type=simple
    WorkingDirectory=/opt/private-app
    ExecStart=/usr/bin/python3 -m http.server 8080 --bind 0.0.0.0 --directory /opt/private-app
    Restart=always

    [Install]
    WantedBy=multi-user.target
    SERVICE

    systemctl daemon-reload
    systemctl enable --now private-app
  EOF

  tags = {
    Name = "private-app-ec2"
  }
}

# Public reverse proxy EC2
resource "aws_instance" "proxy" {
  ami                         = data.aws_ami.amazon_linux.id
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.public.id
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.proxy.id]

  user_data = <<-EOF
    #!/bin/bash
    dnf install -y nginx

    cat > /etc/nginx/conf.d/private-app.conf <<'NGINX'
    server {
        listen 80;
        server_name _;

        location / {
            proxy_pass http://${aws_instance.app.private_ip}:8080;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
        }
    }
    NGINX

    systemctl enable --now nginx
    nginx -t && systemctl reload nginx
  EOF

  depends_on = [
    aws_route_table_association.public,
    aws_instance.app
  ]

  tags = {
    Name = "public-proxy-ec2"
  }
}
