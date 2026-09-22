export const MODEL: string
export type Phase = "investigate" | "plan" | "implement" | "review"
export interface Handoff {
  summary: string
  files?: string[]
  plan?: string[]
  verdict?: "pass" | "revise" | "blocked"
}
export interface Assignment {
  requestId: string
  phase: Phase
  workerId: string
}
export interface WorkflowRecord extends Assignment {
  result: Handoff
  interrupted?: boolean
}
export interface Workflow {
  version: 1
  id: string
  revision: number
  goal: string
  context: string
  scope: string[]
  constraints: string[]
  allowWrite: boolean
  maxSteps: number
  status:
    | "ready"
    | "running"
    | "completed"
    | "blocked"
    | "failed"
    | "cancelled"
    | "interrupted"
  active: Assignment | null
  records: WorkflowRecord[]
  decisions: {
    kind: string
    choice: string
    confidence: number
    model: string
    revision: number
  }[]
  usage: { inputTokens: number; outputTokens: number }
  error: string | null
  updatedAt: string
}
export interface WorkerRequest extends Assignment {
  goal: string
  context: string
  constraints: string[]
  scope: string[]
  permission: "read-only" | "write"
  handoffs: WorkflowRecord[]
}
export interface DecisionRequest {
  state: unknown
  instructions: string
  criteria: Record<string, string>
  signal?: AbortSignal
}
export interface Decision {
  choice: string
  confidence: number
  model: string
  inputTokens?: number
  outputTokens?: number
}
export type Decider = (request: DecisionRequest) => Promise<Decision>
export function createWorkflow(input: {
  id?: string
  goal: string
  context?: string
  scope?: string[]
  constraints?: string[]
  allowWrite?: boolean
  maxSteps?: number
}): Workflow
export function restoreWorkflow(value: unknown): Workflow
export function resumeWorkflow(value: unknown): Workflow
export function workerPrompt(request: WorkerRequest): string
export function createJevDecider(input: {
  apiKey: string
  fetchImpl?: typeof fetch
}): Decider
export function runWorkflow(
  state: Workflow,
  host: {
    workers: { id: string; description: string; canWrite: boolean }[]
    decide: Decider
    execute(
      request: WorkerRequest,
      signal: AbortSignal
    ): Promise<string | Handoff>
    checkpoint(state: Workflow): void | Promise<void>
    signal?: AbortSignal
    timeoutMs?: number
  }
): Promise<Workflow>
