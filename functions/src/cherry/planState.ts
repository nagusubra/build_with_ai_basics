/** The date card's state on the match (`spec.md > Data Model > matches`). */
export interface DatePlan {
  status: 'none' | 'proposed' | 'confirmed';
  dish?: string;
  dishWhy?: string;
  day?: string;
  time?: string;
  /** Bumped on every new or changed card, so a tap on an outdated card can't confirm. */
  version: number;
  confirmedBy: Record<string, boolean>;
}

export interface PlanDetails {
  dish: string;
  dishWhy?: string;
  day: string;
  time: string;
}

/** Human messages after a "not ready" before Cherry may suggest a date again unprompted. */
export const NOT_READY_COOLDOWN = 6;

export const noPlan = (): DatePlan => ({ status: 'none', version: 0, confirmedBy: {} });

export function readPlan(raw: unknown): DatePlan {
  const p = (raw ?? {}) as Partial<DatePlan>;
  return {
    status: p.status ?? 'none',
    dish: p.dish,
    dishWhy: p.dishWhy,
    day: p.day,
    time: p.time,
    version: p.version ?? 0,
    confirmedBy: p.confirmedBy ?? {},
  };
}

export const planIsComplete = (d: Partial<PlanDetails> | undefined): d is PlanDetails =>
  !!d?.dish?.trim() && !!d?.day?.trim() && !!d?.time?.trim();

/** A new or changed card. Any change clears everyone's confirmation. */
export function proposePlan(previous: DatePlan, details: PlanDetails): DatePlan {
  return {
    status: 'proposed',
    dish: details.dish.trim(),
    dishWhy: details.dishWhy?.trim(),
    day: details.day.trim(),
    time: details.time.trim(),
    version: previous.version + 1,
    confirmedBy: {},
  };
}

export type ConfirmResult =
  | { ok: false; reason: 'not_member' | 'no_plan' | 'outdated_card' | 'already_confirmed' }
  | { ok: true; plan: DatePlan; bothConfirmed: boolean };

/** One person taps Confirm on card `version`. Confirmed only once both members have. */
export function confirmPlan(plan: DatePlan, users: string[], uid: string, version: number): ConfirmResult {
  if (!users.includes(uid)) return { ok: false, reason: 'not_member' };
  if (plan.status === 'confirmed') return { ok: false, reason: 'already_confirmed' };
  if (plan.status !== 'proposed') return { ok: false, reason: 'no_plan' };
  if (plan.version !== version) return { ok: false, reason: 'outdated_card' };
  const confirmedBy = { ...plan.confirmedBy, [uid]: true };
  const bothConfirmed = users.every((u) => confirmedBy[u]);
  return { ok: true, plan: { ...plan, confirmedBy, status: bothConfirmed ? 'confirmed' : 'proposed' }, bothConfirmed };
}

export const asksForDate = (text: string) =>
  /\b(date|plan (something|a|it)|cook (something )?together|let'?s cook|when are you free|free (on|this))\b/i.test(text);

/** Cherry may put a new date card up unless one is confirmed, or someone recently said not yet. */
export function mayProposeDate(
  m: { datePlan?: DatePlan; dateDeclinedAt?: Date | null; humanMessagesSinceDecline?: number },
  latestText: string,
): boolean {
  if (m.datePlan?.status === 'confirmed') return false;
  if (asksForDate(latestText)) return true;
  if (m.dateDeclinedAt && (m.humanMessagesSinceDecline ?? 0) < NOT_READY_COOLDOWN) return false;
  return true;
}
