FROM node:24.19.0-bookworm-slim@sha256:a9f5f7c91a432850b2a8a7797adf5eadb6c733ceed61167806cee7ea7fbc29df AS base
WORKDIR /app
ENV NODE_ENV=production BRUMORA_HOST=0.0.0.0 BRUMORA_PORT=8787
COPY --chown=node:node server/package.json server/index.ts server/engine.ts ./server/
COPY --chown=node:node assets/species.json assets/enemies.json ./assets/
RUN mkdir -p /app/server/data && chown node:node /app/server/data
USER node
EXPOSE 8787
HEALTHCHECK --interval=10s --timeout=3s --start-period=5s --retries=3 CMD node -e "fetch('http://127.0.0.1:8787/health').then(r=>{if(!r.ok)process.exit(1)}).catch(()=>process.exit(1))"
FROM base AS test
COPY --chown=node:node tests/server.test.ts ./tests/server.test.ts
HEALTHCHECK NONE
CMD ["node", "--test", "tests/server.test.ts"]

FROM base AS runtime
CMD ["node", "server/index.ts"]
