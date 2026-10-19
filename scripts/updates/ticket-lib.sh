#!/bin/bash
#
# Shared by create-clickup-ticket and create-productive-ticket: the ticket's title, its body
# and the status it opens in, so both providers say the same thing and differ only in how
# they send it. Sourced, not executed.
#
# The body is built once, as Markdown. ClickUp takes that as-is (markdown_content);
# Productive renders its description as HTML, so it goes through ticket_markdown_to_html.

# The status a new ticket opens in when update-data does not name one. Matched by name,
# ignoring case, against the statuses the ClickUp list or the Productive workflow defines.
TICKET_DEFAULT_STATUS="Ready for Dev"

ticket_title() {
  if [ "${UPDATE_MODE:-security}" = "composer" ]; then
    printf '%s' "Maintenance Updates For Your Website - ${SITE_NAME}"
  else
    printf '%s' "Security Updates Required For Your Website - ${SITE_NAME}"
  fi
}

# Resolve the ticket template: consumer override, else the copy beside the calling script.
# The wording differs between a security run and a routine maintenance run, so the template
# is chosen by UPDATE_MODE (exported by run-update; defaults to security when run by hand).
ticket_template() {
  local name="TICKET_TEMPLATE-${UPDATE_MODE:-security}.md"
  if [ -f "./.circleci/scripts/updates/${name}" ]; then
    printf '%s' "./.circleci/scripts/updates/${name}"
  else
    printf '%s' "$(dirname "$0")/${name}"
  fi
}

# ticket_markdown PROJECTS_UPDATED
#
# The ticket body as Markdown. PROJECTS_UPDATED is run-update's "core, webform, " list.
# UPDATE_FAILURES (env) holds one "- name: reason" line per package the run could not
# update, with literal "\n" separators, or "None.". PR_URL and PR_NUMBER (env) are the
# pull request run-update opened for these updates; when set, the body ends with a link
# to it.
ticket_markdown() {
  local projects="$1" body projects_md failures_md="" line name reason

  # One bullet per project, instead of a run-on "core, webform," sentence.
  projects_md=$( printf '%s' "$projects" | tr ',' '\n' \
    | sed 's/^[[:space:]]*//; s/[[:space:]]*$//; /^$/d; s/^/- /' )

  # Each failure gets its own bullet, with composer's explanation under it as a code block:
  # it is tool output, and as a sentence it buries the package name in a wall of text. The
  # whole block is dropped when nothing failed, because a client-facing ticket should not
  # carry an empty "problems" heading.
  if [ -n "${UPDATE_FAILURES:-}" ] && [ "${UPDATE_FAILURES}" != "None." ]; then
    failures_md="Could not be updated automatically and need a look by hand:"$'\n'
    while IFS= read -r line; do
      line="${line#- }"
      [ -z "$line" ] && continue
      name="${line%%: *}"
      reason="${line#*: }"
      [ "$reason" = "$line" ] && reason=""
      failures_md+=$'\n'"- ${name}"$'\n'
      if [ -n "$reason" ]; then
        # A stray fence in composer's output would close the block early.
        reason=$( printf '%s' "$reason" | sed "s/\`\`\`/'''/g" )
        failures_md+=$'\n```\n'"${reason}"$'\n```\n'
      fi
    done < <( printf '%b' "${UPDATE_FAILURES}" )
  fi

  body=$(cat "$(ticket_template)")
  body=${body//\[SITE_NAME\]/$SITE_NAME}
  # A template that keeps [PROJECTS] on a line of its own gets the bullet list. One that
  # still has it inline ("required for: [PROJECTS]") -- an older consumer override -- gets
  # the comma-separated list it was written for.
  if printf '%s\n' "$body" | grep -qx '[[:space:]]*\[PROJECTS\][[:space:]]*'; then
    body=${body//\[PROJECTS\]/$projects_md}
  else
    body=${body//\[PROJECTS\]/$( printf '%s' "$projects" | sed 's/,[[:space:]]*$//' )}
  fi
  body=${body//\[FAILURES\]/$failures_md}

  # Added here rather than in the template, so overridden templates get it too.
  if [ -n "${PR_URL:-}" ]; then
    body+=$'\n\n'"**Pull request ready for internal review**"
    body+=$'\n'"This ticket already has a pull request with these updates, and it is ready for internal review: [Pull request${PR_NUMBER:+ #$PR_NUMBER}](${PR_URL})"
  fi
  printf '%s\n' "$body"
}

# ticket_markdown_to_html < markdown
#
# Just enough Markdown for the ticket body: paragraphs, "- " bullet lists, ``` code
# blocks, **bold** and [links](url). Single newlines inside a paragraph become <br>. A blank line between two blocks
# becomes an empty paragraph, because Productive gives <p> no margin of its own: without it
# every block runs into the next. HTML metacharacters are escaped before any tag is added,
# so a site name or composer message containing & or < cannot break the markup.
ticket_markdown_to_html() {
  sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g' | awk '
    # [text](url) and **text**. Plain POSIX awk (no gensub), since CI runs mawk. Link text
    # stops at "(" or "[", which keeps the pattern free of a "]" inside brackets -- the
    # one bracket form awks disagree on.
    function inline(s,    out, m, t, u) {
      out = ""
      while (match(s, /\[[^([]*\]\([^)]*\)/)) {
        m = substr(s, RSTART, RLENGTH)
        t = m; sub(/\]\(.*$/, "", t); t = substr(t, 2)
        u = m; sub(/^.*\]\(/, "", u); sub(/\)$/, "", u)
        out = out substr(s, 1, RSTART - 1) "<a href=\"" u "\">" t "</a>"
        s = substr(s, RSTART + RLENGTH)
      }
      s = out s
      out = ""
      while (match(s, /\*\*[^*]+\*\*/)) {
        out = out substr(s, 1, RSTART - 1) "<strong>" substr(s, RSTART + 2, RLENGTH - 4) "</strong>"
        s = substr(s, RSTART + RLENGTH)
      }
      return out s
    }
    function close_block() {
      if (block == "p")  out = out "</p>"
      if (block == "ul") out = out "</ul>"
      if (block != "") gap = 1
      block = ""
    }
    function open_block(tag) {
      if (gap && out != "") out = out "<p><br></p>"
      gap = 0
      block = tag
      out = out "<" tag ">"
    }
    /^[ \t]*```/ {
      if (block == "pre") { out = out "</code></pre>"; block = ""; gap = 1; next }
      close_block(); open_block("pre"); out = out "<code>"; first = 1; next
    }
    block == "pre" { out = out (first ? "" : "\n") $0; first = 0; next }
    /^[ \t]*$/ { close_block(); next }
    /^- / {
      if (block != "ul") { close_block(); open_block("ul") }
      out = out "<li>" inline(substr($0, 3)) "</li>"
      next
    }
    {
      if (block == "p") { out = out "<br>" inline($0); next }
      close_block(); open_block("p"); out = out inline($0)
    }
    END {
      if (block == "pre") out = out "</code></pre>"
      else close_block()
      printf "%s", out
    }'
}
