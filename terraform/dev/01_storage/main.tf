    # terraform/dev/01_storage/main.tf

    terraform {
      required_providers {
        aws = {
          source  = "hashicorp/aws"
          version = "~> 5.0"
        }
      }
      required_version = ">= 1.0"
    }