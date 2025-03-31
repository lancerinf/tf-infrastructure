terraform {
  required_version = "~> 1.11.3"

  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "5.93.0"
    }
  }

  backend "s3" {
    bucket = "tf-infrastructure-fede-dev-389210"
    key = "accounts/fede-dev/backup-util.tfstate"
    region = "eu-north-1"
    use_lockfile = true
  }
}

provider "aws" {
  region = "eu-north-1"
}
