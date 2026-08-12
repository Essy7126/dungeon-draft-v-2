export interface RngStep {
  state: number;
  value: number;
}

export function normalizeSeed(seed: number): number {
  const normalized = Math.abs(Math.trunc(seed)) >>> 0;
  return normalized === 0 ? 0x9e3779b9 : normalized;
}

export function nextRandom(state: number): RngStep {
  let value = state >>> 0;
  value ^= value << 13;
  value ^= value >>> 17;
  value ^= value << 5;
  const nextState = value >>> 0;
  return { state: nextState, value: nextState / 0x1_0000_0000 };
}

export function seededShuffle<T>(values: readonly T[], initialState: number): { values: T[]; state: number } {
  const copy = [...values];
  let state = initialState;
  for (let index = copy.length - 1; index > 0; index -= 1) {
    const step = nextRandom(state);
    state = step.state;
    const swapIndex = Math.floor(step.value * (index + 1));
    const current = copy[index];
    const other = copy[swapIndex];
    if (current !== undefined && other !== undefined) {
      copy[index] = other;
      copy[swapIndex] = current;
    }
  }
  return { values: copy, state };
}
