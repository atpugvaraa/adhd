/*
Purpose: Select thoughts eligible for a planned review moment.
Stage: Resurfacing.
Plan:
- Apply the agreed schedule and retry policy.
- Return a small, explainable set rather than an unbounded queue.
- Do not infer urgency from the amount of time a thought has waited.
Learning goal: Keep eligibility decisions independent of notification delivery.
*/
