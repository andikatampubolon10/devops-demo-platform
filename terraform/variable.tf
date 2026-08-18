variable "kubeconfig_path" {
  type        = string
  description = "Path to kubeconfig file"
}

variable "app_image_tag" {
  type        = string
  description = "Tag of the app docker image"
  default     = "3.0"
}

variable "worker_image_tag" {
  type        = string
  description = "Tag of the worker docker image"
  default     = "1.0"
}
