// The story run as a Cloudflare Workflow (ADR-0002, sad §6 S-03): the app's run id is the
// instance id, and `StoryRunWorkflow` hands each durable `step.do` to `runStoryRun`. Exported
// from `src/index.ts` and bound as `STORY_RUN` in `wrangler.jsonc`.
import { WorkflowEntrypoint, type WorkflowEvent, type WorkflowStep } from "cloudflare:workers";
import type { Env } from "../env";
import { runStoryRun, type StepRunner, type StoryRunParams } from "./run-steps.ts";

export type { StoryRunParams } from "./run-steps.ts";

export class StoryRunWorkflow extends WorkflowEntrypoint<Env, StoryRunParams> {
  async run(event: Readonly<WorkflowEvent<StoryRunParams>>, step: WorkflowStep): Promise<void> {
    const runner: StepRunner = {
      do: (name, config, fn) => step.do(name, config, fn as () => Promise<never>) as Promise<never>,
    };
    await runStoryRun(this.env, runner, event.payload);
  }
}
