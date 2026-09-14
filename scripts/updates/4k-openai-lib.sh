#!/bin/bash

# Request AI-generated functional testing steps from an OpenAI-compatible Chat Completions
# API.
#
# Usage: openai_request "<api-key>" "<prompt>"
#
# Prints the assistant's message content on stdout (empty string on any error), so a
# failed, rate-limited, or misconfigured request can never abort the caller.
#
# Any provider that speaks the OpenAI Chat Completions protocol works; only the base URL,
# the model and the key change. That includes the free tiers of Groq, OpenRouter, Cerebras
# and Google Gemini. See the README for the exact values.
#
#   OPENAI_API_BASE   API root. Default: https://api.openai.com/v1
#   OPENAI_MODEL      Model id. Default: gpt-4o-mini
#   OPENAI_TIMEOUT    Per-request timeout in seconds. Default: 45
openai_request() {
    local api_key="$1"
    local prompt_text="$2"

    local model="${OPENAI_MODEL:-gpt-4o-mini}"
    local api_base="${OPENAI_API_BASE:-https://api.openai.com/v1}"
    local endpoint="${api_base%/}/chat/completions"
    local timeout="${OPENAI_TIMEOUT:-45}"
    local system_prompt
    system_prompt="You are a senior Drupal QA engineer. A Drupal project has just received a \
security update. Reply with concise, Markdown-formatted functional testing steps as a checklist \
(use '- [ ] ' items). Cover only what a tester should verify after the update; no preamble."

    # Build the request body with jq so the prompt text is always correctly JSON-escaped
    # (quotes/newlines can never break the request). The token-limit field is a parameter:
    # OpenAI's newer models require max_completion_tokens, while most compatible providers
    # only accept max_tokens, so we try one and fall back to the other.
    _openai_body() {
        jq -n \
            --arg model "$model" \
            --arg system "$system_prompt" \
            --arg user "$prompt_text" \
            --arg token_field "$1" \
            '{
                model: $model,
                messages: [
                    { role: "system", content: $system },
                    { role: "user",   content: $user }
                ],
                temperature: 0.7
            } + { ($token_field): 500 }'
    }

    # Send the request; on any curl failure, return empty rather than aborting the caller.
    # The HTTP status is appended to the body so failures can be reported instead of being
    # swallowed silently.
    _openai_call() {
        curl -sS -X POST "$endpoint" \
            --max-time "$timeout" \
            --retry 2 --retry-connrefused \
            -w '%{http_code}' \
            -H "Content-Type: application/json" \
            -H "Authorization: Bearer $api_key" \
            -d "$(_openai_body "$1")" 2>/dev/null || true
    }

    local response http_status body
    response="$(_openai_call max_completion_tokens)"
    http_status="${response: -3}"
    body="${response%???}"

    # Providers that do not know max_completion_tokens reject the request outright; retry
    # once with the older field name before giving up.
    if [ "$http_status" = "400" ]; then
        response="$(_openai_call max_tokens)"
        http_status="${response: -3}"
        body="${response%???}"
    fi

    if [ "$http_status" != "200" ]; then
        echo "[autosec:ai] ${endpoint} returned HTTP ${http_status:-no response}; skipping the AI testing steps." >&2
        if [ -n "$body" ]; then
            echo "[autosec:ai] $(echo "$body" | jq -r '.error.message // empty' 2>/dev/null || true)" >&2
        fi
        return 0
    fi

    # Extract the message content. If the API returned an error object (no choices), the
    # `// empty` fallback yields an empty string instead of failing.
    echo "$body" | jq -r '.choices[0].message.content // empty' 2>/dev/null || true
}
