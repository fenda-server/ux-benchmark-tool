# Servidor HTTP local com headers COOP/COEP para SharedArrayBuffer (FFmpeg.wasm).
# Alternativa ao serve.py para Windows sem Python instalado.
#
# Uso:
#   .\serve.ps1
#   .\serve.ps1 -Port 8080

param(
    [int]$Port = 8000,
    [string]$Directory = $PSScriptRoot
)

$MimeTypes = @{
    ".html" = "text/html; charset=utf-8"
    ".htm"  = "text/html; charset=utf-8"
    ".js"   = "text/javascript; charset=utf-8"
    ".mjs"  = "text/javascript; charset=utf-8"
    ".json" = "application/json; charset=utf-8"
    ".css"  = "text/css; charset=utf-8"
    ".wasm" = "application/wasm"
    ".png"  = "image/png"
    ".jpg"  = "image/jpeg"
    ".jpeg" = "image/jpeg"
    ".gif"  = "image/gif"
    ".svg"  = "image/svg+xml"
    ".ico"  = "image/x-icon"
    ".zip"  = "application/zip"
    ".mp4"  = "video/mp4"
    ".webm" = "video/webm"
}

$listener = [System.Net.HttpListener]::new()
$listener.Prefixes.Add("http://localhost:$Port/")
$listener.Start()

Write-Host "UX Discovery Benchmark"
Write-Host "  Servindo: $Directory"
Write-Host "  URL:      http://localhost:$Port"
Write-Host "  Headers:  COOP=same-origin · COEP=credentialless"
Write-Host "  Ctrl+C para encerrar.`n"

try {
    while ($listener.IsListening) {
        $context = $listener.GetContext()
        $request = $context.Request
        $response = $context.Response

        $localPath = [System.Uri]::UnescapeDataString($request.Url.LocalPath)
        if ($localPath -eq "/") { $localPath = "/index.html" }

        $relativePath = $localPath.TrimStart("/") -replace "/", [System.IO.Path]::DirectorySeparatorChar
        $filePath = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($Directory, $relativePath))
        $rootFull = [System.IO.Path]::GetFullPath($Directory)

        if (-not $filePath.StartsWith($rootFull, [StringComparison]::OrdinalIgnoreCase)) {
            $response.StatusCode = 403
            $body = [System.Text.Encoding]::UTF8.GetBytes("403 Forbidden")
            $response.ContentType = "text/plain; charset=utf-8"
            $response.ContentLength64 = $body.Length
            $response.OutputStream.Write($body, 0, $body.Length)
            $response.Close()
            continue
        }

        $response.Headers.Add("Cross-Origin-Opener-Policy", "same-origin")
        $response.Headers.Add("Cross-Origin-Embedder-Policy", "credentialless")
        $response.Headers.Add("Cross-Origin-Resource-Policy", "cross-origin")
        $response.Headers.Add("X-Content-Type-Options", "nosniff")
        $response.Headers.Add("Referrer-Policy", "strict-origin-when-cross-origin")
        $response.Headers.Add("X-Frame-Options", "SAMEORIGIN")
        $response.Headers.Add(
            "Content-Security-Policy",
            "default-src 'self'; script-src 'self' 'unsafe-inline' https://cdn.tailwindcss.com https://cdn.jsdelivr.net; style-src 'self' 'unsafe-inline' https://cdn.tailwindcss.com https://fonts.googleapis.com; font-src 'self' https://fonts.gstatic.com; img-src 'self' blob: data:; media-src 'self' blob:; connect-src 'self' blob:; worker-src 'self' blob:; frame-ancestors 'self'; base-uri 'self'; form-action 'self'"
        )

        if (Test-Path -LiteralPath $filePath -PathType Leaf) {
            $ext = [System.IO.Path]::GetExtension($filePath).ToLowerInvariant()
            $contentType = $MimeTypes[$ext]
            if (-not $contentType) { $contentType = "application/octet-stream" }

            if ($ext -in @(".js", ".css", ".wasm")) {
                $response.Headers.Add("Cache-Control", "public, max-age=3600")
            } else {
                $response.Headers.Add("Cache-Control", "no-cache")
            }

            $bytes = [System.IO.File]::ReadAllBytes($filePath)
            $response.StatusCode = 200
            $response.ContentType = $contentType
            $response.ContentLength64 = $bytes.Length
            $response.OutputStream.Write($bytes, 0, $bytes.Length)
            Write-Host "[$(Get-Date -Format 'dd/MM/yyyy HH:mm:ss')] $($request.HttpMethod) $localPath -> 200"
        } else {
            $response.StatusCode = 404
            $body = [System.Text.Encoding]::UTF8.GetBytes("404 Not Found")
            $response.ContentType = "text/plain; charset=utf-8"
            $response.ContentLength64 = $body.Length
            $response.OutputStream.Write($body, 0, $body.Length)
            Write-Host "[$(Get-Date -Format 'dd/MM/yyyy HH:mm:ss')] $($request.HttpMethod) $localPath -> 404"
        }

        $response.Close()
    }
} finally {
    $listener.Stop()
    $listener.Close()
    Write-Host "`nEncerrado."
}
