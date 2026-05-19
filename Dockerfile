FROM nginx:alpine

COPY ["CPG Athos.html", "/usr/share/nginx/html/index.html"]

RUN sed -i 's/listen\s*80;/listen 8010;/g; s/listen\s*\[::\]:80;/listen [::]:8010;/g' /etc/nginx/conf.d/default.conf

EXPOSE 8010

CMD ["nginx", "-g", "daemon off;"]
