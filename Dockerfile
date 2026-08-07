ARG N8N_VERSION=1.103.2
FROM n8nio/n8n:${N8N_VERSION}

USER root
RUN if command -v apk >/dev/null 2>&1; then \
      apk add --no-cache python3 py3-pip; \
    elif command -v apt-get >/dev/null 2>&1; then \
      apt-get update && apt-get install -y --no-install-recommends python3 python3-pip && rm -rf /var/lib/apt/lists/*; \
    else \
      echo "No supported package manager found" && exit 1; \
    fi
RUN mkdir -p /opt/n8n-workers /data/local_products /data/video_jobs /data/video_output && chown -R node:node /opt/n8n-workers /data
USER node
