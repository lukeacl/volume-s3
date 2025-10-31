FROM ubuntu

RUN apt-get update && apt-get -y install s3cmd cron

ADD run.sh /run.sh

VOLUME ["/volume"]

CMD ["/run.sh"]
