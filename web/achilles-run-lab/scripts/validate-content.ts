import { createDefaultConfig } from '../src/content/defaults';
import { validateConfig } from '../src/content/content_loader';

const result = validateConfig(createDefaultConfig(12345));
if (!result.ok) {
  process.stderr.write(`Contenu invalide :\n${result.errors.join('\n')}\n`);
  process.exitCode = 1;
} else {
  const enemyCount = result.config.rooms.reduce((sum, room) => sum + room.enemies.reduce((roomSum, entry) => roomSum + entry.count, 0), 0);
  process.stdout.write(`Contenu ${result.config.contentVersion} valide : ${result.config.rooms.length} salles, ${result.config.abilities.length} capacités, ${result.config.rewards.length} récompenses, ${enemyCount} ennemis initiaux.\n`);
}
