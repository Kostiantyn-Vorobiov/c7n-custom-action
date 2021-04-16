variable "slack_channel" {
  type        = string
  description = "Slack Channel Name used to send notification about policy events (don't use a '#' preffix)"
  default     = "testing-integrations"
}

variable "slack_webhook" {
  type        = string
  description = "Slack Webhook Endpoint used to send policy events"
  default     = ""
}

variable "tags" {
  type        = map
  description = "AWS Tags to add to every created resource"  
  default = {}
}
