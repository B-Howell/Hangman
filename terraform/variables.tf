variable "api-domain-name" {
  default = "hangman-api.brettmhowell.com"
}

variable "alb-domain-name" {
  default = "hangman-alb.brettmhowell.com"
}

variable "region" {
  default = "us-east-1"
}

variable "db_name" {
  default = "Hangman"
}

variable "db_username" {
  default = "root"
}

variable "db_password" {
  default = "Bh_661399!"
}

variable "db_secret_key" {
  default = "p14y-h4ngm4n!"
}

variable "container-name" {
  default = "hangman"
}

variable "container-port" {
  default = 5000
}

variable "container-uri" {
  default = "185666942958.dkr.ecr.us-east-1.amazonaws.com/hangman:v8.7"
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