// The offered AI list (ADR-0004): which AIs may be chosen for each step of a story run,
// their list prices and the step pricing rule. Pure, so it runs anywhere. The Worker
// refuses a run or step with an id that is not offered for the step's role (AC-13); the
// app shows the prices and estimates from this list (AC-12).

import list from "./models.json" with { type: "json" };

export type Provider = "anthropic" | "opencode-zen" | "xai" | "higgsfield";
export type Role = "text" | "picture";

interface ModelBase {
  id: string;
  name: string;
  provider: Provider;
  /** Set on entries whose id or price the owner has not verified yet. */
  provisional?: boolean;
}

export interface TextModel extends ModelBase {
  role: "text";
  inputUsdPerMTok: number;
  outputUsdPerMTok: number;
  /** List-price cost of one text step for a group of 15 words (AC-12's "≈ $X (estimate)"),
   *  assuming about 1,000 input and 600 output tokens. */
  estimate15Usd: number;
}

export interface PictureModel extends ModelBase {
  role: "picture";
  usdPerPicture: number;
  /** True when the price per picture is itself approximate (Higgsfield: plan price / credits). */
  approx?: boolean;
}

export type OfferedModel = TextModel | PictureModel;

export interface Defaults {
  story: string;
  prompt: string;
  picture: string;
}

export interface Price {
  usd: number;
  /** True for a "≈" price: a timeout estimate, or a price per picture that is approximate. */
  estimated: boolean;
}

export interface Usage {
  modelId: string;
  /** Tokens the provider reported (text steps). */
  inputTokens?: number;
  outputTokens?: number;
}

/** The fixed AI that splits a session's words into groups; not choosable (spec AC-01). */
export const GROUPING_MODEL = "claude-haiku-4-5-20251001";

export const pricesAsOf: string = list.pricesAsOf;
export const defaults: Defaults = list.defaults;
export const offeredModels: readonly OfferedModel[] = list.models as OfferedModel[];

function find(id: string): OfferedModel | undefined {
  return offeredModels.find((model) => model.id === id);
}

/** Is this id offered for the role? A text id asked for as a picture (or the reverse) is not. */
export function isOffered(role: Role, id: string): boolean {
  return find(id)?.role === role;
}

function requireModel(id: string): OfferedModel {
  const model = find(id);
  if (!model) throw new Error(`model not on the offered list: ${id}`);
  return model;
}

/** A step's price: reported tokens x list price, or the price per picture. */
export function priceOf(usage: Usage): Price {
  const model = requireModel(usage.modelId);
  if (model.role === "picture") return { usd: model.usdPerPicture, estimated: model.approx === true };
  const usd =
    ((usage.inputTokens ?? 0) * model.inputUsdPerMTok + (usage.outputTokens ?? 0) * model.outputUsdPerMTok) /
    1_000_000;
  return { usd, estimated: false };
}

/**
 * A timed-out step reports no usage, so it is priced from what was sent: the input tokens
 * plus the step's output limit x the list price, or the price per picture. Always "≈".
 */
export function estimateOnTimeout(modelId: string, inputTokens: number, outputLimit: number): Price {
  const { usd } = priceOf({ modelId, inputTokens, outputTokens: outputLimit });
  return { usd, estimated: true };
}
