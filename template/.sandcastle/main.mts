import { run, claudeCode } from "@ai-hero/sandcastle";
import { docker } from "@ai-hero/sandcastle/sandboxes/docker";
import { execSync } from "node:child_process";

interface Issue {
  number: number;
  title: string;
}

const issues = JSON.parse(
  execSync(
    "gh issue list --label ready-for-agent --state open --json number,title"
  ).toString()
) as Issue[];

if (issues.length === 0) {
  console.log("No issues labelled ready-for-agent. Nothing to do.");
  process.exit(0);
}

for (const issue of issues) {
  console.log(`\nProcessing issue #${issue.number}: ${issue.title}`);

  await run({
    agent: claudeCode("claude-opus-4-6"),
    sandbox: docker(),
    promptFile: ".sandcastle/prompt.md",
    promptArgs: { ISSUE_NUMBER: String(issue.number) },
    branchStrategy: {
      type: "branch",
      branch: `agent/issue-${issue.number}`,
    },
    logging: { type: "stdout" },
  });
}
