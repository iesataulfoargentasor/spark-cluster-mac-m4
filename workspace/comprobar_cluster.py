"""Prueba real: registro de workers, Python remoto, agregación y Parquet compartido."""
import argparse
import json
import platform
import time
from urllib.request import urlopen
from pyspark.sql import SparkSession, functions as F

def identificar(partition):
    import socket
    from pyspark import BarrierTaskContext
    BarrierTaskContext.get().barrier()
    import platform
    yield (socket.gethostname(), platform.machine())

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--workers', type=int, choices=[1, 2], default=2)
    parser.add_argument("--expected-arch", choices=["aarch64", "x86_64"], default="aarch64")
    args = parser.parse_args()
    assert platform.machine() == args.expected_arch, platform.machine()
    alive = []
    for _ in range(60):
        with urlopen('http://spark-master:8080/json/', timeout=5) as response:
            info = json.load(response)
        alive = [w for w in info['workers'] if w['state'] == 'ALIVE']
        if len(alive) == args.workers:
            break
        time.sleep(2)
    assert len(alive) == args.workers, f'Esperados {args.workers} workers; encontrados {len(alive)}'
    spark = SparkSession.builder.appName('Comprobacion-SBD').getOrCreate()
    try:
        assert spark.sparkContext.master == 'spark://spark-master:7077'
        slots = args.workers * 2
        locations = spark.sparkContext.parallelize(range(slots), slots).barrier().mapPartitions(identificar).collect()
        hosts = [host for host, arch in locations]
        assert all(arch == args.expected_arch for host, arch in locations), locations
        assert len(set(hosts)) == args.workers, hosts
        df = spark.read.option('header', True).schema('pais STRING, importe INT').csv('/workspace/datos/ventas.csv')
        total = df.groupBy('pais').agg(F.sum('importe').alias('total'))
        actual = {row.pais: row.total for row in total.collect()}
        assert actual == {'ES': 30, 'FR': 12}, actual
        dest = '/workspace/salidas/comprobacion_ventas'
        total.write.mode('overwrite').parquet(dest)
        assert spark.read.parquet(dest).count() == 2
        print(json.dumps({'resultado': 'OK', 'arquitectura': platform.machine(), 'spark': spark.version, 'workers': len(alive), 'hosts_ejecutores': sorted(set(hosts)), 'ventas': actual}, ensure_ascii=False))
    finally:
        spark.stop()

if __name__ == '__main__':
    main()
