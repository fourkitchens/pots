#!/bin/bash

openai_request() {
    # Get the OpenAI API Key.
    OPENAI_API_KEY=$1

    # Get the prompt text.
    API_PROMPT_TEXT="$2"

    # Define the API model.
    API_MODEL="gpt-3.5-turbo"

    # Define the API temperature.
    API_TEMPERATURE=0.7

    # Define the API temperature.
    API_MAX_TOKENS=500

    # Define the endpoint of OpenAI API.
    API_ENDPOINT="https://api.openai.com/v1/chat/completions"

    # Make the request to OpenAI API by curl.
    curl -X POST \
         -H "Content-Type: application/json" \
         -H "Authorization: Bearer $OPENAI_API_KEY" \
         -d "{ \"model\": \"$API_MODEL\", \"messages\": [{\"role\": \"user\", \"content\": \"$API_PROMPT_TEXT\"}], \"temperature\": $API_TEMPERATURE, \"max_tokens\": $API_MAX_TOKENS }" \
         $API_ENDPOINT | \
         python3 -c "import json,sys;obj=json.load(sys.stdin);print(obj['choices'][0]['message']['content']);"
}
