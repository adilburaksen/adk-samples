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

"""Ambient agent that processes incoming support tickets.

This agent receives support ticket events via ADK trigger endpoints
(Pub/Sub) and produces a structured triage analysis including
priority classification, category detection, and recommended next steps.

The agent runs autonomously — it is invoked by events, not by users.
Each event creates an ephemeral session, and the agent processes the
ticket without any human interaction.
"""

import json

from google.adk.agents import LlmAgent


def parse_event(raw_event: str) -> dict:
    """Parse a trigger event and extract the ticket data.

    Trigger endpoints deliver events as a JSON string with 'data' and
    'attributes' fields. This tool extracts those fields so the agent
    can reason about the ticket contents.

    Args:
        raw_event: JSON string from the trigger endpoint containing
            'data' (the ticket payload) and 'attributes' (event metadata).

    Returns:
        A dict with 'ticket' (the parsed ticket data) and 'metadata'
        (event attributes like source, timestamp, etc.).
    """
    event = json.loads(raw_event)
    return {
        "ticket": event.get("data"),
        "metadata": event.get("attributes", {}),
    }


def emit_critical_ticket_alert(
    priority: str,
    category: str,
    customer: str,
    summary: str,
) -> dict:
    """Emit a structured log for critical (P0/P1) tickets.

    Cloud Run captures JSON stdout as structured logs in Cloud Logging.
    A log-based metric and alert policy trigger email notifications
    when these logs appear.

    Call this tool ONLY for P0 or P1 tickets, after completing triage.

    Args:
        priority: The ticket priority — must be "P0" or "P1".
        category: The ticket category (e.g., "technical", "billing").
        customer: The customer name or identifier.
        summary: A one-sentence summary of the issue.

    Returns:
        Confirmation that the alert log was emitted.
    """
    log_entry = {
        "severity": "CRITICAL" if priority == "P0" else "ERROR",
        "message": f"Critical ticket alert: [{priority}] {summary}",
        "alert_type": "critical_ticket",
        "priority": priority,
        "category": category,
        "customer": customer,
        "summary": summary,
    }
    print(json.dumps(log_entry), flush=True)
    return {"status": "alert_emitted", "priority": priority}


root_agent = LlmAgent(
    model="gemini-2.5-flash",
    name="support_agent",
    instruction="""You are an ambient support ticket triage agent. You process
incoming support tickets automatically — no human is in the loop.

When you receive an event:
1. Use the `parse_event` tool to extract the ticket data and metadata.
2. Analyze the ticket and produce a structured triage report.
3. If the ticket is **P0** or **P1**, call the `emit_critical_ticket_alert` tool
   with the priority, category, customer, and summary. This triggers an email
   notification to the on-call team.

Your triage report MUST include:
- **Priority**: P0 (critical outage), P1 (major impact), P2 (moderate), or P3 (minor/question)
- **Category**: One of: billing, technical, account, feature-request, bug-report, general
- **Summary**: A one-sentence summary of the issue
- **Key entities**: Customer name, product, or service mentioned
- **Recommended action**: What team or workflow should handle this next
- **Sentiment**: positive, neutral, negative, or urgent

Be concise and structured. Your output will be consumed by downstream
automation, not read by a human in real time.""",
    tools=[parse_event, emit_critical_ticket_alert],
)
