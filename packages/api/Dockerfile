FROM node:22-slim

WORKDIR /app

COPY package.json package-lock.json ./
RUN npm ci --omit=dev

COPY index.ts ./

EXPOSE 3000

CMD ["node",  "index.ts"]
