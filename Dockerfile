# Setu Finance - production image
# Builds the React app and runs the Express API in one image.
# On startup it copies the built frontend into a shared volume that Caddy serves.

# ---- build stage: compile the React/Vite frontend ----
FROM node:22-alpine AS build
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build          # vite build -> /app/dist

# ---- runtime stage: Express API + baked-in dist ----
FROM node:22-alpine
WORKDIR /app
ENV NODE_ENV=production
COPY package*.json ./
RUN npm ci --omit=dev
COPY server ./server
COPY shared ./shared
COPY --from=build /app/dist ./dist

EXPOSE 8787

# Healthcheck: server is up once the auth status endpoint responds.
HEALTHCHECK --interval=10s --timeout=5s --start-period=40s --retries=6 \
  CMD wget -qO- http://localhost:8787/api/auth/status >/dev/null 2>&1 || exit 1

# Publish the frontend into the shared volume, then start the API.
# Migrations run automatically inside the app on boot.
CMD ["sh", "-c", "mkdir -p /web && cp -r /app/dist/. /web/ && node server/index.js"]
