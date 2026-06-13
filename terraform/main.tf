resource "aws_security_group" "automation_sg" {
  name        = "ai-automation-sg"
  description = "Security group for AI Automation Workflow setup"

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_ip]
  }

  ingress {
    description = "n8n"
    from_port   = 5678
    to_port     = 5678
    protocol    = "tcp"
    cidr_blocks = [var.my_ip]
  }

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [var.my_ip]
  }

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.my_ip]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "ai-automation-sg"
    Project = "AI Automation Workflow"
  }
}

resource "aws_key_pair" "ai_automation_key" {
  key_name   = var.key_name
  public_key = file("${path.module}/key-pair/ai-automation-key.pub")
}

resource "aws_instance" "automation_server" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  key_name               = aws_key_pair.ai_automation_key.key_name
  vpc_security_group_ids = [aws_security_group.automation_sg.id]

  user_data = file("docker-install.sh")

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
  }

  tags = {
    Name    = "ai-automation-server"
    Project = "AI Automation Workflow"
  }
}

resource "aws_eip" "automation_eip" {
  domain = "vpc"

  tags = {
    Name = "ai-automation-eip"
  }
}

resource "aws_eip_association" "automation_eip_assoc" {
  instance_id   = aws_instance.automation_server.id
  allocation_id = aws_eip.automation_eip.id
}