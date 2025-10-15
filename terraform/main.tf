terraform {
  required_version = ">= 1.0"

  cloud {
    organization = "TerraformSynth"

    workspaces {
      name = "forum"
    }
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile != "" ? var.aws_profile : null

  # Removed default_tags to avoid requiring logs:TagResource and servicediscovery:TagResource permissions
}
