variable "state_bucket" {
  default = "bhcrc-tfstate"
}

variable "state_file" {
  default = "hangman.tfstate"
}

variable "sso_profile" {
  default = "terraform"
}

variable "alb-domain-name" {
  default = "hangman-alb.brettmhowell.com"
}

variable "region" {
  default = "us-east-1"
}

variable "container-name" {
  default = "hangman"
}

variable "container-port" {
  default = 5000
}

variable "tg-name" {
  default = "Hangman-TG"
}

variable "alb-name" {
  default = "Hangman-ALB"
}

variable "execution-role-arn" {
  default = "arn:aws:iam::185666942958:role/ecsTaskExecutionRole"
}

variable "service-name" {
  default = "hangman-service"
}