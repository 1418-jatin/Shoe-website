# ---- Jakey Shoes : static site served by Nginx ----
FROM nginx:1.27-alpine

# Custom nginx config (gzip, caching, /healthz endpoint)
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Website
COPY index.html /usr/share/nginx/html/index.html

EXPOSE 80

HEALTHCHECK --interval=30s --timeout=3s --retries=3 \
  CMD wget -qO- http://localhost/healthz || exit 1

CMD ["nginx", "-g", "daemon off;"]
