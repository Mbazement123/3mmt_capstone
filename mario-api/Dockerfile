FROM node:20.6.1-alpine AS build
WORKDIR /app

COPY package*.json ./
RUN npm ci --legacy-peer-deps

COPY . .
RUN npm run build

FROM node:20.6.1-alpine
WORKDIR /app

# Do not force production NODE_ENV in the image; allow docker-compose to set it for dev tests
ENV PORT=5000

# Runtime image: install only runtime deps (no sqlite)
RUN apk add --no-cache python3

COPY package*.json ./
RUN npm ci --legacy-peer-deps

COPY --from=build /app/dist ./dist
COPY --from=build /app/src ./src
COPY --from=build /app/.sequelizerc ./
COPY --from=build /app/nest-cli.json ./
COPY --from=build /app/tsconfig.build.json ./
COPY --from=build /app/tsconfig.json ./

EXPOSE 5000
CMD ["node", "dist/main.js"]
