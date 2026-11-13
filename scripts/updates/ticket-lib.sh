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
# The two providers differ: ClickUp lists still call it "Ready for Dev", while the
# Productive workflow renamed it "Ready to Start". For Productive, the "status" key of
# productive-ticket-fields.json wins over PRODUCTIVE_DEFAULT_STATUS; this is the fallback
# for when that file is missing or does not set one.
TICKET_DEFAULT_STATUS="Ready for Dev"          # ClickUp
PRODUCTIVE_DEFAULT_STATUS="Ready to Start"     # Productive

ticket_title() {
  if [ "${UPDATE_MODE:-security}" = "composer" ]; then
    printf '%s' "Minor Upgrades For Your Website - ${SITE_NAME}"
  else
    printf '%s' "Security Updates Required For Your Website - ${SITE_NAME}"
  fi
}

# ticket_find_file NAME
#
# Resolve one of the ticket's support files: consumer override, else the vendored copy,
# else the copy beside the calling script (running from a POTS checkout, where there is
# no vendor/). Never only the calling script's directory: a consumer who overrides just
# the ticket script runs it from .circleci/scripts/updates/, where the file does not
# exist. Prints the last candidate when none exists, so the caller's error names a path.
ticket_find_file() {
  local name="$1" candidate
  for candidate in "./.circleci/scripts/updates/${name}" \
                   "./vendor/fourkitchens/pots/scripts/updates/${name}" \
                   "$(dirname "$0")/${name}"; do
    if [ -f "$candidate" ]; then
      printf '%s' "$candidate"
      return
    fi
  done
  printf '%s' "$(dirname "$0")/${name}"
}

# The wording differs between a security run and a minor upgrades run, so the template
# is chosen by UPDATE_MODE (exported by run-update; defaults to security when run by hand).
#
# It can also differ by client engagement (the defaults are written for clients whose
# updates are included in their plan). A project names its own wording with
# "ticket_template" in the update-data blob, falling back to the TICKET_TEMPLATE_VARIANT
# env var -- the same blob-then-env order as ticketing_system. A variant "fwt" reads
# TICKET_TEMPLATE-<mode>-fwt.md, found like any other ticket file. A variant with no file
# for this mode is logged and the default template is used, so it never costs the ticket.
ticket_template() {
  local mode="${UPDATE_MODE:-security}" variant="" file
  if [ -n "${UPDATE_DATA:-}" ] && [ "${UPDATE_DATA}" != "{}" ] \
     && printf '%s' "$UPDATE_DATA" | jq empty >/dev/null 2>&1; then
    variant="$( printf '%s' "$UPDATE_DATA" | jq -r '.ticket_template // empty' )"
  fi
  variant="${variant:-${TICKET_TEMPLATE_VARIANT:-}}"
  if [ -n "$variant" ]; then
    # The variant becomes part of a file name: letters, digits, - and _ only, so it can
    # never point outside the template directories.
    if [[ ! "$variant" =~ ^[A-Za-z0-9_-]+$ ]]; then
      echo "Warning: ticket template variant '${variant}' may only use letters, digits, - and _; using the default template." >&2
    else
      file="$( ticket_find_file "TICKET_TEMPLATE-${mode}-${variant}.md" )"
      if [ -f "$file" ]; then
        printf '%s' "$file"
        return
      fi
      echo "Warning: no TICKET_TEMPLATE-${mode}-${variant}.md for ticket template variant '${variant}'; using the default template." >&2
    fi
  fi
  ticket_find_file "TICKET_TEMPLATE-${mode}.md"
}

# ticket_markdown PROJECTS_UPDATED
#
# The ticket body as Markdown. PROJECTS_UPDATED is run-update's "core, webform, " list.
# UPDATE_FAILURES (env) holds one "- name: reason" line per package the run could not
# update, or "None.". PR_URL and PR_NUMBER (env) are the
# pull request run-update opened for these updates; when set, the body ends with a link
# to it.
ticket_markdown() {
  local projects="$1" body projects_md failures_md="" failures line name reason

  # One bullet per project, instead of a run-on "core, webform," sentence.
  projects_md=$( printf '%s' "$projects" | tr ',' '\n' \
    | sed 's/^[[:space:]]*//; s/[[:space:]]*$//; /^$/d; s/^/- /' )

  # Each failure gets its own bullet, with composer's explanation under it as a code block:
  # it is tool output, and as a sentence it buries the package name in a wall of text. The
  # whole block is dropped when nothing failed, because a client-facing ticket should not
  # carry an empty "problems" heading.
  if [ -n "${UPDATE_FAILURES:-}" ] && [ "${UPDATE_FAILURES}" != "None." ]; then
    # run-update separates the lines with real newlines. An older caller used literal
    # "\n" separators instead; split those on exactly that, never with printf '%b', which
    # also expands any "\c" or "\n" inside a reason and cuts or splits the list there.
    failures="${UPDATE_FAILURES}"
    if [[ "$failures" != *$'\n'* ]]; then
      failures="${failures//\\n/$'\n'}"
    fi
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
    done < <( printf '%s\n' "$failures" )
  fi

  body=$(cat "$(ticket_template)")
  # Quoted replacements: since bash 5.2 (patsub_replacement) an unquoted one turns every
  # "&" in a site name or composer message into the matched placeholder.
  body=${body//\[SITE_NAME\]/"$SITE_NAME"}
  # A template that keeps [PROJECTS] on a line of its own gets the bullet list. One that
  # still has it inline ("required for: [PROJECTS]") -- an older consumer override -- gets
  # the comma-separated list it was written for.
  if printf '%s\n' "$body" | grep -qx '[[:space:]]*\[PROJECTS\][[:space:]]*'; then
    body=${body//\[PROJECTS\]/"$projects_md"}
  else
    body=${body//\[PROJECTS\]/"$( printf '%s' "$projects" | sed 's/,[[:space:]]*$//' )"}
  fi
  body=${body//\[FAILURES\]/"$failures_md"}

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
