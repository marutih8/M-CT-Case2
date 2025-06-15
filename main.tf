provider "aws" {
  region = var.region
}

# -------------------------------
# 2. Create Security Group
# -------------------------------
resource "aws_security_group" "instance_sg" {
  name        = "web-sg"
  description = "Allow HTTP and SSH"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# -------------------------------
# ALB Target Groups
# -------------------------------
resource "aws_lb_target_group" "blue" {
  name        = "blue-tg"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "instance"
}

resource "aws_lb_target_group" "green" {
  name        = "green-tg"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "instance"
}

# -------------------------------
# ALB
# -------------------------------
resource "aws_lb" "main" {
  name               = "bluegreen-alb"
  internal           = false
  load_balancer_type = "application"
  subnets            = var.public_subnets
  security_groups    = [aws_security_group.instance_sg.id]

  tags = {
    Name = "BlueGreenALB"
  }
}

# -------------------------------
# Listener (Initially Blue)
# -------------------------------
resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.main.arn
  port              = 443
  protocol          = "HTTPS"
  certificate_arn   = var.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.blue.arn
  }
}

# -------------------------------
# EC2 Instances - Blue
# -------------------------------
resource "aws_instance" "blue" {
  count                     = 2
  ami                       = var.ami_id
  instance_type             = var.instance_type
  subnet_id                 = element(var.public_subnets, count.index)
  key_name                  = var.key_name
  vpc_security_group_ids    = [aws_security_group.instance_sg.id]

  tags = {
    Name = "blue-ec2-${count.index + 1}"
  }

  user_data = <<-EOF
               #!/bin/bash
              apt update -y
              apt install -y apache2 wget unzip
              cd /var/www/html
              wget https://www.tooplate.com/zip-templates/2133-moso-interior.zip
              unzip 2133-moso-interior.zip
              cp -r 2133-moso-interior/* .
              rm -rf 2133-moso-interior 2133-moso-interior.zip
              systemctl start apache2
              systemctl enable apache2
              EOF
}

resource "aws_lb_target_group_attachment" "blue_attach" {
  count              = 2
  target_group_arn   = aws_lb_target_group.blue.arn
  target_id          = aws_instance.blue[count.index].id
  port               = 80
}

# -------------------------------
# EC2 Instances - Green
# -------------------------------
resource "aws_instance" "green" {
  count                     = 2
  ami                       = var.ami_id
  instance_type             = var.instance_type
  subnet_id                 = element(var.public_subnets, count.index)
  key_name                  = var.key_name
  vpc_security_group_ids    = [aws_security_group.instance_sg.id]

  tags = {
    Name = "green-ec2-${count.index + 1}"
  }

  user_data = <<-EOF
              #!/bin/bash
              apt update -y
              apt install -y apache2 wget unzip
              cd /var/www/html
              wget https://www.tooplate.com/zip-templates/2129_crispy_kitchen.zip
              unzip 2129_crispy_kitchen.zip
              cp -r 2129_crispy_kitchen/* .
              systemctl start apache2
              systemctl enable apache2
              EOF
}

resource "aws_lb_target_group_attachment" "green_attach" {
  count              = 2
  target_group_arn   = aws_lb_target_group.green.arn
  target_id          = aws_instance.green[count.index].id
  port               = 80
}

# -------------------------------
# Listener Rule for Green Path
# -------------------------------
resource "aws_lb_listener_rule" "green_rule" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.green.arn
  }

  condition {
    path_pattern {
      values = ["/green/*"]
    }
  }
}

