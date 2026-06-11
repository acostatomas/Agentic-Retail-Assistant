# Lab1 - Inventory Pipeline Setup

### Para Windows

Usa el archivo batch (recomendado - funciona en cualquier PC sin configuración):

```cmd
cd Lab1/inventory-pipeline
.\setup.bat
```

### Para Linux/Mac

Usa el script Bash:

```bash
cd Lab1/inventory-pipeline
./setup.sh
```

## Opciones de Uso

### 1. Ejecutar todos los pasos (default)

**Windows (Batch):**
```cmd
.\setup.bat
```
**Bash:**
```bash
./setup.sh
```

### 2. Ejecutar un paso individual

**Windows (Batch):**
```cmd
.\setup.bat -Step 1    # Solo crear el tópico inventory.transactions
.\setup.bat -Step 2    # Solo crear el stream y tabla de ksqlDB
.\setup.bat -Step 3    # Solo producir los 20 mensajes
```

**Bash:**
```bash
./setup.sh -s 1    # Solo crear el tópico inventory.transactions
./setup.sh -s 2    # Solo crear el stream y tabla de ksqlDB
./setup.sh -s 3    # Solo producir los 20 mensajes
```

### 3. Cleanup antes de ejecutar

**Windows (Batch):**
```cmd
.\setup.bat -CleanupExe              # Limpia y ejecuta todos los pasos
.\setup.bat -CleanupExe -Step 1      # Limpia y ejecuta solo el paso 1
```

**Bash:**
```bash
./setup.sh -c        # Limpia y ejecuta todos los pasos
./setup.sh -c -s 1   # Limpia y ejecuta solo el paso 1
```

### 4. Solo cleanup (sin ejecutar pasos)

**Windows (Batch):**
```cmd
.\setup.bat -Cleanup
```

**Bash:**
```bash
./setup.sh -C
```

## Tabla de Equivalencias

| Bash | Windows Batch | Windows PowerShell | Descripción |
|------|---------------|-------------------|-------------|
| `./setup.sh` | `setup.bat` | `.\setup.bat` | Ejecuta los 3 pasos |
| `./setup.sh -s 1` | `setup.bat -Step 1` | `.\setup.bat -Step 1` | Solo paso 1 (crear tópico) |
| `./setup.sh -s 2` | `setup.bat -Step 2` | `.\setup.bat -Step 2` | Solo paso 2 (crear stream/tabla) |
| `./setup.sh -s 3` | `setup.bat -Step 3` | `.\setup.bat -Step 3` | Solo paso 3 (producir mensajes) |
| `./setup.sh -c` | `setup.bat -CleanupExe` | `.\setup.bat -CleanupExe` | Limpia y ejecuta todo |
| `./setup.sh -C` | `setup.bat -Cleanup` | `.\setup.bat -Cleanup` | Solo limpia |
| `./setup.sh -c -s 1` | `setup.bat -CleanupExe -Step 1` | `.\setup.bat -CleanupExe -Step 1` | Limpia y ejecuta paso 1 |


## Más información

Ver el tutorial completo en: [Lab1/tutorial.md](../tutorial.md)