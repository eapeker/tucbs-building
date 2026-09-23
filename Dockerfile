# TUCBS bina veri seti: CityGML -> CityJSON -> 3D Tiles pipeline'ini
# tek bir imaj icinde calistirir. Uc farkli calisma zamani (Java, Python,
# Node.js) gerektiren bu pipeline'i host makinede elle kurmak yerine
# (bkz. README.md "Setup" bolumu - conda, citygml-tools, portable Node
# indirme scriptleri) burada hepsi tek seferde, tekrarlanabilir sekilde
# kuruluyor.
FROM node:22-bookworm

# --- Java 17 (citygml-tools icin) + Python 3 (cjio, pyproj, triangle icin) ---
RUN apt-get update && apt-get install -y --no-install-recommends \
    openjdk-17-jre-headless \
    python3 \
    python3-pip \
    curl \
    unzip \
    && rm -rf /var/lib/apt/lists/*

# --- citygml-tools (CityGML -> CityJSON) ---
ARG CITYGML_TOOLS_VERSION=2.5.0
RUN curl -sL -o /tmp/citygml-tools.zip \
      "https://github.com/citygml4j/citygml-tools/releases/download/v${CITYGML_TOOLS_VERSION}/citygml-tools-${CITYGML_TOOLS_VERSION}.zip" \
    && unzip -q /tmp/citygml-tools.zip -d /opt \
    && mv "/opt/citygml-tools-${CITYGML_TOOLS_VERSION}" /opt/citygml-tools \
    && rm /tmp/citygml-tools.zip \
    && ln -s /opt/citygml-tools/citygml-tools /usr/local/bin/citygml-tools

# --- Python bagimliliklari ---
RUN pip3 install --no-cache-dir --break-system-packages \
    cjio==0.10.1 \
    pyproj==3.7.2 \
    triangle==20250106

WORKDIR /app

# --- Node bagimliliklari (once sadece package*.json, cache icin) ---
COPY tools/package.json tools/package-lock.json ./tools/
RUN cd tools && npm ci

# --- Proje dosyalari ---
COPY data/raw ./data/raw
COPY scripts ./scripts

ENV PYTHON=python3
ENV CITYGML_TOOLS=citygml-tools

# Varsayilan komut: tam pipeline'i bastan sona calistirir
# (data/raw -> data/cityjson -> data/3dtiles).
CMD bash scripts/convert_to_cityjson.sh && \
    cd tools && node ../scripts/generate_3dtiles_textured.mjs
