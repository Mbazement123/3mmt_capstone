FROM node:20.6.1-alpine AS build
WORKDIR /app

COPY package*.json ./
RUN npm ci --legacy-peer-deps

COPY . .
RUN npm run build

FROM node:20.6.1-alpine
WORKDIR /app

ENV NODE_ENV=production
ENV PORT=5000

COPY package*.json ./
RUN npm ci --omit=dev --legacy-peer-deps && npm cache clean --force

COPY --from=build /app/dist ./dist
COPY --from=build /app/src ./src
COPY --from=build /app/.sequelizerc ./
COPY --from=build /app/nest-cli.json ./
COPY --from=build /app/tsconfig.build.json ./
COPY --from=build /app/tsconfig.json ./

EXPOSE 5000
CMD ["node", "dist/main.js"]
