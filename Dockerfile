FROM openjdk:8-jdk

# grab gosu for easy step-down from root
ENV GOSU_VERSION 1.7
RUN set -x \
	&& wget -O /usr/local/bin/gosu "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$(dpkg --print-architecture)" \
	&& wget -O /usr/local/bin/gosu.asc "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$(dpkg --print-architecture).asc" \
	&& export GNUPGHOME="$(mktemp -d)" \
	&& gpg --keyserver ha.pool.sks-keyservers.net --recv-keys B42F6819007F00F88E364FD4036A9C25BF357DD4 \
	&& gpg --batch --verify /usr/local/bin/gosu.asc /usr/local/bin/gosu \
	&& rm -r "$GNUPGHOME" /usr/local/bin/gosu.asc \
	&& chmod +x /usr/local/bin/gosu \
	&& gosu nobody true

# https://artifacts.elastic.co/GPG-KEY-elasticsearch
RUN apt-key adv --keyserver ha.pool.sks-keyservers.net --recv-keys 46095ACC8548582C1A2699A9D27D666CD88E42B4

# https://www.elastic.co/guide/en/elasticsearch/reference/current/setup-repositories.html
# https://www.elastic.co/guide/en/elasticsearch/reference/5.0/deb.html
RUN set -x \
	&& apt-get update && apt-get install -y --no-install-recommends apt-transport-https && rm -rf /var/lib/apt/lists/* \
	&& echo 'deb https://artifacts.elastic.co/packages/5.x/apt stable main' > /etc/apt/sources.list.d/elasticsearch.list

ENV ELASTICSEARCH_VERSION 5.0.1

RUN set -x \
	&& apt-get update \
	&& apt-get install -y --no-install-recommends elasticsearch=$ELASTICSEARCH_VERSION \
	&& rm -rf /var/lib/apt/lists/*

ENV PATH /usr/share/elasticsearch/bin:$PATH

WORKDIR /usr/share/elasticsearch

RUN set -ex \
	&& for path in \
		./data \
		./logs \
		./config \
		./config/scripts \
	; do \
		mkdir -p "$path"; \
		chown -R elasticsearch:elasticsearch "$path"; \
	done

COPY config ./config

# install maven
RUN \
	cd /usr/share \
	&& wget -c http://mirrors.cnnic.cn/apache/maven/maven-3/3.3.9/binaries/apache-maven-3.3.9-bin.zip \
	&& unzip apache-maven-3.3.9-bin.zip \
	&& rm /usr/share/apache-maven-3.3.9-bin.zip

ENV PATH /usr/share/apache-maven-3.3.9/bin:$PATH

# install elasticsearch-analysis-ik
RUN \
	cd /usr/share/elasticsearch/plugins \
	&& wget -c -O ik.zip https://codeload.github.com/medcl/elasticsearch-analysis-ik/zip/v5.0.1 \
	&& unzip ik.zip \
	&& rm ik.zip \
	&& cd elasticsearch-analysis-ik-5.0.1 \
	&& mvn clean \
	&& mvn compile \
	&& mvn package \
	&& mkdir /usr/share/elasticsearch/plugins/ik \
	&& cp target/releases/elasticsearch-analysis-ik-*.zip /usr/share/elasticsearch/plugins/ik \
	&& cd /usr/share/elasticsearch/plugins \
	&& rm -rf elasticsearch-analysis-ik-5.0.1 \
	&& cd /usr/share/elasticsearch/plugins/ik \
	&& unzip elasticsearch-analysis-ik-*.zip \
	&& rm elasticsearch-analysis-ik-*.zip

# install elasticsearch-analysis-pinyin
RUN \
	cd /usr/share/elasticsearch/plugins \
	&& wget -c -O pinyin.zip https://codeload.github.com/medcl/elasticsearch-analysis-pinyin/zip/v5.0.1 \
	&& unzip pinyin.zip \
	&& rm pinyin.zip \
	&& cd elasticsearch-analysis-pinyin-5.0.1 \
	&& mvn clean \
	&& mvn compile \
	&& mvn package \
  	&& mkdir /usr/share/elasticsearch/plugins/pinyin \
	&& cp target/releases/elasticsearch-analysis-pinyin-*.zip /usr/share/elasticsearch/plugins/pinyin \
	&& cd /usr/share/elasticsearch/plugins \
	&& rm -rf elasticsearch-analysis-pinyin-5.0.1 \
  	&& cd /usr/share/elasticsearch/plugins/pinyin \
	&& unzip elasticsearch-analysis-pinyin-*.zip \
	&& rm elasticsearch-analysis-pinyin-*.zip

VOLUME /usr/share/elasticsearch/data

COPY docker-entrypoint.sh /

RUN chmod a+x /docker-entrypoint.sh

EXPOSE 9200 9300
ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["elasticsearch"]