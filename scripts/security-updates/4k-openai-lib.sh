#!/bin/bash

# Request AI-generated functional testing steps from the OpenAI Chat Completions API.
#
# Usage: openai_request "<api-key>" "<prompt>"
#
# Prints the assistant's message content on stdout (empty string on any error), so a
# failed, rate-limited, or misconfigured request can never abort the caller. The model is
# configurable via the OPENAI_MODEL env var (default: gpt-4o-mini).
openai_request() {
    local api_key="$1"
    local prompt_text="$2"

    local model="${OPENAI_MODEL:-gpt-4o-mini}"
    local endpoint="https://api.openai.com/v1/chat/completions"
    local system_prompt
    system_prompt="You are a senior Drupal QA engineer. A Drupal project has just received a \
security update. Reply with concise, Markdown-formatted functional testing steps as a checklist \
(use '- [ ] ' items). Cover only what a tester should verify after the update; no preamble."

    # Build the request body with jq so the prompt text is always correctly JSON-escaped
    # (quotes/newlines can never break the request).
    local body
    body=$(jq -n \
        --arg model "$model" \
        --arg system "$system_prompt" \
        --arg user "$prompt_text" \
        '{
            model: $model,
            messages: [
                { role: "system", content: $system },
                { role: "user",   content: $user }
            ],
            temperature: 0.7,
            max_completion_tokens: 500
        }')

    # Send the request; on any curl failure, return empty rather than aborting the caller.
    local response
    response=$(curl -sS -X POST "$endpoint" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $api_key" \
        -d "$body") || return 0

    # Extract the message content. If the API returned an error object (no choices), the
    # `// empty` fallback yields an empty string instead of failing.
    echo "$response" | jq -r '.choices[0].message.content // empty' 2>/dev/null || true
}
