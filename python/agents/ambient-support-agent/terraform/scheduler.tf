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
# Cloud Scheduler: run the agent on a cron schedule.
#
# Publishes a message to the support-tickets Pub/Sub topic on each tick,
# which is then pushed to the agent's /trigger/pubsub endpoint via the
# existing push subscription.
#
# This demonstrates how to build scheduled ambient agents — for example,
# periodic reporting, batch processing, or health check workflows.
# ---------------------------------------------------------------------------

resource "google_cloud_scheduler_job" "daily_triage_summary" {
  name     = "support-daily-summary"
  project  = var.project_id
  region   = var.region
  schedule = "0 8 * * *" # Every day at 8:00 AM UTC

  description = "Triggers the support agent daily to generate a triage summary."

  pubsub_target {
    topic_name = google_pubsub_topic.support_tickets.id

    data = base64encode(jsonencode({
      task  = "daily_summary"
      scope = "last_24h"
      instructions = "Generate a summary of all support tickets from the last 24 hours. Group by priority and category. Highlight any P0/P1 tickets that may still be unresolved."
    }))

    attributes = {
      source = "cloud-scheduler"
      job    = "daily-triage-summary"
    }
  }

  depends_on = [google_project_service.apis]
}
