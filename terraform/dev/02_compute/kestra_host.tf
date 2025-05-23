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
  key_name               = var.kestra_key_name # Ensure this key pair exists in your AWS account/region
  vpc_security_group_ids = [aws_security_group.kestra_sg.id]
  # Ensure instance is in a public subnet if assign_public_ip is true or using EIP
  # subnet_id = data.aws_subnets.default.ids[0] # Example: Use first default subnet

  iam_instance_profile = aws_iam_instance_profile.kestra_ec2_profile.name

  # User data script to install Docker, Docker Compose, and run Kestra
  user_data = <<-EOF
              #!/bin/bash
              # Install Docker
              yum update -y
              yum install -y docker
              systemctl start docker
              systemctl enable docker
              usermod -a -G docker ec2-user

              # Install Docker Compose V2 (check for latest version)
              DOCKER_COMPOSE_VERSION=v2.24.6 # Specify desired version
              mkdir -p /home/ec2-user/.docker/cli-plugins/
              curl -SL https://github.com/docker/compose/releases/download/$${DOCKER_COMPOSE_VERSION}/docker-compose-linux-x86_64 -o /home/ec2-user/.docker/cli-plugins/docker-compose
              chmod +x /home/ec2-user/.docker/cli-plugins/docker-compose
              chown ec2-user:ec2-user /home/ec2-user/.docker/cli-plugins/docker-compose

              # Fix permissions for .docker directory
              sudo chown -R ec2-user:ec2-user /home/ec2-user/.docker
              chmod -R 700 /home/ec2-user/.docker

              # Create Kestra directory and Docker Compose configuration
              mkdir -p /home/ec2-user/kestra
              chown -R ec2-user:ec2-user /home/ec2-user/kestra
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
    build:
      context: /home/ec2-user/kestra
      dockerfile: Dockerfile
    container_name: kestra_server
    restart: always
    depends_on:
      - postgres
    ports:
      - "8080:8080"
    command: server local
    environment:
      KESTRA_CONFIGURATION_DATASOURCES_POSTGRES_URL: jdbc:postgresql://postgres:5432/kestra_db
      KESTRA_CONFIGURATION_DATASOURCES_POSTGRES_USERNAME: kestra
      KESTRA_CONFIGURATION_DATASOURCES_POSTGRES_PASSWORD: kestra_password
      KESTRA_CONFIGURATION_DATASOURCES_POSTGRES_DRIVERCLASSNAME: org.postgresql.Driver
      KESTRA_CONFIGURATION_REPOSITORY_TYPE: postgres
      KESTRA_CONFIGURATION_QUEUE_TYPE: postgres
      KESTRA_CONFIGURATION_STORAGE_TYPE: s3
      KESTRA_CONFIGURATION_STORAGE_S3_BUCKET: ${data.terraform_remote_state.storage.outputs.processed_s3_bucket_name}
      KESTRA_CONFIGURATION_STORAGE_S3_REGION: ${var.aws_region}
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - /home/ec2-user/kestra/working-directory:/tmp/kestra-working-directory

volumes:
  postgres_data:

EOT

              # Add Dockerfile to extend Kestra image
              cat <<'EOT' > /home/ec2-user/kestra/Dockerfile
# Use the base Kestra dbt image
FROM ghcr.io/kestra-io/dbt:latest

# Switch to root to install the Docker CLI and configure groups
USER root

# Install Docker CLI
RUN apt-get update && apt-get install -y docker.io && rm -rf /var/lib/apt/lists/*

# Remove existing 'docker' group (if it exists) and create a new one with the correct GID
RUN groupdel docker || true && groupadd -g 992 docker && usermod -aG docker kestra

# # Install dbt-athena-community adapter
# RUN pip install dbt-athena-community

# # Install the official dbt-athena adapter
# RUN pip install dbt-athena

# Install the official dbt-athena adapter
RUN pip install git+https://github.com/dbt-athena/dbt-athena.git

# Switch back to the kestra user
USER kestra

# Set the entrypoint to ensure the correct behavior
ENTRYPOINT ["dbt"]

# Install AWS CLI (if required)
RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" && \
    unzip awscliv2.zip && \
    ./aws/install && \
    rm -rf awscliv2.zip aws

# Verify AWS CLI installation
RUN aws --version
EOT

              # Set ownership for the Dockerfile
              chown ec2-user:ec2-user /home/ec2-user/kestra/Dockerfile

              # Build and run Docker Compose
              sudo su - ec2-user -c "cd /home/ec2-user/kestra && docker compose build && docker compose up -d"

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