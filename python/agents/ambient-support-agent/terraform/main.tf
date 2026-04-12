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
# Terraform configuration for the Ambient Support Agent infrastructure.
#
# This provisions the GCP resources needed to connect event sources
# (Pub/Sub, Cloud Scheduler) to a Cloud Run-deployed ADK agent with
# trigger endpoints enabled.
#
# Prerequisites:
#   1. Deploy the agent to Cloud Run first (see README.md)
#   2. Then run: terraform apply -var=project_id=YOUR_PROJECT
# ---------------------------------------------------------------------------

terraform {
  required_version = ">= 1.0.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.0.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region

  default_labels = {
    goog-terraform-provisioned = "true"
    app                        = "ambient-support-agent"
  }
}

locals {
  # Enable required GCP APIs.
  required_apis = [
    "run.googleapis.com",
    "pubsub.googleapis.com",
    "cloudscheduler.googleapis.com",
    "monitoring.googleapis.com",
  ]
}

resource "google_project_service" "apis" {
  for_each = toset(local.required_apis)

  project = var.project_id
  service = each.value

  disable_on_destroy = false
}
