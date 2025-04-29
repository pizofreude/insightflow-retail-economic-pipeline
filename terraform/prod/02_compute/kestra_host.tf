# -----------------------------------------------------
# Kestra Hosting Resources (UPDATED - in kestra_host.tf or main.tf)
# -----------------------------------------------------

# Security Group for Kestra EC2 instance
resource "aws_security_group" "kestra_sg" {
  name        = local.kestra_ec2_sg_name
  description = "Allow Kestra UI and SSH access"
  vpc_id      = data.aws_vpc.default.id

  # Allow inbound traffic on Kestra UI port (default 8080)
  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = var.kestra_allowed_cidr_blocks # Restrict this for production
  }

  # Allow inbound SSH traffic (port 22) - Optional, restrict CIDR
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.kestra_ssh_allowed_cidr_blocks # Restrict this to your IP for security
  }

  # Allow all outbound traffic (needed for pulling images, accessing AWS APIs, etc.)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1" # All protocols
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = local.common_tags
}

# EC2 Instance to host Kestra + PostgreSQL via Docker Compose
resource "aws_instance" "kestra_server" {
  ami                    = data.aws_ami.amazon_linux_2.id
  instance_type          = var.kestra_instance_type
  key_name               = var.kestra_key_name   # Ensure this key pair exists in your AWS account/region
  vpc_security_group_ids = [aws_security_group.kestra_sg.id]
  # Ensure instance is in a public subnet if assign_public_ip is true or using EIP
  # subnet_id = data.aws_subnets.default.ids[0] # Example: Use first default subnet

  iam_instance_profile = aws_iam_instance_profile.kestra_ec2_profile.name

  # User data script to install Docker, Docker Compose, and configure Kestra
  user_data = <<-EOF
              #!/bin/bash
              # Install Docker
              yum update -y
              yum install -y docker
              systemctl start docker
              systemctl enable docker
              usermod -a -G docker ec2-user

              # Install Docker Compose V2
              DOCKER_COMPOSE_VERSION=v2.24.6
              mkdir -p /home/ec2-user/.docker/cli-plugins/
              curl -SL https://github.com/docker/compose/releases/download/$${DOCKER_COMPOSE_VERSION}/docker-compose-linux-x86_64 -o /home/ec2-user/.docker/cli-plugins/docker-compose
              chmod +x /home/ec2-user/.docker/cli-plugins/docker-compose
              chown ec2-user:ec2-user /home/ec2-user/.docker/cli-plugins/docker-compose

              # Fix permissions for .docker directory
              sudo chown -R ec2-user:ec2-user /home/ec2-user/.docker
              chmod -R 700 /home/ec2-user/.docker

              # Create Kestra directory
              mkdir -p /home/ec2-user/kestra
              chown -R ec2-user:ec2-user /home/ec2-user/kestra

              # Create application.yaml for Kestra configuration
              cat <<'EOT' > /home/ec2-user/kestra/application.yaml
              kestra:
                server:
                  port: 8080
                datasources:
                  postgres:
                    url: jdbc:postgresql://postgres:5432/kestra_db
                    username: kestra
                    password: kestra_password
                storage:
                  type: s3
                  s3:
                    bucket: insightflow-prod-processed-data
                    region: ap-southeast-2
                queue:
                  type: postgres
                repository:
                  type: postgres
              EOT
              chown ec2-user:ec2-user /home/ec2-user/kestra/application.yaml

              # Create docker-compose.yml for Kestra and PostgreSQL
              cat <<'EOT' > /home/ec2-user/kestra/docker-compose.yml
              version: '3.8'
              services:
                postgres:
                  image: postgres:15
                  container_name: kestra_postgres
                  restart: always
                  environment:
                    POSTGRES_USER: kestra
                    POSTGRES_PASSWORD: kestra_password
                    POSTGRES_DB: kestra_db
                  volumes:
                    - postgres_data:/var/lib/postgresql/data
                  ports:
                    - "5432:5432"

                kestra:
                  image: kestra/kestra:latest
                  container_name: kestra_server
                  restart: always
                  depends_on:
                    - postgres
                  ports:
                    - "8080:8080"
                  command: server standalone --worker-thread=128 --config /etc/config/application.yaml
                  environment:
                    KESTRA_CONFIGURATION_DATASOURCES_POSTGRES_URL: jdbc:postgresql://postgres:5432/kestra_db
                    KESTRA_CONFIGURATION_DATASOURCES_POSTGRES_USERNAME: kestra
                    KESTRA_CONFIGURATION_DATASOURCES_POSTGRES_PASSWORD: kestra_password
                    KESTRA_CONFIGURATION_STORAGE_TYPE: s3
                    KESTRA_CONFIGURATION_STORAGE_S3_BUCKET: insightflow-prod-processed-data
                    KESTRA_CONFIGURATION_STORAGE_S3_REGION: ap-southeast-2
                  volumes:
                    - kestra-data:/app/storage
                    - /var/run/docker.sock:/var/run/docker.sock
                    - /tmp/kestra-wd:/tmp/kestra-wd
                    - /home/ec2-user/kestra/application.yaml:/etc/config/application.yaml

              volumes:
                postgres_data:
                kestra-data:
              EOT
              chown ec2-user:ec2-user /home/ec2-user/kestra/docker-compose.yml

              # Start Docker Compose
              sudo su - ec2-user -c "cd /home/ec2-user/kestra && docker compose up -d"

              # Wait for PostgreSQL to be ready
              until docker exec kestra_postgres pg_isready -U kestra -d kestra_db; do
                echo "Waiting for PostgreSQL to be ready..."
                sleep 5
              done
              
              # Restart Kestra to ensure it connects to the database
              docker restart kestra_server
              EOF

  tags = merge(local.common_tags, {
    Name = local.kestra_ec2_instance_name
  })

  depends_on = [aws_iam_instance_profile.kestra_ec2_profile]
}

# Optional: Allocate and associate an Elastic IP for a static address
resource "aws_eip" "kestra_eip" {
  instance = aws_instance.kestra_server.id
  domain   = "vpc"
  tags = merge(local.common_tags, {
    Name = local.kestra_ec2_eip_name
  })
}