FROM nginx:alpine

COPY ["CPG Athos.html", "/usr/share/nginx/html/index.html"]
COPY athos/ /usr/share/nginx/html/athos/
COPY default.conf /etc/nginx/conf.d/default.conf

EXPOSE 8010

CMD ["nginx", "-g", "daemon off;"]
