# Execute Packer to build a custom AMI
resource "null_resource" "packer_build" {
  provisioner "local-exec" {
    command = "packer build ./packer_template.json"
  }

  triggers = {
    always_run = "${timestamp()}"
  }
}

# Wait for the custom AMI to be created by Packer
data "aws_ami" "custom_ami" {
  most_recent = true
  filter {
    name   = "name"
    values = ["custom-ami-vite-*"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
  owners = ["self"]
  depends_on = [null_resource.packer_build]
}

# Security group to allow SSH, HTTP, HTTPS, 8080, and 9000 for Jenkins and SonarQube
resource "aws_security_group" "allow_ssh_http_https" {
  name        = "allow_ssh_http_https"
  description = "Allow SSH, HTTP, HTTPS, Jenkins, SonarQube"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Allow SSH from anywhere
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Allow HTTP from anywhere
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Allow HTTPS from anywhere
  }

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Allow Jenkins (HTTP) from anywhere
  }

  ingress {
    from_port   = 9000
    to_port     = 9000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Allow SonarQube from anywhere
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]  # Allow all outbound traffic
  }
}

# EC2 instance launched from custom AMI
resource "aws_instance" "my_ec2" {
  ami             = data.aws_ami.custom_ami.id   # Use the custom AMI ID from Packer
  instance_type   = "t2.medium"                   # Adjust based on your requirements
  key_name        = "keydemo"               # Your SSH key pair name
  security_groups = [aws_security_group.allow_ssh_http_https.name]

  tags = {
    Name = "SonarQube-Jenkins-Instance"
  }
}

# Create an Ansible inventory file dynamically
resource "local_file" "ansible_inventory" {
  filename = "inventory.ini"
  content  = <<-EOF
  [my_ec2]
  ${aws_instance.my_ec2.public_ip} ansible_user=ubuntu ansible_ssh_private_key_file=/home/jeeva/.ssh/keydemo.pem
  EOF
}
# Run Ansible playbooks for Jenkins and SonarQube configuration
resource "null_resource" "run_ansible_playbook" {
  provisioner "local-exec" {
    command = "sleep 30 && ansible-playbook -i inventory.ini master_playbook.yml"
  }
  depends_on = [aws_instance.my_ec2, local_file.ansible_inventory]
}

