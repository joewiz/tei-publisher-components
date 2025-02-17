ARG EXIST_VERSION=5.2.0

# START STAGE 1
FROM openjdk:8-jdk-slim as builder

USER root

ENV ANT_VERSION 1.10.11
ENV ANT_HOME /etc/ant-${ANT_VERSION}

WORKDIR /tmp

RUN apt-get update && apt-get install -y \
    git \
    curl

RUN curl -L -o apache-ant-${ANT_VERSION}-bin.tar.gz http://www.apache.org/dist/ant/binaries/apache-ant-${ANT_VERSION}-bin.tar.gz \
    && mkdir ant-${ANT_VERSION} \
    && tar -zxvf apache-ant-${ANT_VERSION}-bin.tar.gz \
    && mv apache-ant-${ANT_VERSION} ${ANT_HOME} \
    && rm apache-ant-${ANT_VERSION}-bin.tar.gz \
    && rm -rf ant-${ANT_VERSION} \
    && rm -rf ${ANT_HOME}/manual \
    && unset ANT_VERSION

ENV PATH ${PATH}:${ANT_HOME}/bin

RUN curl -sL https://deb.nodesource.com/setup_14.x | bash - \
    && apt-get install -y nodejs \
    && curl -L https://www.npmjs.com/install.sh | sh

FROM builder as tei

ARG TEMPLATING_VERSION=v1.0.0
ARG PUBLISHER_LIB_VERSION=v2.9.0
ARG ROUTER_VERSION=v0.5.1
ARG PUBLISHER_VERSION=master

# add key
RUN  mkdir -p ~/.ssh && ssh-keyscan -t rsa github.com >> ~/.ssh/known_hosts

RUN git clone https://github.com/eXist-db/templating.git \
    && cd templating \
    && git checkout ${TEMPLATING_VERSION} \
    && npm start

# Build tei-publisher-lib
RUN  git clone https://github.com/eeditiones/tei-publisher-lib.git \
    && cd tei-publisher-lib \
    && git checkout ${PUBLISHER_LIB_VERSION} \
    && ant

RUN  git clone https://github.com/eeditiones/roaster.git \
    && cd roaster \
    && git checkout ${ROUTER_VERSION} \
    && ant

# Build tei-publisher-app
RUN  git clone https://github.com/eeditiones/tei-publisher-app.git \
    && cd tei-publisher-app \
    && git checkout ${PUBLISHER_VERSION} \
    # if you prefer to have webcomponents included locally, comment out following line and
    # enable the ones below
    && sed -i 's/$config:webcomponents :=.*;/$config:webcomponents := "local";/' modules/config.xqm \
    && ant -Dnpm=npm xar-local

WORKDIR /tmp/tei-publisher-app

COPY dist/*.js resources/scripts/
COPY i18n/common/* resources/i18n/common/

RUN ant

FROM existdb/existdb:${EXIST_VERSION}

COPY --from=tei /tmp/templating/templating-*.xar /exist/autodeploy
COPY --from=tei /tmp/tei-publisher-lib/build/*.xar /exist/autodeploy
COPY --from=tei /tmp/roaster/build/*.xar /exist/autodeploy
COPY --from=tei /tmp/tei-publisher-app/build/*.xar /exist/autodeploy

ENV DATA_DIR /exist-data

ENV JAVA_TOOL_OPTIONS \
    -Dfile.encoding=UTF8 \
    -Dsun.jnu.encoding=UTF-8 \
    -Djava.awt.headless=true \
    -Dorg.exist.db-connection.cacheSize=${CACHE_MEM:-256}M \
    -Dorg.exist.db-connection.pool.max=${MAX_BROKER:-20} \
    -Dlog4j.configurationFile=/exist/etc/log4j2.xml \
    -Dexist.home=/exist \
    -Dexist.configurationFile=/exist/etc/conf.xml \
    -Djetty.home=/exist \
    -Dexist.jetty.config=/exist/etc/jetty/standard.enabled-jetty-configs \
    -XX:+UnlockExperimentalVMOptions \
    -XX:+UseCGroupMemoryLimitForHeap \
    -XX:+UseG1GC \
    -XX:+UseStringDeduplication \
    -XX:MaxRAMFraction=1 \
    -XX:+ExitOnOutOfMemoryError \
    -Dorg.exist.db-connection.files=${DATA_DIR} \
    -Dorg.exist.db-connection.recovery.journal-dir=${DATA_DIR}

# pre-populate the database by launching it once
RUN [ "java", \
    "org.exist.start.Main", "client", "-l", \
    "--no-gui",  "--xpath", "system:get-version()" ]