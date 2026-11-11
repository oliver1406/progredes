ARG BASE_IMAGE
FROM ${BASE_IMAGE}
ARG VCS_REF
LABEL org.opencontainers.image.revision="${VCS_REF}"
COPY nginx.conf /etc/nginx/nginx.conf
COPY index.html /usr/share/nginx/html/index.html
RUN test -n "$VCS_REF" && printf '{"revision":"%s","kind":"demo"}\n' "$VCS_REF" > /usr/share/nginx/html/version.json
USER 101:101
EXPOSE 8080
HEALTHCHECK --interval=10s --timeout=3s --retries=6 CMD wget -q -O /dev/null http://127.0.0.1:8080/health || exit 1
ENTRYPOINT ["nginx", "-g", "daemon off;"]
