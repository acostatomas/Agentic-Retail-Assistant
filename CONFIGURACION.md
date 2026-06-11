# Guía de Configuración - Labs TechSummit

## 📍 Ubicación del archivo .env raíz

El script [`Lab1/inventory-pipeline/setup.ps1`](Lab1/inventory-pipeline/setup.ps1:44) busca un archivo `.env` en la **raíz del proyecto**, es decir:

```
C:/Users/tomas/Labs_TechSummit/.env
```

**Este archivo NO existe actualmente** y debes crearlo.

## 🔧 Cómo crear el archivo .env raíz

### Opción 1: Copiar desde Lab2 (Recomendado)

El archivo más completo está en [`Lab2/confluent_agents/.env`](Lab2/confluent_agents/.env), así que puedes copiarlo:

```powershell
# Desde PowerShell en C:/Users/tomas/Labs_TechSummit/
Copy-Item Lab2/confluent_agents/.env .env
```

### Opción 2: Crear manualmente

Crea un nuevo archivo llamado `.env` en `C:/Users/tomas/Labs_TechSummit/` con el siguiente contenido:

```env
# ---- Per-student settings (you must edit these) ----------------------------
# SSH target for your VM and path to your .pem key
SSH_HOST=root@YOUR_VM_IP
SSH_KEY=Lab1/inventory-pipeline/your-key.pem

# ---- Cluster endpoints ------------------------------------------------------
# Kafka broker address (internal cluster DNS)
BOOTSTRAP_SERVERS=kafka.confluent.svc.cluster.local:9092

# ksqlDB endpoint
# - For Lab1 (scripts running inside cluster): use internal DNS
# - For Lab2 (MCP from your machine): use external HTTPS URL
KSQLDB_ENDPOINT=http://ksqldb.confluent.svc.cluster.local:8088
KSQLDB_ENDPOINT_EXTERNAL=https://YOUR_VM_IP/ksqldb/

# ---- ksqlDB Authentication -------------------------------------------------
# Credentials for ksqlDB access
KSQLDB_USERNAME=admin
KSQLDB_PASSWORD=YOUR_KSQLDB_PASSWORD

# API credentials for Lab2 MCP tool (usually same as username/password)
KSQLDB_API_KEY=admin
KSQLDB_API_SECRET=YOUR_KSQLDB_PASSWORD

# ---- Kafka SASL Authentication (for port 9092) -----------------------------
KAFKA_SASL_USERNAME=kafka-admin
KAFKA_SASL_PASSWORD=YOUR_KAFKA_PASSWORD
KAFKA_SECURITY_PROTOCOL=SASL_SSL
KAFKA_SASL_MECHANISM=PLAIN

# ---- Lab1: Kafka Topics & ksqlDB Objects -----------------------------------
TOPIC_NAME=inventory.transactions
TOPIC_PARTITIONS=1
TOPIC_REPLICATION_FACTOR=3
TOPIC_RETENTION_MS=-1
DERIVED_TOPIC_NAME=inventory.availability
KSQL_STREAM_NAME=inventory_transactions
KSQL_TABLE_NAME=inventory_availability
```

## 🔑 Variables que necesitas configurar

### 1. SSH_HOST
**Dónde encontrarlo:** Este es el IP de tu VM proporcionado por el instructor.

**Formato:** `root@<IP_DE_TU_VM>`

**Ejemplo:** `root@192.168.1.100`

### 2. SSH_KEY
**Dónde encontrarlo:** Esta es la ruta relativa a tu archivo `.pem` de clave SSH.

**Formato:** `Lab1/inventory-pipeline/<nombre-de-tu-clave>.pem`

**Ejemplo:** `Lab1/inventory-pipeline/mi-clave.pem`

**Nota:** El archivo `.pem` debe estar en la carpeta `Lab1/inventory-pipeline/`

### 3. KSQLDB_PASSWORD
**Dónde encontrarlo:** Proporcionado por el instructor o en la documentación del cluster.

**También se usa para:** `KSQLDB_API_SECRET` (mismo valor)

### 4. KAFKA_SASL_PASSWORD
**Dónde encontrarlo:** Proporcionado por el instructor o en la documentación del cluster.

**Nota:** Este es diferente al password de ksqlDB.

## 📂 Estructura de archivos .env

```
Labs_TechSummit/
├── .env                              ← ARCHIVO RAÍZ (necesitas crearlo)
├── Lab1/
│   └── inventory-pipeline/
│       ├── setup.ps1                 ← Lee el .env raíz
│       └── your-key.pem              ← Tu clave SSH aquí
└── Lab2/
    └── confluent_agents/
        └── .env                      ← Configuración para Lab2
```

## 🔄 Relación entre los archivos .env

### `.env` raíz (C:/Users/tomas/Labs_TechSummit/.env)
- **Usado por:** [`Lab1/inventory-pipeline/setup.ps1`](Lab1/inventory-pipeline/setup.ps1)
- **Variables requeridas:** `SSH_HOST`, `SSH_KEY`
- **Variables opcionales pero recomendadas:** Todas las demás (para Lab2)

### `Lab2/confluent_agents/.env`
- **Usado por:** Scripts de Lab2 y agentes de Confluent
- **Variables requeridas:** `KSQLDB_PASSWORD`, `KSQLDB_API_SECRET`, `KAFKA_SASL_PASSWORD`

## ✅ Verificación

Después de crear el archivo `.env` raíz, verifica que:

1. ✅ El archivo existe en `C:/Users/tomas/Labs_TechSummit/.env`
2. ✅ Contiene las variables `SSH_HOST` y `SSH_KEY`
3. ✅ La ruta en `SSH_KEY` apunta a un archivo `.pem` existente
4. ✅ El archivo `.pem` tiene los permisos correctos (el script los ajustará automáticamente)

## 🚀 Siguiente paso

Una vez configurado el `.env` raíz, puedes ejecutar:

```powershell
cd Lab1/inventory-pipeline
.\setup.bat
```

El script automáticamente:
1. Leerá el `.env` raíz
2. Ajustará los permisos de tu clave SSH
3. Copiará los archivos necesarios a tu VM
4. Ejecutará los pasos del pipeline

## 📝 Notas importantes

- El `.env` raíz debe estar **dos niveles arriba** del script `setup.ps1`
- La ruta `SSH_KEY` es **relativa al directorio raíz** (Labs_TechSummit)
- Los valores `YOUR_VM_IP`, `YOUR_KSQLDB_PASSWORD`, y `YOUR_KAFKA_PASSWORD` deben ser reemplazados con tus credenciales reales
- **NO compartas** tu archivo `.env` ni tu clave `.pem` en repositorios públicos

## 🆘 Solución de problemas

### Error: ".env file not found"
**Causa:** El archivo `.env` no existe en la raíz del proyecto.

**Solución:** Crea el archivo en `C:/Users/tomas/Labs_TechSummit/.env`

### Error: "SSH_HOST not found in .env"
**Causa:** La variable `SSH_HOST` no está definida o está comentada.

**Solución:** Agrega la línea `SSH_HOST=root@<TU_IP>` al archivo `.env`

### Error: "SSH key not found"
**Causa:** La ruta en `SSH_KEY` no apunta a un archivo existente.

**Solución:** Verifica que el archivo `.pem` existe en la ruta especificada.

### Error de permisos SSH
**Causa:** La clave SSH tiene permisos incorrectos.

**Solución:** El script [`setup.ps1`](Lab1/inventory-pipeline/setup.ps1:84-97) ajusta automáticamente los permisos usando `icacls`.