FROM spark:4.0.1-scala2.13-java17-python3-ubuntu@sha256:a552a335e0aedb44fa28b20ed7e9dc52c2e856faf87fb0409fb57dbf37b45bf7
USER root
RUN apt-get update && apt-get install -y --no-install-recommends python3-venv \
    && rm -rf /var/lib/apt/lists/* \
    && python3 -m venv /opt/venv \
    && /opt/venv/bin/pip install --no-cache-dir jupyterlab==4.4.9 \
    && ln -s /opt/spark/python/lib/py4j-*-src.zip /opt/py4j.zip \
    && mkdir -p /workspace /tmp/spark-work /home/alumno \
    && chown -R 1000:1000 /workspace /tmp/spark-work /home/alumno
ENV PATH="/opt/venv/bin:/opt/spark/bin:${PATH}" \
    PYTHONPATH="/opt/spark/python:/opt/py4j.zip" \
    PYSPARK_PYTHON="/opt/venv/bin/python" \
    PYSPARK_DRIVER_PYTHON="/opt/venv/bin/python" \
    HOME="/home/alumno" \
    SPARK_DAEMON_MEMORY="512m"
COPY spark-config/spark-defaults.conf /opt/spark/conf/spark-defaults.conf
ARG LOCAL_UID=501
ARG LOCAL_GID=20
RUN (getent group "${LOCAL_GID}" || groupadd --gid "${LOCAL_GID}" alumno) \
    && (getent passwd "${LOCAL_UID}" || useradd --uid "${LOCAL_UID}" --gid "${LOCAL_GID}" --home-dir /home/alumno alumno) \
    && chown -R "${LOCAL_UID}:${LOCAL_GID}" /home/alumno \
    && chmod 1777 /tmp/spark-work
WORKDIR /workspace
USER ${LOCAL_UID}:${LOCAL_GID}
