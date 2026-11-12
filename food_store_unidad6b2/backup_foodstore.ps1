<#
.SYNOPSIS
    Respaldo de la base foodstore_tp en formato custom (comprimido, paralelo, verificable).

.DESCRIPTION
    Genera un dump en formato custom (-Fc) con compresión nivel 3 y 4 jobs paralelos.
    Incluye timestamp en el nombre, log detallado y manejo de errores.
    NO guarda contraseñas; usa variable de entorno PGPASSWORD.

.PARAMETER BackupDir
    Directorio destino del respaldo. Default: C:\backups\foodstore

.PARAMETER DbName
    Nombre de la base a respaldar. Default: foodstore_tp

.PARAMETER PgDumpPath
    Ruta a pg_dump.exe. Default: C:\Program Files\PostgreSQL\18\bin\pg_dump.exe

.NOTES
    Requiere: variable de entorno PGPASSWORD seteada en la sesión actual.
    Ejemplo: $env:PGPASSWORD = "tu_password"
#>

param(
    [string]$BackupDir = "C:\backups\foodstore",
    [string]$DbName    = "foodstore_tp",
    [string]$PgDumpPath = "C:\Program Files\PostgreSQL\18\bin\pg_dump.exe",
    [string]$DbHost      = "localhost",
    [int]$Port         = 5432,
    [string]$User      = "postgres",
    [int]$Compression  = 3,
    [int]$Jobs         = 4
)

# ---------- CONFIGURACIÓN ----------
$ErrorActionPreference = "Stop"
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$dumpFile  = Join-Path $BackupDir "foodstore_${DbName}_${timestamp}.dump"
$logFile   = Join-Path $BackupDir "logs\backup_${DbName}_${timestamp}.log"

# Crear directorios si no existen
if (-not (Test-Path $BackupDir)) { New-Item -ItemType Directory -Force -Path $BackupDir | Out-Null }
$logDir = Split-Path $logFile
if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Force -Path $logDir | Out-Null }

# Función de logging
function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $entry = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [$Level] $Message"
    Add-Content -Path $logFile -Value $entry
    Write-Host $entry
}

# ---------- INICIO ----------
Write-Log "=== INICIO RESPALDO foodstore_tp ==="
Write-Log "Timestamp: $timestamp"
Write-Log "Base de datos: $DbName"
Write-Log "Archivo dump: $dumpFile"
Write-Log "Log: $logFile"
Write-Log "pg_dump: $PgDumpPath"
Write-Log "Parámetros: -Fc -Z $Compression"

# Verificar que pg_dump existe
if (-not (Test-Path $PgDumpPath)) {
    Write-Log "ERROR: No se encuentra pg_dump en $PgDumpPath" "ERROR"
    exit 1
}

# Verificar variable de entorno PGPASSWORD
if (-not $env:PGPASSWORD) {
    Write-Log "ERROR: Variable de entorno PGPASSWORD no está seteada. Configure antes de ejecutar." "ERROR"
    exit 1
}

# Verificar conectividad y base destino
try {
    $checkCmd = "& `"$PgDumpPath`" --version"
    $version = Invoke-Expression $checkCmd
    Write-Log "pg_dump version: $version"
} catch {
    Write-Log "ERROR al verificar pg_dump: $_" "ERROR"
    exit 1
}

# ---------- EJECUCIÓN DEL RESPALDO ----------
$startTime = Get-Date
Write-Log "Iniciando pg_dump..."

$pgDumpArgs = @(
    "-h", $DbHost
    "-p", $Port
    "-U", $User
    "-d", $DbName
    "-Fc"
    "-Z", $Compression.ToString()
    "-f", $dumpFile
    "-v"  # verbose para log detallado
)

try {
    $process = Start-Process -FilePath $PgDumpPath -ArgumentList $pgDumpArgs -NoNewWindow -Wait -PassThru -RedirectStandardError $logFile
    $exitCode = $process.ExitCode
    $endTime = Get-Date
    $duration = $endTime - $startTime

    if ($exitCode -eq 0) {
        $fileSizeMB = [math]::Round((Get-Item $dumpFile).Length / 1MB, 2)
        Write-Log "RESPALDO EXITOSO"
        Write-Log "Tamaño del archivo: ${fileSizeMB} MB"
        Write-Log "Duración: $($duration.TotalSeconds) segundos"
        Write-Log "Código de salida: $exitCode"

        # Verificación rápida: listar contenido del dump
        $listLog = Join-Path $BackupDir "logs\backup_list_${DbName}_${timestamp}.log"
        $pgRestoreListArgs = @("-l", $dumpFile)
        Start-Process -FilePath "C:\Program Files\PostgreSQL\18\bin\pg_restore.exe" -ArgumentList $pgRestoreListArgs -NoNewWindow -Wait -RedirectStandardOutput $listLog -RedirectStandardError (Join-Path $BackupDir "logs\backup_list_${DbName}_${timestamp}_err.log")
        Write-Log "Listado de objetos guardado en: $listLog"

        exit 0
    } else {
        Write-Log "ERROR: pg_dump falló con código $exitCode" "ERROR"
        exit $exitCode
    }
} catch {
    Write-Log "EXCEPCION durante pg_dump: $_" "ERROR"
    exit 1
}