import { describe, expect, test } from 'vitest';
import { createDefaultConfig } from '../../src/content/defaults';
import { chooseAchillesCommand } from '../../src/domain/ai/achilles_bot';
import { applyGameCommand, createInitialGameState } from '../../src/domain/run/engine';

describe('simulation multi-seed', () => {
  test('plusieurs seeds avancent sans NaN, commande invalide ni boucle', () => {
    for (const seed of [1, 7, 42, 12345, 54321]) {
      const config = createDefaultConfig(seed);
      let result = applyGameCommand(createInitialGameState(), { type: 'START_RUN', seed, config });
      if (!result.accepted) throw new Error(result.error);
      let state = result.state;
      let guard = 0;
      while (state.run?.result === 'IN_PROGRESS' && guard < 1000) {
        result = applyGameCommand(state, chooseAchillesCommand(state));
        expect(result.accepted).toBe(true);
        if (!result.accepted) throw new Error(result.error);
        state = result.state;
        guard += 1;
      }
      expect(guard).toBeLessThan(1000);
      expect(JSON.stringify(state)).not.toContain('NaN');
      expect(state.run?.metrics.invalidCommandCount).toBe(0);
    }
  });
});
