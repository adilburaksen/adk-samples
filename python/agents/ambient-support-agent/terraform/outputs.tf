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

output "cloud_run_url" {
  description = "URL of the deployed Cloud Run agent service."
  value       = data.google_cloud_run_v2_service.agent.uri
}

output "pubsub_topic" {
  description = "Pub/Sub topic for publishing support tickets."
  value       = google_pubsub_topic.support_tickets.id
}

output "dead_letter_topic" {
  description = "Dead-letter topic for failed ticket processing."
  value       = google_pubsub_topic.dead_letter.id
}

output "trigger_endpoint" {
  description = "Full trigger endpoint URL for Pub/Sub."
  value       = "${data.google_cloud_run_v2_service.agent.uri}/apps/${var.agent_name}/trigger/pubsub"
}

output "alert_policy" {
  description = "Cloud Monitoring alert policy for critical tickets."
  value       = google_monitoring_alert_policy.critical_tickets.display_name
}
