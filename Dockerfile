FROM couchbase
ADD /setup.sh /setup.sh
ENTRYPOINT ["bash","./setup.sh"]