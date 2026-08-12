import { createServer } from 'vite';

const server = await createServer({
  server: { host: '127.0.0.1', port: 4173, strictPort: true },
});

await server.listen();
process.stdout.write('Serveur E2E prêt sur http://127.0.0.1:4173\n');

let closing = false;
const shutdown = async () => {
  if (closing) return;
  closing = true;
  await server.close();
  process.exit(0);
};

setTimeout(() => { void shutdown(); }, 120_000);
process.once('SIGINT', () => { void shutdown(); });
process.once('SIGTERM', () => { void shutdown(); });

