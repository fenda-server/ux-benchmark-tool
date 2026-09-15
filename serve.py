#!/usr/bin/env python3
"""
Servidor HTTP local com headers COOP/COEP para SharedArrayBuffer.

Necessário para FFmpeg.wasm (@ffmpeg/ffmpeg) no navegador.

Uso:
    python3 serve.py
    # abra http://localhost:8000
"""

from __future__ import annotations

import argparse
import functools
import http.server
import os
import socketserver
import sys


class CoopCoepRequestHandler(http.server.SimpleHTTPRequestHandler):
    """Serve arquivos estáticos com Cross-Origin Isolation habilitada."""

    extensions_map = {
        **getattr(http.server.SimpleHTTPRequestHandler, "extensions_map", {}),
        ".wasm": "application/wasm",
        ".js": "text/javascript",
        ".mjs": "text/javascript",
        ".json": "application/json",
        ".html": "text/html",
        ".css": "text/css",
    }

    def translate_path(self, path: str) -> str:
        """Impede path traversal (../) fora do diretório raiz."""
        translated = super().translate_path(path)
        root = os.path.abspath(self.directory)
        abspath = os.path.abspath(translated)
        if abspath != root and not abspath.startswith(root + os.sep):
            raise FileNotFoundError("forbidden path")
        return translated

    def end_headers(self) -> None:
        # SharedArrayBuffer + FFmpeg.wasm
        # credentialless (em vez de require-corp) libera CDNs sem header CORP
        # (Tailwind, Lucide, Google Fonts, jsDelivr) mantendo isolamento.
        self.send_header("Cross-Origin-Opener-Policy", "same-origin")
        self.send_header("Cross-Origin-Embedder-Policy", "credentialless")
        self.send_header("Cross-Origin-Resource-Policy", "cross-origin")
        self.send_header("X-Content-Type-Options", "nosniff")
        self.send_header("Referrer-Policy", "strict-origin-when-cross-origin")
        self.send_header("X-Frame-Options", "SAMEORIGIN")
        self.send_header(
            "Content-Security-Policy",
            "default-src 'self'; "
            "script-src 'self' 'unsafe-inline' 'wasm-unsafe-eval' blob: https://cdn.tailwindcss.com https://cdn.jsdelivr.net; "
            "style-src 'self' 'unsafe-inline' https://cdn.tailwindcss.com https://fonts.googleapis.com; "
            "font-src 'self' https://fonts.gstatic.com; "
            "img-src 'self' blob: data:; "
            "media-src 'self' blob:; "
            "connect-src 'self' blob:; "
            "worker-src 'self' blob:; "
            "frame-ancestors 'self'; "
            "base-uri 'self'; "
            "form-action 'self'",
        )
        # Cache leve para assets locais
        if self.path.endswith((".js", ".css", ".wasm")):
            self.send_header("Cache-Control", "public, max-age=3600")
        else:
            self.send_header("Cache-Control", "no-cache")
        super().end_headers()

    def log_message(self, fmt: str, *args) -> None:
        sys.stderr.write("[%s] %s\n" % (self.log_date_time_string(), fmt % args))


def main() -> None:
    parser = argparse.ArgumentParser(description="Servidor local COOP/COEP para UX Benchmark")
    parser.add_argument("-p", "--port", type=int, default=8000, help="Porta (padrão: 8000)")
    parser.add_argument(
        "--host",
        default="127.0.0.1",
        help="Host de escuta (padrão: 127.0.0.1; use 0.0.0.0 em servidor)",
    )
    parser.add_argument(
        "-d",
        "--directory",
        default=os.path.dirname(os.path.abspath(__file__)) or ".",
        help="Diretório a servir (padrão: pasta deste script)",
    )
    args = parser.parse_args()

    os.chdir(args.directory)
    handler = functools.partial(CoopCoepRequestHandler, directory=args.directory)

    # Allow address reuse for quick restarts
    socketserver.TCPServer.allow_reuse_address = True

    with socketserver.TCPServer((args.host, args.port), handler) as httpd:
        display_host = "localhost" if args.host in ("127.0.0.1", "::1") else args.host
        print(f"UX Discovery Benchmark")
        print(f"  Servindo: {args.directory}")
        print(f"  URL:      http://{display_host}:{args.port}")
        print(f"  Headers:  COOP=same-origin · COEP=credentialless")
        print(f"  Ctrl+C para encerrar.\n")
        try:
            httpd.serve_forever()
        except KeyboardInterrupt:
            print("\nEncerrado.")


if __name__ == "__main__":
    main()
