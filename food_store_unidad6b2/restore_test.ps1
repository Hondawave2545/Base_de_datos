<#
.SYNOPSIS
    Automatizacion de la restauracion del respaldo de foodstore_tp en foodstore_restore_test
    y validacion completa de integridad.

.DESCRIPTION
    1. Crea/elimina base foodstore_restore_test
    2. Restaura el dump mas reciente (o especificado) con pg_restore en paralelo
    3. Ejecuta validaciones de conteo, restricciones logicas e integridad referencial
    4. Mide RTO (tiempo total restauracion + validacion)
    5. Genera log detallado y reporte de resultados

.NOTES
    - NO restaura sobre foodstore_tp (produccion)
    - Requiere: variable de entorno PGPASSWORD seteada
    - El dump debe existir en el directorio de respaldos
#>

param(
    [string]$BackupDir     = "C:\backups\foodstore",
    [string]$TargetDb      = "foodstore_restore_test",
    [string]$SourceDb      = "foodstore_tp",
    [string]$PgRestorePath = "C:\Program Files\PostgreSQL\18\bin\pg_restore.exe",
    [string]$PsqlPath      = "C:\Program Files\PostgreSQL\18\bin\psql.exe",
    [string]$DbHost        = "localhost",
    [int]$Port             = 5432,
    [string]$User          = "postgres",
    [int]$Jobs             = 4,
    [string]$DumpFile      = ""
)

# CONFIGURACION
$ErrorActionPreference = "Stop"
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$logFile   = Join-Path $BackupDir "logs\restore_${TargetDb}_${timestamp}.log"
$resultsFile = Join-Path $BackupDir "logs\validation_${TargetDb}_${timestamp}.txt"

$logDir = Split-Path $logFile
if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Force -Path $logDir | Out-Null }

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $entry = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [$Level] $Message"
    Add-Content -Path $logFile -Value $entry
    Write-Host $entry
}

function Write-Result {
    param([string]$Message)
    Add-Content -Path $resultsFile -Value $Message
    Write-Host $Message
}

# INICIO
$overallStart = Get-Date
Write-Log "=== INICIO RESTAURACION Y VALIDACION ==="
Write-Log "Timestamp: $timestamp"
Write-Log "Base origen (respaldada): $SourceDb"
Write-Log "Base destino (test): $TargetDb"
Write-Log "Log: $logFile"
Write-Log "Resultados: $resultsFile"

if (-not $env:PGPASSWORD) {
    Write-Log "ERROR: PGPASSWORD no seteado" "ERROR"
    exit 1
}

# Buscar archivo dump
if (-not $DumpFile) {
    $dumps = Get-ChildItem -Path $BackupDir -Filter "foodstore_${SourceDb}_*.dump" | Sort-Object LastWriteTime -Descending
    if ($dumps.Count -eq 0) {
        Write-Log "ERROR: No se encontraron dumps para $SourceDb en $BackupDir" "ERROR"
        exit 1
    }
    $DumpFile = $dumps[0].FullName
    Write-Log "Usando dump mas reciente: $DumpFile"
} else {
    $DumpFile = Join-Path $BackupDir $DumpFile
    if (-not (Test-Path $DumpFile)) {
        Write-Log "ERROR: Dump especificado no existe: $DumpFile" "ERROR"
        exit 1
    }
}

$dumpSizeMB = [math]::Round((Get-Item $DumpFile).Length / 1MB, 2)
Write-Log "Tamano dump: ${dumpSizeMB} MB"
Write-Log "Fecha dump: $(Get-Item $DumpFile).LastWriteTime"

foreach ($tool in @($PgRestorePath, $PsqlPath)) {
    if (-not (Test-Path $tool)) {
        Write-Log "ERROR: No se encuentra $tool" "ERROR"
        exit 1
    }
}

# 1. PREPARAR BASE DESTINO
Write-Log "--- Paso 1: Preparar base destino $TargetDb ---"

$terminateSql = @"
SELECT pg_terminate_backend(pid)
FROM pg_stat_activity
WHERE datname = '$TargetDb' AND pid <> pg_backend_pid();
"@

try {
    & $PsqlPath -h $DbHost -p $Port -U $User -d postgres -c $terminateSql 2>&1 | ForEach-Object { Write-Log $_ }
} catch {
    Write-Log "Advertencia al terminar conexiones: $_" "WARN"
}

$dropSql = "DROP DATABASE IF EXISTS $TargetDb;"
& $PsqlPath -h $DbHost -p $Port -U $User -d postgres -c $dropSql 2>&1 | ForEach-Object { Write-Log $_ }

$createSql = "CREATE DATABASE $TargetDb OWNER $User;"
& $PsqlPath -h $DbHost -p $Port -U $User -d postgres -c $createSql 2>&1 | ForEach-Object { Write-Log $_ }
Write-Log "Base $TargetDb creada."

# 2. RESTAURAR CON PG_RESTORE
Write-Log "--- Paso 2: Restaurando dump con pg_restore -j $Jobs ---"
$restoreStart = Get-Date

$restoreArgs = @(
    "-h", $DbHost
    "-p", $Port
    "-U", $User
    "-d", $TargetDb
    "-j", $Jobs.ToString()
    "-v"
    $DumpFile
)

try {
    $process = Start-Process -FilePath $PgRestorePath -ArgumentList $restoreArgs -NoNewWindow -Wait -PassThru -RedirectStandardError $logFile
    $exitCode = $process.ExitCode
    $restoreEnd = Get-Date
    $restoreDuration = $restoreEnd - $restoreStart

    if ($exitCode -ne 0) {
        Write-Log "ERROR: pg_restore fallo con codigo $exitCode" "ERROR"
        exit 1
    }

    Write-Log "RESTAURACION EXITOSA"
    Write-Log "Duracion restauracion: $($restoreDuration.TotalSeconds) segundos"
} catch {
    Write-Log "EXCEPCION durante pg_restore: $_" "ERROR"
    exit 1
}

# 3. VALIDACIONES POST-RESTAURACION
Write-Log "--- Paso 3: Ejecutando validaciones ---"
$validationStart = Get-Date

$validationSql = @"
\set ON_ERROR_STOP on
\echo '=== VALIDACIONES POST-RESTAURACION ==='
\echo 'Base:' current_database()
\echo 'Timestamp:' now()
\echo ''

-- 1. CONTEOS DE FILAS
\echo '--- 1. CONTEOS DE FILAS ---'
SELECT 'categorias' AS tabla, count(*) FROM categorias
UNION ALL SELECT 'sucursales', count(*) FROM sucursales
UNION ALL SELECT 'empleados', count(*) FROM empleados
UNION ALL SELECT 'clientes', count(*) FROM clientes
UNION ALL SELECT 'productos', count(*) FROM productos
UNION ALL SELECT 'pedidos', count(*) FROM pedidos
UNION ALL SELECT 'detalle_pedido', count(*) FROM detalle_pedido
UNION ALL SELECT 'pagos', count(*) FROM pagos
ORDER BY tabla;

-- 2. VALIDACIONES LOGICAS (deben ser 0)
\echo ''
\echo '--- 2. VALIDACIONES LOGICAS (esperado: 0) ---'
SELECT 'detalle_pedido cantidad <= 0' AS check, count(*) FROM detalle_pedido WHERE cantidad <= 0
UNION ALL SELECT 'productos stock < 0', count(*) FROM productos WHERE stock < 0
UNION ALL SELECT 'pedidos total < 0', count(*) FROM pedidos WHERE total < 0
UNION ALL SELECT 'pagos monto < 0', count(*) FROM pagos WHERE monto < 0
UNION ALL SELECT 'clientes email duplicados', count(*) - count(DISTINCT email) FROM clientes
UNION ALL SELECT 'empleados dni duplicados', count(*) - count(DISTINCT dni) FROM empleados
UNION ALL SELECT 'productos precio < 0', count(*) FROM productos WHERE precio < 0;

-- 3. INTEGRIDAD REFERENCIAL (FK)
\echo ''
\echo '--- 3. INTEGRIDAD REFERENCIAL ---'
SELECT 'pedidos.id_cliente -> clientes' AS fk, count(*) AS huerfanos
FROM pedidos p LEFT JOIN clientes c ON c.id_cliente = p.id_cliente WHERE c.id_cliente IS NULL
UNION ALL SELECT 'pedidos.id_sucursal -> sucursales', count(*)
FROM pedidos p LEFT JOIN sucursales s ON s.id_sucursal = p.id_sucursal WHERE s.id_sucursal IS NULL
UNION ALL SELECT 'pedidos.id_empleado_repartidor -> empleados', count(*)
FROM pedidos p LEFT JOIN empleados e ON e.id_empleado = p.id_empleado_repartidor WHERE p.id_empleado_repartidor IS NOT NULL AND e.id_empleado IS NULL
UNION ALL SELECT 'detalle_pedido.id_pedido -> pedidos', count(*)
FROM detalle_pedido d LEFT JOIN pedidos p ON p.id_pedido = d.id_pedido WHERE p.id_pedido IS NULL
UNION ALL SELECT 'detalle_pedido.id_producto -> productos', count(*)
FROM detalle_pedido d LEFT JOIN productos pr ON pr.id_producto = d.id_producto WHERE pr.id_producto IS NULL
UNION ALL SELECT 'pagos.id_pedido -> pedidos', count(*)
FROM pagos pg LEFT JOIN pedidos p ON p.id_pedido = pg.id_pedido WHERE p.id_pedido IS NULL
UNION ALL SELECT 'productos.id_categoria -> categorias', count(*)
FROM productos p LEFT JOIN categorias c ON c.id_categoria = p.id_categoria WHERE c.id_categoria IS NULL
UNION ALL SELECT 'empleados.id_sucursal -> sucursales', count(*)
FROM empleados e LEFT JOIN sucursales s ON s.id_sucursal = e.id_sucursal WHERE s.id_sucursal IS NULL;

-- 4. VISTAS Y MV
\echo ''
\echo '--- 4. VISTAS Y MV ---'
SELECT 'v_productos_vigentes' AS objeto, count(*) FROM v_productos_vigentes
UNION ALL SELECT 'v_pedidos_cliente', count(*) FROM v_pedidos_cliente
UNION ALL SELECT 'v_detalle_pedido', count(*) FROM v_detalle_pedido
UNION ALL SELECT 'v_clientes_publico', count(*) FROM v_clientes_publico
UNION ALL SELECT 'mv_facturacion_categoria_mes', count(*) FROM mv_facturacion_categoria_mes;

-- 5. FUNCIONES UNIDAD 5
\echo ''
\echo '--- 5. FUNCIONES AUTENTICACION ---'
SELECT proname, prosecdef FROM pg_proc
WHERE proname IN ('fn_autenticar','fn_resetear_password') AND pronamespace = 'public'::regnamespace;

-- 6. ROLES UNIDAD 5
\echo ''
\echo '--- 6. ROLES ---'
SELECT rolname, rolcanlogin FROM pg_roles
WHERE rolname IN ('rol_app_lectura','rol_app_escritura','rol_soporte','rol_reportes','rol_auditoria','app_web','admin_datos')
ORDER BY rolname;

\echo ''
\echo '=== FIN VALIDACIONES ==='
"@

try {
    & $PsqlPath -h $DbHost -p $Port -U $User -d $TargetDb -c $validationSql 2>&1 | Tee-Object -FilePath $resultsFile -Append | ForEach-Object { Write-Log $_ }
    Write-Log "Validaciones completadas. Resultados en: $resultsFile"
} catch {
    Write-Log "ERROR en validaciones: $_" "ERROR"
    exit 1
}

$validationEnd = Get-Date
$validationDuration = $validationEnd - $validationStart

# 4. CALCULO RTO / RPO
$overallEnd = Get-Date
$totalDuration = $overallEnd - $overallStart

$dumpTime = (Get-Item $DumpFile).LastWriteTime
$rpo = $overallStart - $dumpTime

Write-Log "--- METRICAS RPO / RTO ---"
Write-Log "RPO observado (antiguedad del respaldo): $($rpo.TotalHours) horas ($($rpo.TotalMinutes) minutos)"
Write-Log "RTO observado (restauracion + validacion): $($totalDuration.TotalMinutes) minutos ($($totalDuration.TotalSeconds) segundos)"
Write-Log "  - Restauracion: $($restoreDuration.TotalSeconds) segundos"
Write-Log "  - Validacion: $($validationDuration.TotalSeconds) segundos"

Write-Result ""
Write-Result "=== RESUMEN RPO/RTO ==="
Write-Result "Fecha/hora respaldo: $($dumpTime)"
Write-Result "Fecha/hora inicio restauracion: $($overallStart)"
Write-Result "Fecha/hora fin validacion: $($overallEnd)"
Write-Result "RPO observado: $([math]::Round($rpo.TotalHours, 2)) horas"
Write-Result "RTO observado: $([math]::Round($totalDuration.TotalMinutes, 2)) minutos"
Write-Result "Tamano dump: ${dumpSizeMB} MB"

Write-Log "=== FIN RESTAURACION Y VALIDACION ==="
exit 0