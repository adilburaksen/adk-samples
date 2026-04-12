# Ambient Support Agent

An **ambient agent** that processes incoming support tickets autonomously —
no human in the loop. Tickets arrive via Pub/Sub in real time or on a cron
schedule via Cloud Scheduler, and the agent automatically triages each one:
classifying priority, detecting category, extracting key entities, and
recommending next steps.

This sample demonstrates ADK's [trigger endpoints](https://adk.dev/runtime/ambient-agents/)
for building event-driven agents on Google Cloud.

## Getting Started

**Prerequisites:** **[Python 3.10+](https://www.python.org/downloads/)**, **[uv](https://github.com/astral-sh/uv)**

You have two options to get started. Choose the one that best fits your setup:

*   A. **[Google AI Studio (Recommended)](#a-google-ai-studio-recommended)**: The quickest way to get started using a **Google AI Studio API key**. This method involves cloning the sample repository.
*   B. **[Google Cloud Vertex AI](#b-google-cloud-vertex-ai)**: Choose this path if you want to use an existing **Google Cloud project** for authentication and deployment.

---

### A. Google AI Studio (Recommended)

You'll need a **[Google AI Studio API Key](https://aistudio.google.com/app/apikey)**.

#### Step 1: Clone Repository

Clone the repository and `cd` into the project directory.

```bash
git clone https://github.com/google/adk-samples.git
cd adk-samples/python/agents/ambient-support-agent
```

#### Step 2: Set Environment Variables

Create a `.env` file with your API key (see `.env.example` for reference):

```bash
echo "GOOGLE_API_KEY=YOUR_AI_STUDIO_API_KEY" >> .env
```

#### Step 3: Install & Run

From the `ambient-support-agent` directory, install dependencies and start the server with triggers enabled:

```bash
make install && make dev
```

In a separate terminal, send a test ticket:

```bash
curl -X POST http://localhost:8000/apps/support_agent/trigger/pubsub \
  -H "Content-Type: application/json" \
  -d '{
    "message": {
      "data": "eyJzdWJqZWN0IjogIkNhbm5vdCBsb2dpbiIsICJib2R5IjogIjUwMCBlcnJvciBmb3IgMiBob3VycywgYmxvY2tpbmcgbXkgdGVhbSIsICJjdXN0b21lciI6ICJBbGljZSJ9",
      "attributes": {"source": "web-portal"}
    },
    "subscription": "projects/test/subscriptions/test-sub"
  }'
```

You should see `{"status":"success"}`. Check the server logs to confirm the
agent called the model and processed the ticket:

```
Pub/Sub trigger: subscription=projects/test/subscriptions/test-sub
Sending out request, model: gemini-2.5-flash ...
Response received from the model.
"POST /apps/support_agent/trigger/pubsub HTTP/1.1" 200 OK
```

To see the full triage report interactively, use the ADK playground:

```bash
make playground
# Open http://localhost:8501 and paste a ticket JSON as a chat message
```

---

### B. Google Cloud Vertex AI

<details>
<summary>Using the cloned repository with Vertex AI</summary>

If you've already cloned the repository (as in Option A) and want to use
Vertex AI instead of AI Studio, create a `.env` file with:

```bash
echo "GOOGLE_GENAI_USE_VERTEXAI=TRUE" >> .env
echo "GOOGLE_CLOUD_PROJECT=YOUR_PROJECT_ID" >> .env
echo "GOOGLE_CLOUD_LOCATION=us-central1" >> .env
```

Make sure you're authenticated with Google Cloud:

```bash
gcloud auth application-default login
```

Then run `make install && make dev` to start the server.
</details>

## Cloud Deployment

Deploy the agent to Cloud Run with Pub/Sub and Cloud Scheduler infrastructure.

**Prerequisites:** **[Google Cloud SDK](https://cloud.google.com/sdk/docs/install)**, **[Terraform](https://www.terraform.io/)**

```bash
gcloud config set project YOUR_PROJECT_ID
```

#### Step 1: Deploy to Cloud Run

```bash
make deploy
```

#### Step 2: Setup infrastructure (Pub/Sub, Scheduler, IAM)

```bash
make infra NOTIFICATION_EMAIL=oncall@example.com
```

This creates:

| Resource | Purpose |
| --- | --- |
| `support-tickets` topic | Receives support ticket messages |
| `support-tickets-dead-letter` topic | Catches messages that fail after 5 attempts |
| `support-tickets-push` subscription | Authenticated push to `/trigger/pubsub` |
| `support-daily-summary` scheduler job | Daily cron at 8:00 AM UTC |
| `support-agent-invoker` SA | Least-privilege service account |
| `support-critical-tickets` log metric | Counts P0/P1 alert logs from the agent |
| `Critical Ticket (P0/P1)` alert policy | Emails on-call when a critical ticket arrives |

#### Step 3: Test

```bash
make test
```

This publishes a test ticket via Pub/Sub. Check Cloud Logging for `200 OK`
entries confirming the agent processed the message.

You can also fire the daily summary manually:

```bash
gcloud scheduler jobs run support-daily-summary \
  --location=us-central1 \
  --project=$(gcloud config get-value project)
```

#### Cleanup

```bash
make clean NOTIFICATION_EMAIL=oncall@example.com
```

## Agent Details

| Attribute | Description |
| :--- | :--- |
| **Interaction Type** | Ambient (event-driven) |
| **Complexity** | Easy |
| **Agent Type** | Single Agent |
| **Components** | Tools: `parse_event`, `emit_critical_ticket_alert` |
| **Trigger Sources** | Pub/Sub push, Cloud Scheduler (cron) |
| **Infrastructure** | Terraform (Cloud Run, Pub/Sub, Cloud Scheduler, Cloud Monitoring, IAM) |

## How the Agent Works

```
┌──────────────┐
│ Cloud        │─── cron tick ──► Pub/Sub ──┐
│ Scheduler    │                            │
└──────────────┘                            │
                  ┌──────────────┐          │
                  │  Your app /  │─ ticket ─┤
                  │  service     │          │
                  └──────────────┘          ▼
                                  ┌──────────────────┐
                                  │   Cloud Run      │
                                  │   ADK Agent      │──► Triage Report
                                  │   /trigger/pubsub│
                                  └────────┬─────────┘
                                           │ P0/P1
                                           ▼
                                  ┌──────────────────┐
                                  │  Cloud Logging   │
                                  │  (structured log)│
                                  └────────┬─────────┘
                                           │
                                           ▼
                                  ┌──────────────────┐
                                  │ Cloud Monitoring │──► Email Alert
                                  │  (alert policy)  │
                                  └──────────────────┘
```

**Two triggering paths, one endpoint:**

1. **Real-time** — Any system publishes a support ticket to the `support-tickets`
   Pub/Sub topic. The push subscription delivers it to `/trigger/pubsub`.

2. **Scheduled** — Cloud Scheduler publishes to the **same** topic on a cron
   schedule. No extra code or endpoints needed.

The agent receives the event, uses the `parse_event` tool to extract the
ticket data, then produces a structured triage report with priority (P0-P3),
category, summary, key entities, recommended action, and sentiment.

**Critical ticket alerting:**

When the agent classifies a ticket as P0 or P1, it calls the
`emit_critical_ticket_alert` tool, which emits a structured JSON log.
Cloud Monitoring watches for these logs via a log-based metric and fires
an alert policy that sends an email notification. No additional services
or infrastructure are needed — Cloud Run's built-in structured logging
feeds directly into Cloud Monitoring.

## Customization

| What to change | How |
| --- | --- |
| **Ticket schema** | Edit the agent instructions in `support_agent/agent.py` |
| **Downstream actions** | Add tools for your tracker, Slack, or database |
| **Multi-agent triage** | Replace the single agent with a `SequentialAgent` |
| **Schedule** | Edit `schedule` in `terraform/scheduler.tf` |
| **Concurrency** | Set `ADK_TRIGGER_MAX_CONCURRENT` env var |
| **Notification channel** | Replace email with Slack, PagerDuty, or SMS in `terraform/monitoring.tf` ([docs](https://cloud.google.com/monitoring/support/notification-options)) |

## Technologies Used

| Component | Technology |
| --- | --- |
| **Agent framework** | [ADK](https://github.com/google/adk-python) |
| **LLM** | [Gemini](https://ai.google.dev/) |
| **Server** | [FastAPI](https://fastapi.tiangolo.com/) via ADK |
| **Triggers** | [Cloud Pub/Sub](https://cloud.google.com/pubsub), [Cloud Scheduler](https://cloud.google.com/scheduler) |
| **Alerting** | [Cloud Monitoring](https://cloud.google.com/monitoring) |
| **Deployment** | [Cloud Run](https://cloud.google.com/run) |
| **Infrastructure** | [Terraform](https://www.terraform.io/) |

## Troubleshooting

- For general ADK issues, see the [ADK documentation](https://adk.dev).
- For trigger endpoint details, see [Ambient Agents](https://adk.dev/runtime/ambient-agents/).
- For Cloud Run deployment, see [Deploy to Cloud Run](https://adk.dev/deploy/cloud-run/).

## Disclaimer

This agent sample is provided for illustrative purposes only. It serves as a basic example of an agent and a foundational starting point for individuals or teams to develop their own agents.

Users are solely responsible for any further development, testing, security hardening, and deployment of agents based on this sample. We recommend thorough review, testing, and the implementation of appropriate safeguards before using any derived agent in a live or critical system.
