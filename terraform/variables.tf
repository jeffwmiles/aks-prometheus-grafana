variable "adminGroupObjectIds" {
  type        = list(string)
  description = "A list of Object IDs of Azure Active Directory Groups which should have Admin Role on the Cluster"
  default     = []
}

variable "artifactAPIToken" {
  type        = string
  description = "String containing API token for private artifact registry"
}
