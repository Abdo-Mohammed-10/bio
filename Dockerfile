FROM nginx:1.25-alpine AS build

RUN rm -rf /usr/share/nginx/html/*

COPY frontend/ /usr/share/nginx/html/

FROM nginx:1.25-alpine

COPY nginx.conf /etc/nginx/nginx.conf

COPY --from=build /usr/share/nginx/html /usr/share/nginx/html

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]