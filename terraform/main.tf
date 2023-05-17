terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 4.0, < 5.0"
    }
  }
}

provider "aws" {
  region  = "us-east-1"
  profile = "terraform"
}

# Resources created in AWS Console before using this Terraform Configuration: #
# -- ACM Certificate for my API Gateway Custom Domain ------------------------#
# -- ECR private repo with my app container ----------------------------------#

data "aws_api_gateway_domain_name" "domain" {
  domain_name = var.domain-name
}

#----------------------------------------------------------#
#--------------------------VPC-----------------------------#
#----------------------------------------------------------#
# VPC will use a /23 prefix for a total of 512 IP's in     #
# the VPC. The subnets will use a /27 prefix for 32 IP's   #
# in each subnet. This will allow for a total of 16        #
# subnets. We will start by creating 4 (2 Public and 2     #
# Private), which should leave sufficient room for         #
# expansion if necessary. ---------------------------------#
#----------------------------------------------------------#

resource "aws_vpc" "vpc" {
  cidr_block           = "10.16.0.0/23"
  instance_tenancy     = "default"
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = {
    Name = "hangman-vpc-tf"
  }
}

#--------------------Internet-Gateway----------------------#

resource "aws_internet_gateway" "internet_gateway" {
  vpc_id = aws_vpc.vpc.id
  tags = {
    Name = "hangman-igw-tf"
  }
}

#---------------------Public-Subnets-----------------------#
# Creates public subnets with a route to the internet      #
# gateway. These subnets wont be used in this configuration#
# But could be of use in the future -----------------------#
#----------------------------------------------------------#

resource "aws_subnet" "public_1" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = "10.16.0.0/27"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true
  tags = {
    Name = "public-subnet-1"
  }
}

resource "aws_subnet" "public_2" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = "10.16.0.32/27"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = true
  tags = {
    Name = "public-subnet-2"
  }
}

#----------------Public Subnet Route Table-----------------#

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.internet_gateway.id
  }

  tags = {
    Name = "public"
  }
}

resource "aws_route_table_association" "public_rt_1" {
  subnet_id      = aws_subnet.public_1.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_rt_2" {
  subnet_id      = aws_subnet.public_2.id
  route_table_id = aws_route_table.public.id
}

#---------------------Private-Subnets-----------------------#
#- Creates Private Subnets that will host the ECS Cluster.  #
#-----------------------------------------------------------#

resource "aws_subnet" "private_1" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = "10.16.0.128/27"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = false
  tags = {
    Name = "private-subnet-1"
  }
}

resource "aws_subnet" "private_2" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = "10.16.0.160/27"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = false
  tags = {
    Name = "private-subnet-2"
  }
}

#----------------Private Subnet Route Table----------------#

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name = "private"
  }
}

resource "aws_route_table_association" "private_rt_1" {
  subnet_id      = aws_subnet.private_1.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "private_rt_2" {
  subnet_id      = aws_subnet.private_2.id
  route_table_id = aws_route_table.private.id
}

#-------------------Security-Groups-----------------------#
#- Creates the Security Groups Necessary for the ---------#
#- configuration to communicate properly -----------------#
#---------------------------------------------------------#

#---------------------VPC-Link-SG-------------------------#
#- Any Traffic -> VPC Link -------------------------------#
#- VPC Link    -> Application Load Balancer (HTTP) -------#
#- VPC Link    -> Application Load Balancer (HTTPS) ------#
#---------------------------------------------------------#

resource "aws_security_group" "vpc-link-sg" {
  name        = "vpc-link-sg-tf"
  description = "Security group for the VPC-Link"
  vpc_id      = aws_vpc.vpc.id
}

resource "aws_security_group_rule" "ingress-from-internet" {
  security_group_id = aws_security_group.vpc-link-sg.id
  type              = "ingress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  description = "Any Traffic to VPC Link"
}

resource "aws_security_group_rule" "egress-to-alb-http" {
  security_group_id        = aws_security_group.vpc-link-sg.id
  type                     = "egress"
  from_port                = 80
  to_port                  = 80
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.alb-sg.id
  description = "VPC Link to Application Load Balancer (HTTP)"
}

resource "aws_security_group_rule" "egress-to-alb-https" {
  security_group_id        = aws_security_group.vpc-link-sg.id
  type                     = "egress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.alb-sg.id
  description = "VPC Link to Application Load Balancer (HTTPS)"
}

#-------------Application-Load-Balancer-SG----------------#
#- Local    -> ALB ---------------------------------------#
#- VPC Link -> ALB ---------------------------------------#
#- ALB      -> Elastic Container Service -----------------#
#---------------------------------------------------------#

resource "aws_security_group" "alb-sg" {
  name        = "alb-sg-tf"
  description = "Security group for the Application Load Balancer"
  vpc_id      = aws_vpc.vpc.id
}

resource "aws_security_group_rule" "ingress-from-vpc" {
  security_group_id = aws_security_group.alb-sg.id
  type              = "ingress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["10.16.0.0/23"]
  description = "Local to ALB"
}

resource "aws_security_group_rule" "ingress-from-vpc-link" {
  security_group_id        = aws_security_group.alb-sg.id
  type                     = "ingress"
  from_port                = 0
  to_port                  = 0
  protocol                 = "-1"
  source_security_group_id = aws_security_group.vpc-link-sg.id
  description = "VPC Link to ALB"
}

resource "aws_security_group_rule" "egress-to-ecs" {
  security_group_id        = aws_security_group.alb-sg.id
  type                     = "egress"
  from_port                = 0
  to_port                  = 0
  protocol                 = "-1"
  source_security_group_id = aws_security_group.ecs-sg.id
  description = "ALB to Elastic Container Service"
}

#--------------Elastic-Container-Service-SG---------------#
#- ALB           -> ECS ----------------------------------#
#- VPC Endpoints -> ECS ----------------------------------#
#- ECS           -> ECS ----------------------------------#
#- ECS           -> ALB ----------------------------------#
#- ECS           -> VPC Endpoints ------------------------#
#- ECS           -> Anywhere -----------------------------#
#---------------------------------------------------------#

resource "aws_security_group" "ecs-sg" {
  name        = "ecs-sg-tf"
  description = "Security group for the ECS Cluster"
  vpc_id      = aws_vpc.vpc.id
}

resource "aws_security_group_rule" "ingress-from-alb" {
  security_group_id        = aws_security_group.ecs-sg.id
  type                     = "ingress"
  from_port                = 0
  to_port                  = 0
  protocol                 = "-1"
  source_security_group_id = aws_security_group.alb-sg.id
  description = "ALB to ECS"
}

resource "aws_security_group_rule" "ingress-from-vpc-endpoints" {
  security_group_id        = aws_security_group.ecs-sg.id
  type                     = "ingress"
  from_port                = 0
  to_port                  = 0
  protocol                 = "-1"
  source_security_group_id = aws_security_group.vpc-endpoint-sg.id
  description = "VPC Endpoints to ECS"
}

resource "aws_security_group_rule" "ingress-from-ecs" {
  security_group_id        = aws_security_group.ecs-sg.id
  type                     = "ingress"
  from_port                = 0
  to_port                  = 0
  protocol                 = "-1"
  source_security_group_id = aws_security_group.ecs-sg.id
  description = "ECS to ECS"
}

resource "aws_security_group_rule" "egress-to-alb" {
  security_group_id        = aws_security_group.ecs-sg.id
  type                     = "egress"
  from_port                = 0
  to_port                  = 0
  protocol                 = "-1"
  source_security_group_id = aws_security_group.alb-sg.id
  description = "ECS to ALB"
}

resource "aws_security_group_rule" "egress-to-vpc-endpoints" {
  security_group_id        = aws_security_group.ecs-sg.id
  type                     = "egress"
  from_port                = 0
  to_port                  = 0
  protocol                 = "-1"
  source_security_group_id = aws_security_group.vpc-endpoint-sg.id
  description = "ECS to VPC Endpoints"
}

resource "aws_security_group_rule" "egress-to-anywhere" {
  security_group_id = aws_security_group.ecs-sg.id
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  description = "ECS to Anywhere"
}

#--------------------VPC-Endpoint-SG----------------------#
#- Local            -> VPC Endpoints ---------------------#
#- VPC Endpoints    -> Local -----------------------------#
#---------------------------------------------------------#

resource "aws_security_group" "vpc-endpoint-sg" {
  name        = "vpc-endpoint-sg-tf"
  description = "Security group for the VPC Endpoints"
  vpc_id      = aws_vpc.vpc.id
}

resource "aws_security_group_rule" "ingress-local" {
  security_group_id = aws_security_group.vpc-endpoint-sg.id
  type              = "ingress"
  from_port         = "0"
  to_port           = "0"
  protocol          = "-1"
  cidr_blocks       = ["10.16.0.0/23"]
  description = "Local to VPC Endpoints"
}

resource "aws_security_group_rule" "egress-local" {
  security_group_id = aws_security_group.vpc-endpoint-sg.id
  type              = "egress"
  from_port         = "0"
  to_port           = "0"
  protocol          = "-1"
  cidr_blocks       = ["10.16.0.0/23"]
  description = "VPC Endpoints to Local"
}

#---------------------VPC-Endpoints------------------------#
# This creates 4 different VPC Endpoints for each of my ---#
# private subnets (3 Interface, 1 Gateway): ---------------#
# - com.amazonaws.us-east-1.ecr.dkr (IF)-------------------#
# - com.amazonaws.us-east-1.ecr.api (IF)-------------------#
# - com.amazonaws.us-east-1.s3 (GW)------------------------#
# - com.amazonaws.us-east-1.logs (IF)----------------------#
# ---------------------------------------------------------#

resource "aws_vpc_endpoint" "interface_endpoint_ecs_dkr" {
  vpc_id             = aws_vpc.vpc.id
  service_name       = "com.amazonaws.${var.region}.ecr.dkr"
  vpc_endpoint_type  = "Interface"
  security_group_ids = [aws_security_group.vpc-endpoint-sg.id]
  subnet_ids         = [aws_subnet.private_1.id, aws_subnet.private_2.id]
  ip_address_type = "ipv4"
  private_dns_enabled = true

  dns_options {
    dns_record_ip_type = "ipv4"
  }

  tags = {
    Name = "Connect-ECS-DKR"
  }
}

resource "aws_vpc_endpoint" "interface_endpoint_ecs_api" {
  vpc_id             = aws_vpc.vpc.id
  service_name       = "com.amazonaws.${var.region}.ecr.api"
  vpc_endpoint_type  = "Interface"
  security_group_ids = [aws_security_group.vpc-endpoint-sg.id]
  subnet_ids         = [aws_subnet.private_1.id, aws_subnet.private_2.id]
  ip_address_type = "ipv4"
  private_dns_enabled = true

  dns_options {
    dns_record_ip_type = "ipv4"
  }

  tags = {
    Name = "Connect-ECS-API"
  }
}

resource "aws_vpc_endpoint" "interface_endpoint_cw_logs" {
  vpc_id             = aws_vpc.vpc.id
  service_name       = "com.amazonaws.${var.region}.logs"
  vpc_endpoint_type  = "Interface"
  security_group_ids = [aws_security_group.vpc-endpoint-sg.id]
  subnet_ids         = [aws_subnet.private_1.id, aws_subnet.private_2.id]
  ip_address_type = "ipv4"
  private_dns_enabled = true

  dns_options {
    dns_record_ip_type = "ipv4"
  }

  tags = {
    Name = "Connect-Cloudwatch-Logs"
  }
}

resource "aws_vpc_endpoint" "gateway_endpoint_s3" {
  vpc_id            = aws_vpc.vpc.id
  service_name      = "com.amazonaws.${var.region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids = [aws_route_table.private.id]
  tags = {
    Name = "Connect-S3"
  }
}


#----------------Application-Load-Balancer-----------------#
# Creates the Target Group that will point towards the ECS #
# Cluster and the Application Load Balancer that sends ----#
# traffic to the target group, listening in HTTP:80 -------#
#----------------------------------------------------------#

resource "aws_lb_target_group" "target-group" {
  name        = var.tg-name
  port        = var.container-port
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = aws_vpc.vpc.id
}

resource "aws_lb" "alb" {
  name               = var.alb-name
  internal           = true
  load_balancer_type = "application"

  subnets         = [aws_subnet.private_1.id, aws_subnet.private_2.id]
  security_groups = [aws_security_group.alb-sg.id]
}

resource "aws_lb_listener" "http_listener" {
  load_balancer_arn = aws_lb.alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.target-group.arn
  }
}

#----------------------------------------------------------#
#----------------Elastic-Container-Service-----------------#
#----------------------------------------------------------#

resource "aws_ecs_cluster" "cluster" {
  name = "Hangman-Cluster"
}

resource "aws_ecs_task_definition" "task_definition" {
  family                   = "Hangman-TaskDefinition"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  task_role_arn            = var.execution-role-arn
  execution_role_arn       = var.execution-role-arn
  cpu                      = 512
  memory                   = 1024

  container_definitions = jsonencode([
    {
      name          = "hangman"
      image         = "185666942958.dkr.ecr.us-east-1.amazonaws.com/hangman:v7"
      essential     = true
      portMappings = [
        {
          containerPort = 5000
          hostPort      = 5000
          protocol      = "tcp"
          appProtocol   = "http"
        }
      ]
    }
])
}

resource "aws_ecs_service" "service" {
  name = var.service-name
  cluster = aws_ecs_cluster.cluster.id
  task_definition = aws_ecs_task_definition.task_definition.id
  desired_count = 2
  

  network_configuration {
    security_groups = [aws_security_group.ecs-sg.id]
    subnets = [aws_subnet.private_1.id, aws_subnet.private_2.id]
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.target-group.arn
    container_name = var.container-name
    container_port = var.container-port

  }
}

#----------------------------------------------------------#
#-----------------------API-Gateway------------------------#
#----------------------------------------------------------#

resource "aws_apigatewayv2_vpc_link" "vpc-link" {
  name               = "hangman-vpc-link"
  security_group_ids = [aws_security_group.vpc-link-sg.id]
  subnet_ids         = [aws_subnet.private_1.id, aws_subnet.private_2.id]
}

resource "aws_apigatewayv2_api" "http-api-gateway" {
  name          = "hangman"
  protocol_type = "HTTP"
  api_key_selection_expression = "$request.header.x-api-key"

}

resource "aws_apigatewayv2_stage" "stage" {
  api_id = aws_apigatewayv2_api.http-api-gateway.id
  name   = "$default"
  auto_deploy = true
}

resource "aws_apigatewayv2_integration" "integration" {
  api_id = aws_apigatewayv2_api.http-api-gateway.id
  integration_uri = aws_lb_listener.http_listener.arn
  integration_type = "HTTP_PROXY"
  integration_method = "ANY"
  connection_type = "VPC_LINK"
  connection_id = aws_apigatewayv2_vpc_link.vpc-link.id
}

resource "aws_apigatewayv2_route" "route" {
  api_id    = aws_apigatewayv2_api.http-api-gateway.id
  route_key = "ANY /{proxy+}"
  target = "integrations/${aws_apigatewayv2_integration.integration.id}"
}

resource "aws_apigatewayv2_api_mapping" "mapping" {
  api_id      = aws_apigatewayv2_api.http-api-gateway.id
  domain_name = var.domain-name
  stage       = aws_apigatewayv2_stage.stage.id
}
