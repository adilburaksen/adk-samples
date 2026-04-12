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
# IAM: Dedicated service account with least-privilege permissions.
# ---------------------------------------------------------------------------

# Service account for Pub/Sub push to invoke Cloud Run.
resource "google_service_account" "pubsub_invoker" {
  account_id   = "support-agent-invoker"
  display_name = "Ambient Support Agent - Pub/Sub Invoker"
  project      = var.project_id
}

# Grant the invoker permission to call the Cloud Run service.
resource "google_cloud_run_v2_service_iam_member" "pubsub_invoker" {
  name     = data.google_cloud_run_v2_service.agent.name
  location = var.region
  project  = var.project_id
  role     = "roles/run.invoker"
  member   = "serviceAccount:${google_service_account.pubsub_invoker.email}"
}

# Allow the GCP-managed Pub/Sub service agent to create OIDC tokens
# for authenticated push delivery.
data "google_project" "project" {
  project_id = var.project_id
}

resource "google_service_account_iam_member" "pubsub_token_creator" {
  service_account_id = google_service_account.pubsub_invoker.name
  role               = "roles/iam.serviceAccountTokenCreator"
  member             = "serviceAccount:service-${data.google_project.project.number}@gcp-sa-pubsub.iam.gserviceaccount.com"
}
