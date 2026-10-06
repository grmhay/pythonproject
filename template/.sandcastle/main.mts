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

// Issue numbers may be passed as arguments to run a subset in a chosen order:
// `npm run sandcastle -- 9 5`. Sequencing matters when two issues touch the
// same code, since every agent branches off main and cannot see the others.
const requested = process.argv.slice(2).map(Number);

const unknown = requested.filter((n) => !issues.some((i) => i.number === n));
if (unknown.length > 0) {
  console.error(
    `Not open with label ready-for-agent: ${unknown.map((n) => `#${n}`).join(", ")}`
  );
  process.exit(1);
}

const queue =
  requested.length > 0
    ? requested.map((n) => issues.find((i) => i.number === n)!)
    : issues;

console.log(`Queued: ${queue.map((i) => `#${i.number}`).join(", ")}`);

for (const issue of queue) {
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
