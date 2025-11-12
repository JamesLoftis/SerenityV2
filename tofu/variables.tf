variable "sheet_id" {
  description = "Google Sheet ID (Tiller sheet)."
  type        = string
}

variable "gdrive_sa_email" {
  description = "Service account email for Google Sheets plugin."
  type        = string
  default     = ""
}

variable "gdrive_sa_private_key" {
  description = "Service account private key (with \\n escapes) for Google Sheets plugin."
  type        = string
  default     = ""
  sensitive   = true
}
