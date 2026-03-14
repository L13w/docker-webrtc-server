FROM ossrs/srs:5

COPY srs.conf /usr/local/srs/conf/srs.conf
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN sed -i 's/\r$//' /usr/local/bin/entrypoint.sh && chmod +x /usr/local/bin/entrypoint.sh

# English UI overrides (replaces Chinese SRS defaults)
COPY html/ /usr/local/srs/objs/nginx/html/

# RTMP ingest
EXPOSE 1935
# HTTP server (HLS, static files)
EXPOSE 8080
# HTTP API
EXPOSE 1985
# WebRTC media (ICE/SRTP) - UDP preferred, TCP fallback
EXPOSE 8000/udp
EXPOSE 8000/tcp

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
