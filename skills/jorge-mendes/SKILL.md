---
name: jorge-mendes
description: Debug Atlassian tickets by fetching issue details, checking organization in the database, and analyzing the codebase for root cause. Use when the user says "Jorge Mendes" followed by a Jira URL, provides an Atlassian/Jira URL, or asks to debug a ticket.
---

# Jorge Mendes - Atlassian Ticket Debugger

> **Recommended Model**: This skill works best with Claude Opus 4.5 for complex root cause analysis. Please ensure you have Opus 4.5 selected in your Cursor chat before running.

## Prerequisites Check

**CRITICAL**: Before proceeding, perform these checks:

### 1. Verify MCP Servers Availability

1. **Atlassian MCP** (`user-Atlassian`) - **REQUIRED**
   - If not available, **STOP IMMEDIATELY** and inform the user:
     > "The Atlassian MCP server is not available. Please ensure it's configured and try again."

2. **Metabase MCP** (`user-metabase`) - Recommended but not blocking
   - If not available, warn the user but continue with codebase analysis:
     > "The Metabase MCP server is not available. Database checks will be skipped."

### 2. Discover Metabase Database ID

If Metabase MCP is available, call `list_databases` to find the correct production database:

```
Tool: CallMcpTool
Server: user-metabase
Tool Name: list_databases
Arguments: {}
```

From the results, identify the main application database (typically the PostgreSQL database). **Store the `database_id`** — you will need it for all subsequent `execute_query` calls.

If multiple databases are returned, prefer the one whose name clearly matches the production/staging environment (e.g., contains "sona" or "production").

## When to Ask Questions

**IMPORTANT**: Before proceeding with the investigation, evaluate if you have enough information. Ask clarifying questions when:

### Required Information Missing

1. **No Atlassian URL provided**:
   - Ask: "Please provide the Atlassian/Jira ticket URL you'd like me to investigate."

2. **Ambiguous URL** (multiple issue keys visible):
   - Ask: "I found multiple issue keys in the URL. Which one should I investigate: PROJ-123 or PROJ-456?"

3. **URL format unrecognizable**:
   - Ask: "I couldn't parse the issue key from this URL. Could you provide the direct ticket URL (e.g., https://site.atlassian.net/browse/PROJ-123)?"

### Optional Context That Would Help

4. **Multiple databases available** (after listing databases):
   - If more than one database is returned and none clearly matches production:
   - Ask: "I found multiple databases: [list names]. Which one should I query for organisation data?"

5. **Vague issue description** (after fetching ticket):
   - If the Jira description is very short or lacks technical details:
   - Ask: "The ticket description is quite brief. Do you have any additional context about: [specific missing details like error messages, affected features, reproduction steps]?"

6. **Multiple potential root causes** (during analysis):
   - If the codebase analysis reveals several equally likely causes:
   - Ask: "I found multiple potential causes: [list them]. Do you have any preference on which area to investigate first, or should I analyze all of them?"

7. **Organisation identifier unclear** (after fetching ticket):
   - If organisation info is mentioned but ambiguous (e.g., "customer X" without ID):
   - Ask: "The ticket mentions '[organisation reference]' but I couldn't find a clear organisation ID or slug. Do you know the organisation identifier I should search for?"

### When NOT to Ask Questions

- **Don't ask** if you can reasonably infer the answer from context
- **Don't ask** if the information is optional and you can proceed without it
- **Don't ask** multiple questions at once — ask the most critical one first
- **Don't ask** if you've already started the investigation and can complete it with what you have

## Workflow

### Step 1: Parse the Atlassian URL

Extract the issue key from the provided URL. Common formats:
- `https://<site>.atlassian.net/browse/PROJ-123`
- `https://<site>.atlassian.net/jira/software/projects/PROJ/boards/1?selectedIssue=PROJ-123`

Extract:
- **Site URL**: The `<site>.atlassian.net` portion (used as cloudId)
- **Issue Key**: The `PROJ-123` portion

**If URL is missing or unparseable**: Stop and ask for clarification (see "When to Ask Questions" section).

### Step 2: Get Atlassian Cloud ID

Call the Atlassian MCP to get the cloud ID:

```
Tool: CallMcpTool
Server: user-Atlassian
Tool Name: getAccessibleAtlassianResources
Arguments: {}
```

Use the returned `cloudId` for subsequent calls.

### Step 3: Fetch Issue Details

```
Tool: CallMcpTool
Server: user-Atlassian
Tool Name: getJiraIssue
Arguments: {
  "cloudId": "<cloudId from step 2>",
  "issueIdOrKey": "<issue key from step 1>",
  "expand": "changelog,comments"
}
```

From the response, extract:
- **Summary**: Issue title
- **Description**: Full issue description
- **Reporter**: Who reported it
- **Comments**: Any additional context from comments
- **Organisation ID/Name**: Look for organisation identifiers in the description or custom fields

### Step 4: Check Organisation in Database

If an organisation identifier was found and Metabase MCP is available, query the database using the `database_id` discovered in the prerequisites:

**IMPORTANT**: The `organisations` table is the **only table** in the database that uses `organisation_id` as its primary key instead of `id`. All other tables use `id`.

**CRITICAL - Always Check Table Metadata First**:
Before querying ANY table for the first time, you MUST:
1. Get the table metadata to understand available columns
2. Review column names and types
3. Only select columns that exist in the metadata

Example metadata check workflow:

First, find the table ID:
```
Tool: CallMcpTool
Server: user-metabase
Tool Name: list_tables
Arguments: { "database_id": <database_id> }
```

Then get the metadata for the specific table (e.g., organisations):
```
Tool: CallMcpTool
Server: user-metabase
Tool Name: get_table_metadata
Arguments: { "table_id": <table_id_from_list> }
```

Review the returned columns and their types before constructing your query.

**CRITICAL - Always Show SQL Before Execution**:
Before executing ANY Metabase query, you MUST:
1. Display the raw SQL query in a markdown code block
2. Explain what the query is checking for
3. Only then execute the query using the Metabase MCP

Example query workflow:

First, show the query:
```sql
SELECT organisation_id, name
FROM organisations 
WHERE organisation_id = '<org_id>'
LIMIT 1
```

Then explain: "Checking if organisation `<identifier>` exists in the database..."

Then execute:
```
Tool: CallMcpTool
Server: user-metabase
Tool Name: execute_query
Arguments: {
  "sql": "SELECT organisation_id, name FROM organisations WHERE organisation_id = '<org_id>' LIMIT 1",
  "database_id": <database_id from prerequisites>
}
```

**Tips for Metabase queries**:
- **ALWAYS check table metadata BEFORE querying** to avoid selecting non-existent columns
- Always include a `LIMIT` clause to avoid returning too much data
- Queries are read-only — mutations are not possible through Metabase
- Only select columns that exist in the table metadata
- Avoid columns that may cause issues (check metadata for column types)
- **ALWAYS show the SQL query in a markdown code block BEFORE executing it**

**If organisation identifier is ambiguous**: Ask the user for clarification (see "When to Ask Questions" section).

**If organisation query FAILS**: 
1. Inform the user about the failure with the error message
2. **ASK for confirmation** before proceeding:
   > "The organisation query failed with error: `<error message>`. Would you like me to continue with the codebase analysis anyway?"
3. Wait for user response before proceeding to Step 5
4. If user confirms, continue with codebase analysis
5. If user declines, stop and ask for guidance

**If organisation NOT found**: Inform the user but continue with codebase analysis:
> "Organisation `<identifier>` was not found in the database."

**If Metabase MCP unavailable**: Skip this step and note it in the final report.

### Step 5: Analyze the Codebase

Based on the issue details:

1. **Identify keywords** from the issue description:
   - Error messages
   - Feature names
   - Module/component names
   - Stack traces

2. **Search the codebase** using appropriate tools:
   - Use `Grep` for specific error messages or function names
   - Use `SemanticSearch` for conceptual searches (e.g., "how does X feature work")
   - Use `Read` to examine relevant files

3. **Trace the code path**:
   - Find entry points related to the issue
   - Follow the execution flow
   - Identify potential root causes

4. **Use Metabase MCP during investigation** (if available and helpful):
   - Query database to verify data states mentioned in the issue
   - Check for related records (users, configurations, logs, etc.)
   - Validate assumptions about data relationships
   - **ALWAYS check table metadata before querying new tables**
   - **ALWAYS show the SQL query in a markdown code block BEFORE executing it**
   
   Example investigation query workflow:
   
   First, check what tables are available:
   ```
   Tool: CallMcpTool
   Server: user-metabase
   Tool Name: list_tables
   Arguments: { "database_id": <database_id> }
   ```
   
   Then get metadata for the table you want to query:
   ```
   Tool: CallMcpTool
   Server: user-metabase
   Tool Name: get_table_metadata
   Arguments: { "table_id": <table_id> }
   ```
   
   Then show your query:
   ```sql
   SELECT id, status, created_at
   FROM users
   WHERE organisation_id = '<org_id>'
   LIMIT 10
   ```
   
   Explain: "Checking recent users for this organisation to verify account states..."
   
   Then execute:
   ```
   Tool: CallMcpTool
   Server: user-metabase
   Tool Name: execute_query
   Arguments: {
     "sql": "SELECT id, status, created_at FROM users WHERE organisation_id = '<org_id>' LIMIT 10",
     "database_id": <database_id>
   }
   ```

**If issue description is too vague**: Consider asking for additional context (see "When to Ask Questions" section).

**If multiple potential root causes found**: Evaluate if you should ask which area to prioritize (see "When to Ask Questions" section).

### Step 6: Generate the Report

Create a new markdown file with the investigation results:

**File location**: `./debug-reports/<issue-key>-<timestamp>.md`

**Report template**:

```markdown
# Debug Report: [ISSUE-KEY]

**Generated**: [timestamp]
**Ticket URL**: [original URL]

## Issue Summary

[Summary from Jira]

## Issue Description

[Description from Jira]

## Organisation Check

- **Organisation ID/Name**: [if found in ticket]
- **Found in Database**: [Yes/No/Skipped]
- **Organisation Details**: [if found]

### SQL Queries Executed

[Document ALL Metabase queries executed during the investigation:]

#### Organisation Lookup

```sql
[SQL query for organisation check]
```

**Result**: [Brief summary of results]

#### Additional Investigation Queries

[If additional queries were run during codebase analysis, document them here:]

```sql
[SQL query 1]
```

**Result**: [Brief summary of results]

```sql
[SQL query 2]
```

**Result**: [Brief summary of results]

## Root Cause Analysis

### Keywords Identified
- [keyword 1]
- [keyword 2]

### Relevant Code Locations

[List of files and functions that are relevant to this issue]

### Findings

[Detailed analysis of what was found in the codebase]

### Suspected Root Cause

[Your assessment of what's causing the issue]

## Recommendations

1. [Recommendation 1]
2. [Recommendation 2]

## Additional Notes

[Any other relevant observations]
```

## Error Handling

- **Atlassian MCP unavailable**: Stop immediately and inform user
- **Invalid URL format**: Ask user to provide a valid Jira URL (see "When to Ask Questions")
- **Issue not found**: Report the error and stop
- **Metabase MCP unavailable**: Continue but note in report
- **Metabase database not found**: Warn user, list available databases, and ask for guidance (see "When to Ask Questions")
- **Organisation not found**: Continue but note in report
- **Organisation identifier ambiguous**: Ask user for clarification (see "When to Ask Questions")
- **Organisation query fails**: Ask user if they want to continue with codebase analysis (see Step 4)
- **Vague issue description**: Consider asking for additional context (see "When to Ask Questions")

## Usage Examples

Any of these will trigger the skill:

- `Jorge Mendes: https://mycompany.atlassian.net/browse/PROJ-123`
- `Jorge Mendes https://mycompany.atlassian.net/browse/PROJ-123`
- `Debug this ticket: https://mycompany.atlassian.net/browse/PROJ-123`

The skill will:
1. **Verify MCP servers** → Check Atlassian and Metabase MCP availability
2. **Discover database** → List Metabase databases and identify the correct one
3. Parse URL → Extract `PROJ-123`
4. Fetch issue from Atlassian
5. Check organisation in database via Metabase (if identifier found)
6. Analyze codebase for root cause
7. Generate report at `./debug-reports/PROJ-123-20240215-143022.md`
