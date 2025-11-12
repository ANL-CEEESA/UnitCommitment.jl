# Build Stage
FROM node:18-alpine AS build
WORKDIR /app
COPY package*.json ./
RUN npm install
COPY . .
ARG REACT_APP_BACKEND_URL
ENV REACT_APP_BACKEND_URL=$REACT_APP_BACKEND_URL
RUN npm run build
 
# Production Stage
FROM node:18-alpine AS production
WORKDIR /app
COPY --from=build /app/build ./build
COPY server.js ./
RUN npm install --production express
EXPOSE 3000
CMD ["node", "server.js"]
