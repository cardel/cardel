# ============================================================
# docs-pdf-builder v2 — Markdown + Mermaid → PDF
# ============================================================
# Build:  docker build -t cardel87/create-pdf-from-markdown:latest .
# Push:   docker push cardel87/create-pdf-from-markdown:latest
# ============================================================

FROM node:20-slim

LABEL maintainer="Confirmeza" version="2.0.0"

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true \
    PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium \
    CHROME_BIN=/usr/bin/chromium

# ============================================================
# 1. Sistema + Chromium + Fuentes
# ============================================================
RUN apt-get update && apt-get install -y --no-install-recommends \
    wget curl ca-certificates git jq \
    fonts-noto fonts-noto-cjk fonts-liberation fontconfig \
    librsvg2-bin \
    # Chromium y TODAS sus dependencias
    chromium \
    libnss3 libatk1.0-0 libatk-bridge2.0-0 libcups2 libdrm2 \
    libxcomposite1 libxdamage1 libxrandr2 libgbm1 libasound2 \
    libpangocairo-1.0-0 libgtk-3-0 libxshmfence1 libx11-xcb1 \
    libxss1 libxcb-dri3-0 \
    # dbus necesario para chromium en contenedor
    dbus \
  && fc-cache -fv \
  && apt-get clean && rm -rf /var/lib/apt/lists/*

# ============================================================
# 2. Pandoc
# ============================================================
ARG PANDOC_VERSION=3.1.12
RUN wget -q "https://github.com/jgm/pandoc/releases/download/${PANDOC_VERSION}/pandoc-${PANDOC_VERSION}-1-amd64.deb" \
  && dpkg -i "pandoc-${PANDOC_VERSION}-1-amd64.deb" \
  && rm -f *.deb

# ============================================================
# 3. TinyTeX + paquetes LaTeX
# ============================================================
RUN wget -qO- "https://yihui.org/tinytex/install-bin-unix.sh" | sh \
  && mv /root/.TinyTeX /opt/TinyTeX \
  && ln -s /opt/TinyTeX/bin/x86_64-linux/* /usr/local/bin/

RUN for pkg in \
      babel-spanish geometry fancyhdr fancyvrb titlesec titling \
      parskip setspace enumitem float caption booktabs multirow \
      bookmark xurl tcolorbox environ fontspec selnolig iftex \
      listings upquote svg adjustbox collectbox pgf etoolbox \
      footmisc natbib background everypage csquotes mdframed \
      needspace sourcesanspro sourcecodepro ly1 zref xpatch \
      footnotebackref pagecolor koma-script; \
    do \
      tlmgr install "$pkg" 2>&1 || true; \
    done && texhash

# ============================================================
# 4. Mermaid CLI + Puppeteer config
# ============================================================
RUN npm install -g @mermaid-js/mermaid-cli@10.9.1 \
  && npm cache clean --force

# Config de Puppeteer — CRÍTICO para que Chromium funcione
# --single-process y --disable-dev-shm-usage son esenciales en containers
RUN echo '{ \
  "executablePath": "/usr/bin/chromium", \
  "args": [ \
    "--no-sandbox", \
    "--disable-setuid-sandbox", \
    "--disable-dev-shm-usage", \
    "--disable-gpu", \
    "--disable-software-rasterizer", \
    "--single-process" \
  ] \
}' > /etc/mermaid-puppeteer.json

# ============================================================
# 5. Script entrypoint
# ============================================================
COPY generate-pdf.sh /usr/local/bin/generate-pdf
RUN chmod +x /usr/local/bin/generate-pdf

WORKDIR /workspace

# ============================================================
# 6. Smoke tests — si fallan, el build falla
# ============================================================
RUN echo "=== Test Pandoc ===" && pandoc --version | head -1
RUN echo "=== Test XeLaTeX ===" && xelatex --version | head -1

# Test Mermaid: si esto no funciona, el build se detiene
RUN echo "=== Test Mermaid ===" \
  && echo 'graph LR; A["Hola"]-->B["Mundo"]' > /tmp/_smoke.mmd \
  && mmdc -i /tmp/_smoke.mmd -o /tmp/_smoke.png \
     -p /etc/mermaid-puppeteer.json -s 2 -b white 2>&1 \
  && test -s /tmp/_smoke.png \
  && echo "Mermaid PNG: OK ✅ ($(wc -c < /tmp/_smoke.png) bytes)" \
  && rm -f /tmp/_smoke.*

# Test PDF completo: markdown → PDF con XeLaTeX
RUN echo "=== Test PDF ===" \
  && printf '# Título de Prueba\n\nContenido con **formato** y `código`.\n' > /tmp/_smoke.md \
  && pandoc /tmp/_smoke.md -o /tmp/_smoke.pdf --pdf-engine=xelatex \
     -V mainfont="Noto Sans" -V monofont="Liberation Mono" 2>&1 \
  && test -s /tmp/_smoke.pdf \
  && echo "PDF: OK ✅" \
  && rm -f /tmp/_smoke.*

RUN echo "========================================" \
  && echo "  Todos los tests pasaron ✅" \
  && echo "========================================"

ENTRYPOINT ["generate-pdf"]
CMD ["--help"]
