"""Serve only the title music panel and its existing local backdrop on loopback."""
import argparse
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
FILES = {
    '/': HERE / 'title_music_panel.html',
    '/title_music_panel.html': HERE / 'title_music_panel.html',
    '/title_music_panel.css': HERE / 'title_music_panel.css',
    '/title_music_catalog.js': HERE / 'title_music_catalog.js',
    '/title_music_panel.js': HERE / 'title_music_panel.js',
    '/assets/catabase/title/underworld_gate_mythology_v3.png': ROOT / 'assets/catabase/title/underworld_gate_mythology_v3.png',
}


class Handler(SimpleHTTPRequestHandler):
    def do_GET(self):
        resource = FILES.get(self.path.split('?', 1)[0])
        if not resource or not resource.is_file():
            self.send_error(404)
            return
        data = resource.read_bytes()
        self.send_response(200)
        self.send_header('Content-Type', self.guess_type(str(resource)))
        self.send_header('Content-Length', str(len(data)))
        self.send_header('Cache-Control', 'no-cache')
        self.end_headers()
        self.wfile.write(data)

    def do_HEAD(self):
        self.send_error(405)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--port', type=int, default=8796)
    args = parser.parse_args()
    print(f'Panneau musical : http://127.0.0.1:{args.port}', flush=True)
    ThreadingHTTPServer(('127.0.0.1', args.port), Handler).serve_forever()
