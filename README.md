# UX Discovery Benchmark

Ferramenta web **local** (single-file) para processar gravações de tela: gerar GIFs de motion/interação e capturar frames para relatórios de jornada (Figma-ready).

Tudo roda no navegador com **FFmpeg.wasm** — nenhum upload para servidores externos.

## Como rodar

O FFmpeg.wasm exige `SharedArrayBuffer`, que só fica disponível com isolamento cross-origin (**COOP/COEP**). Use o servidor incluído:

```bash
cd ux-benchmark-tool
python3 serve.py
```

Abra [http://localhost:8000](http://localhost:8000).

> **Não use** `python3 -m http.server` — ele não envia os headers necessários e o FFmpeg falhará ao carregar.

Porta customizada:

```bash
python3 serve.py -p 8080
```

### Deploy em servidor

Para expor na rede (ex.: VM / container):

```bash
python3 serve.py --host 0.0.0.0 -p 8000
```

No Windows (sem Python):

```powershell
.\serve.ps1 -Port 8000
```

> O `serve.ps1` escuta apenas em `localhost`. Em produção no Windows, prefira `serve.py` com `--host 0.0.0.0` ou coloque um reverse proxy (nginx/Caddy) na frente.

**Segurança:** a ferramenta processa vídeos 100% no navegador — não há upload para backend. O servidor só entrega arquivos estáticos com headers COOP/COEP. Não exponha diretamente à internet sem HTTPS e controle de acesso, se aplicável.

## Funcionalidades

### 1. Player & Controles
- Carregar vídeo local (arrastar/soltar ou clique) — MP4, WebM, MOV
- Timeline com scrubber e marcadores **In** / **Out** (Out adiciona à fila)
- Botão **Remover vídeo** para trocar de gravação
- Captura do frame atual para a galeria de jornada

**Atalhos:** `Space` play/pause · `I` In · `O` Out · `C` capturar · `←`/`→` ±5s

### 2. Fila de exportação
- Marque **In** e **Out** — cada par válido entra na fila automaticamente
- Timeline com faixas semi-transparentes por trecho e marcadores de captura (clique para ir ao tempo)
- **Exportar todos** em **GIF** (`palettegen`/`paletteuse`) ou **MP4** (`-c copy`, qualidade original)
- Download individual por arquivo

### 3. Galeria de Jornada
- Frames PNG com campo de legenda (ex.: “Ponto de fricção”)
- **Exportar Jornada** → `.zip` com:
  - `01_frame.png`, `02_frame.png`, …
  - `legendas.json` (ordem, tempo, legenda)

## Stack

| Peça | Uso |
|------|-----|
| Tailwind CSS (CDN) | UI |
| Lucide Icons (CDN) | Ícones |
| FFmpeg.wasm | Codificação GIF no browser |
| JSZip | Pacote da jornada |

## Estrutura

```
ux-benchmark-tool/
├── index.html          # App completo (UI + lógica)
├── serve.py            # HTTP + headers COOP/COEP (credentialless)
├── vendor/             # FFmpeg.wasm local (same-origin / Workers)
│   ├── ffmpeg/         # @ffmpeg/ffmpeg ESM
│   ├── util/           # @ffmpeg/util ESM
│   └── core/           # ffmpeg-core.js + .wasm
└── README.md
```

> O diretório `vendor/` é necessário porque, sob isolamento cross-origin, o Web Worker do FFmpeg precisa ser same-origin.
## Requisitos

- Python 3.8+ (apenas para o servidor local)
- Navegador moderno (Chrome, Edge, Firefox recentes)
- Conexão na primeira carga (CDN: FFmpeg core, Tailwind, Lucide, JSZip)
