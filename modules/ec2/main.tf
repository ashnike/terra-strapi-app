# Generate a TLS private key
resource "tls_private_key" "pri_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Create an AWS key pair using the generated TLS private key
resource "aws_key_pair" "keypair" {
  key_name   = "pipelines"
  public_key = tls_private_key.pri_key.public_key_openssh

  provisioner "local-exec" {
    command = "echo '${tls_private_key.pri_key.private_key_pem}' > ./strapi.pem"
  }
}

# Create a security group for the Strapi instance
resource "aws_security_group" "strapi_sg" {
  vpc_id      = var.vpc_id
  name        = "strapi-sg"
  description = "strapi server sg"

  # Define inbound rules for Strapi
  ingress {
    from_port   = 1337
    to_port     = 1337
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Define inbound rules for SSH
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Define outbound rule for all traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Create an AWS instance for the Strapi server
resource "aws_instance" "strapi_instance" {
  ami               = var.ami_id
  instance_type     = var.instance_type_strapi
  subnet_id         = var.public_subnet_ids[0] # Assuming there's only one subnet
  security_groups   = [aws_security_group.strapi_sg.id]
  key_name          = aws_key_pair.keypair.key_name
  iam_instance_profile = var.instance_profile_name
  depends_on        = [aws_security_group.strapi_sg]
  
  user_data = <<-EOF
                #!/bin/bash
                sudo apt-get update
                curl -sL https://deb.nodesource.com/setup_18.x | sudo -E bash -
                sudo apt-get install -y nodejs npm
                sudo npm install pm2 -g
                if [ ! -d /srv/strapi ]; then sudo git clone https://github.com/ashnike/strapi-app /srv/strapi; else cd /srv/strapi && sudo git pull origin master; fi
                sudo chmod u+x /srv/strapi/strapi-app/d2strapi/generate_env.sh*
                cd /srv/strapi/strapi-app/d2strapi
                sudo ./generate_env.sh
                cd /srv/strapi
                npm install
                npm run build
                pm2 start npm --name "strapi" -- run start
              EOF

  root_block_device {
    volume_size = 30  # Change this to the desired size in GB
    volume_type = "gp2"  # Change this to the desired volume type if necessary
  }

  tags = {
    Name    = "strapi-server"
    Project = "strapi"
  }
}
