terraform {
  backend "s3" {
    bucket = "pgr301-2024-terraform-state"
    key    = "kong/terraform.tfstate"
    region = "eu-west-1"
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

resource "aws_ecr_repository" "kong" {
  name = "custom-kong"
}


locals {
  kong_config = jsonencode(yamldecode(file("${path.module}/kong.yml")))
}


provider "aws" {
  region = "eu-west-1"  # Adjust to your preferred region
}

# VPC
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "kong-vpc"
  }
}

# Private subnets in different availability zones
resource "aws_subnet" "private_1" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "eu-west-1a"  # Adjust according to your region

  tags = {
    Name = "private-subnet-1"
  }
}

resource "aws_subnet" "private_2" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "eu-west-1b"  # Adjust according to your region

  tags = {
    Name = "private-subnet-2"
  }
}

# Route table for private subnets
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "private-rt"
  }
}

# Route table associations
resource "aws_route_table_association" "private_1" {
  subnet_id      = aws_subnet.private_1.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "private_2" {
  subnet_id      = aws_subnet.private_2.id
  route_table_id = aws_route_table.private.id
}

# Security group for Kong
resource "aws_security_group" "kong" {
  name_prefix = "kong-sg"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 8000
    to_port     = 8000
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]  # Adjust based on your needs
  }

  ingress {
    from_port   = 8001
    to_port     = 8001
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]  # Adjust based on your needs
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Output values
output "vpc_id" {
  value = aws_vpc.main.id
}

output "private_subnet_ids" {
  value = [aws_subnet.private_1.id, aws_subnet.private_2.id]
}

output "security_group_id" {
  value = aws_security_group.kong.id
}

# ECS Cluster
resource "aws_ecs_cluster" "kong" {
  name = "kong-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "main-igw"
  }
}

# Public subnet for NAT Gateway
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.0.0/24"
  availability_zone       = "eu-west-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "public-subnet-nat"
  }
}

resource "aws_subnet" "public_2" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.3.0/24"  # Different CIDR from your first public subnet
  availability_zone       = "eu-west-1b"    # Different AZ from your first public subnet
  map_public_ip_on_launch = true

  tags = {
    Name = "public-subnet-2"
  }
}


# Route table for public subnet
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "public-rt"
  }
}

# Associate public subnet with public route table
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# Elastic IP for NAT Gateway
resource "aws_eip" "nat" {
  domain = "vpc"

  depends_on = [aws_internet_gateway.main]
}

# NAT Gateway
resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public.id

  tags = {
    Name = "main-nat"
  }

  depends_on = [aws_internet_gateway.main]
}

# Associate the second public subnet with the public route table
resource "aws_route_table_association" "public_2" {
  subnet_id      = aws_subnet.public_2.id
  route_table_id = aws_route_table.public.id
}

# ECS Task Definition

resource "aws_ecs_task_definition" "kong" {
  family                   = "kong"
  requires_compatibilities = ["FARGATE"]
  network_mode            = "awsvpc"
  cpu                     = 512
  memory                  = 1024
  execution_role_arn      = aws_iam_role.ecs_execution_role.arn
  task_role_arn          = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([
    {
      name  = "kong"
      image = "${aws_ecr_repository.kong.repository_url}:latest"
      portMappings = [
        {
          containerPort = 8000
          hostPort      = 8000
          protocol      = "tcp"
        },
        {
          containerPort = 8001
          hostPort      = 8001
          protocol      = "tcp"
        }
      ]
      environment = [
        {
          name  = "KONG_DATABASE"
          value = "off"
        },
        {
          name  = "KONG_PROXY_ACCESS_LOG"
          value = "/dev/stdout"
        },
        {
          name  = "KONG_ADMIN_ACCESS_LOG"
          value = "/dev/stdout"
        },
        {
          name  = "KONG_PROXY_ERROR_LOG"
          value = "/dev/stderr"
        },
        {
          name  = "KONG_ADMIN_ERROR_LOG"
          value = "/dev/stderr"
        },
        {
          name  = "KONG_ADMIN_LISTEN"
          value = "0.0.0.0:8001"
        },
        {
          name  = "KONG_DECLARATIVE_CONFIG_STRING"
          value = local.kong_config
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "/ecs/kong"
          "awslogs-region"        = "eu-west-1"  # Change to your region
          "awslogs-stream-prefix" = "kong"
        }
      }
    }
  ])
}

# ECS Service

resource "aws_ecs_service" "kong" {
  name            = "kong"
  cluster         = aws_ecs_cluster.kong.id
  task_definition = aws_ecs_task_definition.kong.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  load_balancer {
    target_group_arn = aws_lb_target_group.kong.arn
    container_name   = "kong"
    container_port   = 8000
  }

  network_configuration {
    subnets          = [aws_subnet.private_1.id, aws_subnet.private_2.id]
    security_groups  = [aws_security_group.kong.id]
    assign_public_ip = false
  }
}

# IAM Roles
resource "aws_iam_role" "ecs_execution_role" {
  name = "kong-ecs-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

# ALB Security Group

resource "aws_security_group" "alb" {
  name        = "kong-alb-sg"
  description = "Security group for Kong ALB"
  vpc_id      = aws_vpc.main.id

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

  tags = {
    Name = "kong-alb-sg"
  }
}

# Application Load Balancer

# Update the ALB to use both public subnets
resource "aws_lb" "kong" {
  name               = "kong-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = [aws_subnet.public.id, aws_subnet.public_2.id]  # Now using both subnets

  tags = {
    Name = "kong-alb"
  }
}




# ALB Target Group
resource "aws_lb_target_group" "kong" {
  name        = "kong-tg"
  port        = 8000
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"

  health_check {
    path                = "/status"
    healthy_threshold   = 2
    unhealthy_threshold = 10
    timeout             = 5
    interval           = 10
  }
}

# ALB Listener
resource "aws_lb_listener" "kong" {
  load_balancer_arn = aws_lb.kong.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.kong.arn
  }
}


# Update Kong security group to allow traffic from ALB
resource "aws_security_group_rule" "kong_from_alb" {
  type                     = "ingress"
  from_port                = 8000
  to_port                  = 8000
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.alb.id
  security_group_id        = aws_security_group.kong.id
}

# Output the ALB DNS name
output "kong_endpoint" {
  value = "http://${aws_lb.kong.dns_name}"
}

resource "aws_iam_role" "ecs_task_role" {
  name = "kong-ecs-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

# Attach required policies to the execution role
resource "aws_iam_role_policy_attachment" "ecs_execution_role_policy" {
  role       = aws_iam_role.ecs_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "kong" {
  name              = "/ecs/kong"
  retention_in_days = 30
}


