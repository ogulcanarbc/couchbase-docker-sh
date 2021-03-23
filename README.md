## Environment Variables Examples
    environment:
      CB_REST_USERNAME: Administrator
      CB_REST_PASSWORD: password123
      BUCKET: phone-number-mask-history
      STARTUP_TIMEOUT: 100 #default: 60 (seconds)
      BUCKET_WAIT_TIME: 60 #default: 60 (seconds)
      RAM_SIZE_MB: 256 #default: 256 (mb)
      ENABLE_FLUSH: 1 #default: 1
      BUCKET_RAM_SIZE_MB: 256  #default: 256 (mb)

**Docker Setup With Compose**
* execute bash `docker build -t <yourusername/repository-name> .`
* udpdate couchbase image name on docker compose file
* run `docker-compose up` command to get a running Couchbase.

and after visit to couchbase ui url `http://localhost:8091/ui/index.html`