# Spark en MacBook Air M4 · 24 GB

Stack docente basado en [Spark SBD del IES Ataúlfo Argenta](https://iesataulfoargentasor.github.io/spark-cluster-docker-sbd/), adaptado a Apple Silicon. Incluye Spark 4.0.1, Java 17, Python y JupyterLab 4.4.9 en una imagen común para todos los servicios.

**[Guía web paso a paso](https://iesataulfoargentasor.github.io/spark-cluster-mac-m4/)** · **[Descargar ZIP](https://github.com/iesataulfoargentasor/spark-cluster-mac-m4/archive/refs/heads/main.zip)**

## Qué vas a montar

```text
MacBook Air M4 (24 GB)
└── Docker Desktop: máquina Linux ARM64
    ├── spark-master: asigna recursos
    ├── spark-worker-1: 2 núcleos y 2 GiB para Spark
    ├── spark-worker-2: 2 núcleos y 2 GiB para Spark
    └── jupyter: cuadernos y driver de la aplicación
        Todos comparten /workspace
```

Un worker aloja un executor con 2 núcleos y 2 GiB de heap. Con dos workers hay hasta cuatro tareas simultáneas. Los contenedores de cada worker tienen un límite de 4 GiB para dejar espacio a Python, la JVM y el servicio; no son 4 GiB de heap Spark. Master y Jupyter tienen límites de 1 y 2 GiB. Son límites, no memoria reservada continuamente.

La plataforma se fija en `linux/arm64`: en el M4 no requiere emular Intel. Spark utiliza la CPU; esta práctica no utiliza la GPU ni el Neural Engine. Todos los nodos comparten el mismo portátil: no es un clúster de máquinas físicas independientes.

## 1. Preparar Docker Desktop

1. Instala [Docker Desktop para Mac con Apple Silicon](https://docs.docker.com/desktop/setup/install/mac-install/) y ábrelo.
2. En Settings → Resources, toma como punto de partida **12 GB de RAM y 6 CPU** para Docker. Deja el resto de la memoria para macOS y tus aplicaciones. Si tu versión permite elegir el sistema de carpetas compartidas, utiliza VirtioFS.
3. Reserva unos **10 GB libres** para imagen, caché y prácticas pequeñas. La primera preparación necesita Internet.
4. Abre Terminal. Si tienes Git, descarga el proyecto con estos comandos. Si macOS pide instalar las herramientas de línea de comandos de Apple al ejecutar Git, acepta la instalación y repite después.

```bash
mkdir -p ~/Proyectos
cd ~/Proyectos
git clone https://github.com/iesataulfoargentasor/spark-cluster-mac-m4.git
cd spark-cluster-mac-m4
docker version
docker compose version
```

También puedes descargar el ZIP desde el enlace inicial, descomprimirlo y abrir Terminal en la carpeta que contiene `compose.yaml`. La carpeta del ZIP puede llamarse `spark-cluster-mac-m4-main`; usa su nombre real. Evita iCloud Drive y otras carpetas sincronizadas. Ejecuta todos los comandos siguientes dentro de la carpeta del proyecto.

Docker debe mostrar Client y Server. Necesitas Compose 2.20 o posterior. No hace falta instalar Python, Java o Spark en macOS. Docker Desktop ejecuta contenedores Linux en su máquina virtual; ARM64 evita la emulación de instrucciones Intel.

## 2. Preparar la imagen una vez

```bash
bash preparar.sh
```

El asistente crea `.env` con tu UID/GID, conserva un `.env` existente y construye la imagen. No necesita `sudo`. Puede tardar varios minutos. Si ya tienes `.env`, revisa que `LOCAL_UID` y `LOCAL_GID` coincidan con `id -u` e `id -g`.

La imagen oficial de Spark está fijada por versión y digest del índice multiplataforma. Docker selecciona ARM64 al construir. Las dependencias transitivas de Jupyter y los paquetes del sistema no están completamente fijados.

## 3. Arrancar

Perfil recomendado para tus 24 GB:

```bash
docker compose --profile spark up -d --wait --wait-timeout 300
docker compose --profile "*" ps
```

Arranca master, dos workers y Jupyter. Para trabajar con menos consumo puedes elegir el perfil `spark-single`, con un solo worker. Para cambiar entre perfiles, primero ejecuta `docker compose --profile "*" down` y luego el `up` del perfil elegido. Los archivos de `workspace` se conservan.

## 4. Abrir las interfaces

| Interfaz | Dirección | Uso |
|---|---|---|
| JupyterLab | http://localhost:8888 | Token inicial: `sbd-spark` |
| Master | http://localhost:8080 | Debe mostrar dos workers ALIVE |
| Worker 1 | http://localhost:8081 | Executor y recursos |
| Worker 2 | http://localhost:8082 | Sólo en perfil completo |
| Spark UI | http://localhost:4040 | Sólo mientras exista una aplicación activa |

Si esos puertos están ocupados por el stack anterior, cambia sus valores en `.env` y repite `up`. No cambies los puertos internos ni los nombres de servicio. Las interfaces se publican únicamente en tu propio equipo (127.0.0.1).

## 5. Comprobar ARM64 y el clúster

Antes de abrir sesiones en los cuadernos:

```bash
docker compose exec -T jupyter python /workspace/comprobar_cluster.py --workers 2
```

En modo ligero, usa `--workers 1`. La prueba exige arquitectura `aarch64` tanto en el driver como en los procesos Python de los executors. Comprueba los workers, ejecuta tareas en todos ellos, suma el CSV y escribe y recupera Parquet. El resultado debe incluir `"resultado": "OK"`, `"arquitectura": "aarch64"`, y ventas ES=30, FR=12.

En el perfil completo deben aparecer `spark-worker-1` y `spark-worker-2`. Esta prueba ocupa los cuatro núcleos del clúster simultáneamente; cierra cualquier otra sesión Spark antes de ejecutarla.

## 6. Trabajar con el cuaderno

Abre `notebooks/01_Primer_cluster.ipynb` en Jupyter, guarda una copia y ejecuta las celdas en orden. La sesión ya utiliza `spark://spark-master:7077`. No añadas `.master("local[*]")`: dejarías de utilizar los workers.

El driver está en `jupyter`, desde donde los executors pueden contactar con él. Ejecuta Python desde ese contenedor, no desde una instalación de Python del Mac. Usa rutas `/workspace/...`, no `/Users/...`.

Los cuadernos, CSV y resultados se guardan en `workspace/` del Mac. Los cuatro contenedores ven esa carpeta en la misma ruta. Cierra la aplicación con `spark.stop()` antes de abrir otra; la configuración se ha dimensionado para una aplicación a la vez.

## 7. Parar y volver a trabajar

```bash
docker compose --profile "*" stop
```

Para reanudar:

```bash
docker compose --profile spark up -d --wait --wait-timeout 300
```

Para retirar contenedores y red, conservando los archivos:

```bash
docker compose --profile "*" down
```

Después de reiniciar tendrás que crear otra SparkSession. La memoria de la aplicación no se conserva. Al terminar las prácticas, parar el stack reduce consumo y calentamiento del portátil.

## 8. Utilizarlo sin Internet

Construye la imagen y completa la comprobación con conexión antes de desconectarte. Después:

```bash
docker compose --profile spark up -d --no-build --pull never --wait --wait-timeout 300
```

El cuaderno y el CSV incluidos son locales. Otros ejercicios que descarguen paquetes, datos o conectores externos necesitarán preparación adicional. No copies una imagen Intel del otro ordenador: construye la imagen ARM64 en el Mac.

## 9. Si aparece un error

```bash
docker compose --profile "*" ps -a
docker compose logs --tail 100 spark-master spark-worker-1 spark-worker-2 jupyter
```

- **Docker no responde:** abre Docker Desktop y comprueba que `docker version` incluye Server.
- **No puedes guardar o aparece Mounts denied:** comprueba que la carpeta esté compartida con Docker y sea escribible por tu usuario. Revisa `.env`; si cambias UID/GID, reconstruye con `docker compose build jupyter` y recrea con `up`.
- **Arquitectura x86_64:** revisa que no hayas quitado `platform: linux/arm64` ni utilizado una imagen Intel. El stack incluye una comprobación explícita de arquitectura.
- **Sin recursos / OOMKilled:** cierra otras aplicaciones o cambia al perfil `spark-single`. Deja margen de memoria para Docker y macOS.
- **La prueba espera:** termina las otras sesiones Spark. Comprueba los workers ALIVE y que `--workers` coincide con el perfil.
- **No aparece 4040:** crea primero una SparkSession; desaparece al ejecutar `spark.stop()`.

## Validación y procedencia

Consulta [VALIDACION.txt](VALIDACION.txt) para distinguir las comprobaciones realizadas aquí de la prueba que debes ejecutar en tu Mac. El proyecto original está en https://github.com/iesataulfoargentasor/spark-cluster-docker-sbd (base b0b2f0bf0c1f5238a4d3cc527603539420bc12de). Se conserva su licencia MIT.

Fuentes oficiales: [instalación de Docker en Mac](https://docs.docker.com/desktop/setup/install/mac-install/) y [configuración de recursos](https://docs.docker.com/desktop/settings-and-maintenance/settings/). Los 12 GB/6 CPU son el dimensionamiento propuesto para esta práctica, no un requisito universal de Docker.

## Actualizar una copia existente

Si ya lo clonaste y hay cambios publicados, guarda tu cuaderno, detén el stack y ejecuta:

```bash
docker compose --profile "*" stop
git pull --ff-only
bash preparar.sh
docker compose --profile spark up -d --wait --wait-timeout 300
```

Si acabas de clonarlo, ya tienes la última versión y no necesitas hacer este paso.
Si lo descargaste como ZIP, descarga el ZIP nuevo en otra carpeta y conserva tus cuadernos
antes de trasladarlos. La actualización no requiere borrar datos de Docker.
