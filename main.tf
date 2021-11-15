##################################################################################
# AMI
##################################################################################

data "aws_ami" "ami_ubuntu_1804_latest" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-bionic-18.04-amd64-server*"]
  }
}


##################################################################################
# SECURITY_GROUPS
##################################################################################
resource "aws_default_security_group" "default_security_group" {
  vpc_id = var.vpc_id

  tags = {
    "Name" = "${var.purpose_tag}_default_security_group"
  }
}

resource "aws_security_group" "allow_any_http_in_sg" {
  name   = "allow-any-http-in-sg"
  vpc_id = var.vpc_id

  ingress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
  }

  tags = {
    "Name" = "${var.purpose_tag}-allow-any-http-in-sg"
  }
}

resource "aws_security_group" "allow_any_ssh_in_sg" {
  name   = "allow-any-ssh-in-sg"
  vpc_id = var.vpc_id

  ingress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
  }

  tags = {
    "Name" = "${var.purpose_tag}-allow-any-ssh-in-sg"
  }
}

resource "aws_security_group" "allow_any_all_out_sg" {
  name   = "allow-any-all-out-sg"
  vpc_id = var.vpc_id

  egress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port   = 0
    to_port     = 0
    protocol    = -1
  }

  tags = {
    "Name" = "${var.purpose_tag}-allow-any-all-out-sg"
  }
}

##################################################################################
# DB NETWORK INTERFACES
##################################################################################

resource "aws_network_interface" "db_network_interfaces" {
  count     = var.instance_count
  subnet_id = var.private_subnets_ids[count.index % length(var.private_subnets_ids)]
  # To Allow SSH Connection Through Bastion Host add -> , aws_security_group.allow_any_ssh_in_sg.id
  security_groups = [aws_security_group.allow_any_all_out_sg.id]

  tags = {
    Name = "${var.purpose_tag}-network-interface-db-${count.index + 1}"
  }
}

##################################################################################
# DB EC2 INSTANCES
##################################################################################

resource "aws_instance" "db_servers" {
  count             = var.instance_count
  ami               = data.aws_ami.ami_ubuntu_1804_latest.id
  instance_type     = var.instance_type_db
  key_name          = var.key_name
  availability_zone = var.available_zone_names[count.index % length(var.available_zone_names)]

  network_interface {
    network_interface_id = aws_network_interface.db_network_interfaces[count.index].id
    device_index         = 0
  }

  tags = {
    Name    = "${var.purpose_tag}-db-srv-${count.index + 1}"
    Owner   = var.owner_tag
    Purpose = var.purpose_tag
  }
}

##################################################################################
# WEB NETWORK INTERFACES
##################################################################################

resource "aws_network_interface" "web_network_interfaces" {
  count           = var.instance_count
  subnet_id       = var.public_subnets_ids[count.index % length(var.public_subnets_ids)]
  security_groups = [aws_security_group.allow_any_http_in_sg.id, aws_security_group.allow_any_ssh_in_sg.id, aws_security_group.allow_any_all_out_sg.id]

  tags = {
    Name = "${var.purpose_tag}-network-interface-web-${count.index + 1}"
  }
}

##################################################################################
# WEB EC2 INSTANCES
##################################################################################

resource "aws_instance" "nginx_web_servers" {
  count                = var.instance_count
  ami                  = data.aws_ami.ami_ubuntu_1804_latest.id
  instance_type        = var.instance_type_web
  key_name             = var.key_name
  availability_zone    = var.available_zone_names[count.index % length(var.available_zone_names)]
  user_data            = local.nginx-webserver
  iam_instance_profile = aws_iam_instance_profile.web_instance_profile.id

  network_interface {
    network_interface_id = aws_network_interface.web_network_interfaces[count.index].id
    device_index         = 0
  }

  connection {
    type        = "ssh"
    host        = self.public_ip
    user        = "ubuntu"
    private_key = file(var.private_key_path)
  }

  tags = {
    Name    = "${var.purpose_tag}-web-srv-${count.index + 1}"
    Owner   = var.owner_tag
    Purpose = var.purpose_tag
  }
}


##################################################################################
# WEB APP LOAD-BALANCER
##################################################################################


resource "aws_lb" "web_alb" {
  name               = "web-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.allow_any_http_in_sg.id, aws_security_group.allow_any_all_out_sg.id]
  subnets            = var.public_subnets_ids

  enable_deletion_protection = false

  # access_logs {
  #   bucket  = "${var.s3_logs_bucket_name}"
  #   prefix  = "${var.s3_logs_folder}/alb-logs/alb.access_logs"
  #   enabled = true
  # }

  tags = {
    Name = "${var.purpose_tag}-web-alb"
  }
}

resource "aws_alb_target_group" "nginx_web_servers" {
  name     = "alb-web-servers-target-group"
  port     = 80
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  stickiness {
    type            = "lb_cookie"
    cookie_duration = 60
    enabled         = true
  }

  health_check {
    port                = 80
    protocol            = "HTTP"
    path                = "/"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 3
    interval            = 10
  }
}

resource "aws_alb_listener" "http_listener" {
  load_balancer_arn = aws_lb.web_alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_alb_target_group.nginx_web_servers.arn
  }
}

resource "aws_alb_target_group_attachment" "web_alb_to_nginx_web_servers" {
  count            = var.instance_count
  target_group_arn = aws_alb_target_group.nginx_web_servers.arn
  target_id        = aws_instance.nginx_web_servers.*.id[count.index]
  port             = 80
}
