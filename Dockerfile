# syntax=docker/dockerfile:1
# Multi-stage Dockerfile for Open edX Platform (LMS + CMS/Studio)
#
# Stages:
#   base     – system deps + Python 3.12 + Node 24
#   python   – install Python requirements
#   node     – install NPM packages and compile static assets
#   final    – lean runtime image

ARG PYTHON_VERSION=3.12
ARG NODE_VERSION=24

# ---------------------------------------------------------------------------
# Stage 1: base – OS packages, Python and Node runtimes
# ---------------------------------------------------------------------------
FROM python:${PYTHON_VERSION}-bookworm AS base

ARG NODE_VERSION

ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    DEBIAN_FRONTEND=noninteractive

# Install system packages required by edx-platform
RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential \
        curl \
        git \
        gettext \
        libffi-dev \
        libmysqlclient-dev \
        libssl-dev \
        libxml2-dev \
        libxmlsec1-dev \
        libxmlsec1-openssl \
        libxslt1-dev \
        pkg-config \
        python3-dev \
    && rm -rf /var/lib/apt/lists/*

# Install Node.js via NodeSource
RUN curl -fsSL https://deb.nodesource.com/setup_${NODE_VERSION}.x | bash - \
    && apt-get install -y --no-install-recommends nodejs \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /edx/app/edxapp/edx-platform

# ---------------------------------------------------------------------------
# Stage 2: python – install Python dependencies
# ---------------------------------------------------------------------------
FROM base AS python

# Copy only the requirements files first to maximise layer caching
COPY requirements/ requirements/
COPY pyproject.toml ./

RUN pip install --upgrade pip setuptools wheel \
    && pip install -r requirements/pip-tools.txt \
    && pip install -r requirements/edx/base.txt \
    # assets.txt provides libsass + click needed by scripts/compile_sass.py
    && pip install -r requirements/edx/assets.txt \
    && pip install -e .

# ---------------------------------------------------------------------------
# Stage 3: node – install npm packages and compile static assets
# ---------------------------------------------------------------------------
FROM python AS node

COPY package.json package-lock.json ./

RUN npm ci --prefer-offline

# Copy the rest of the source code
COPY . .

# Build JS bundles (webpack) and compile Sass → CSS.
# Uses npm scripts; no Django settings or database connection required here.
# devstack settings use DevelopmentStorage which serves static files directly
# from source, so collectstatic is not needed at build time.
RUN npm run build

# ---------------------------------------------------------------------------
# Stage 4: final – minimal runtime image
# ---------------------------------------------------------------------------
FROM python AS final

# Copy compiled assets and the full source
COPY --from=node /edx/app/edxapp/edx-platform /edx/app/edxapp/edx-platform

# Runtime directories
RUN mkdir -p \
        /edx/var/edxapp/staticfiles \
        /edx/var/edxapp/media \
        /edx/var/log/edxapp \
        /edx/src/ace_messages \
        /edx/var/data \
    && groupadd -r edxapp \
    && useradd -r -g edxapp -d /edx/app/edxapp -s /sbin/nologin edxapp \
    && chown -R edxapp:edxapp \
        /edx/var/edxapp \
        /edx/var/log \
        /edx/src \
        /edx/var/data

COPY docker/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 8000 8010

USER edxapp

ENTRYPOINT ["/entrypoint.sh"]
CMD ["lms"]
