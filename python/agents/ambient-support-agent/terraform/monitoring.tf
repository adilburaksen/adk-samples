# Copyright 2026 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# ---------------------------------------------------------------------------
# Cloud Monitoring: log-based metric + alert policy + notification channel
#
# When the agent triages a P0 or P1 ticket it emits a structured JSON log.
# Cloud Logging ingests it, a log-based metric counts it, and an alert
# policy sends an email notification.
# ---------------------------------------------------------------------------

resource "google_logging_metric" "critical_tickets" {
  name    = "support-critical-tickets"
  project = var.project_id

  description = "Counts critical (P0/P1) ticket alerts from the support agent."

  filter = <<-EOT
    resource.type="cloud_run_revision"
    resource.labels.service_name="${var.service_name}"
    jsonPayload.alert_type="critical_ticket"
    jsonPayload.priority=("P0" OR "P1")
  EOT

  metric_descriptor {
    metric_kind = "DELTA"
    value_type  = "INT64"
  }
}

resource "google_monitoring_notification_channel" "email" {
  display_name = "Support Agent - Critical Ticket Alerts"
  project      = var.project_id
  type         = "email"

  labels = {
    email_address = var.notification_email
  }

  depends_on = [google_project_service.apis]
}

resource "google_monitoring_alert_policy" "critical_tickets" {
  display_name = "Support Agent - Critical Ticket (P0/P1)"
  project      = var.project_id
  combiner     = "OR"

  conditions {
    display_name = "Critical ticket count > 0"

    condition_threshold {
      filter          = "metric.type=\"logging.googleapis.com/user/${google_logging_metric.critical_tickets.name}\" AND resource.type=\"cloud_run_revision\""
      comparison      = "COMPARISON_GT"
      threshold_value = 0
      duration        = "0s"

      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_COUNT"
      }
    }
  }

  notification_channels = [
    google_monitoring_notification_channel.email.id
  ]

  alert_strategy {
    auto_close = "1800s"
  }

  documentation {
    content   = "The support agent triaged a P0 or P1 ticket. Check Cloud Logging for details."
    mime_type = "text/markdown"
  }

  depends_on = [google_project_service.apis]
}
