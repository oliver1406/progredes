# Docker Desktop iniciado, com Linux containers.
$ErrorActionPreference = 'Stop'
$labArguments = @($args)
function Invoke-LabDocker {
    & docker @args
    if ($LASTEXITCODE -ne 0) { throw 'Docker não concluiu a operação. Confira o diagnóstico acima.' }
}
try {
    if (-not (Get-Command docker -ErrorAction SilentlyContinue)) { throw 'Instale e inicie Docker Desktop, com Linux containers e WSL 2.' }
    $labOs = & docker info --format '{{.OSType}}'
    if ($LASTEXITCODE -ne 0 -or $labOs -ne 'linux') { throw 'Inicie o Docker Desktop em modo Linux containers.' }
    $labBaseLines = @(Get-Content -LiteralPath (Join-Path $PSScriptRoot 'infra/images.lock.env') | Where-Object { $_ -match '^CI_BASE_IMAGE=' })
    if ($labBaseLines.Count -ne 1) { throw 'Lock inválido' }
    $labBase = $labBaseLines[0].Substring('CI_BASE_IMAGE='.Length)
    if ($labBase -notmatch '^[a-z0-9./_-]+@sha256:[a-f0-9]{64}$') { throw 'Lock inválido' }
    Invoke-LabDocker build --build-arg "BASE_IMAGE=$labBase" -t microlab-ops:local -f (Join-Path $PSScriptRoot 'infra/Dockerfile.ops') $PSScriptRoot
    & docker network inspect microlab-proxy *> $null
    if ($LASTEXITCODE -ne 0) { Invoke-LabDocker network create microlab-proxy }
    $labRun = @('run', '--rm', '--name', 'microlab-ops', '-i', '--network', 'microlab-proxy',
        '-e', 'MICROLAB_CONTAINER_MODE=1', '-e', 'ZBX_API_TOKEN', '-e', 'ZBX_USER',
        '-v', 'microlab-workspace:/workspace', '-v', 'microlab-backups:/workspace/backups',
        '-v', 'microlab-runtime-config:/runtime', '-v', '/var/run/docker.sock:/var/run/docker.sock')
    if (-not [Console]::IsInputRedirected -and -not [Console]::IsOutputRedirected) { $labRun += '-t' }
    if ($labArguments.Count -gt 0 -and $labArguments[0] -eq 'export') {
        if ($labArguments.Count -ne 3 -or $labArguments[2] -ne '--confirmed-idle') { throw 'Uso: ./microlab.ps1 export CAMINHO.tgz --confirmed-idle' }
        $labDestination = [IO.Path]::GetFullPath($labArguments[1])
        if (Test-Path -LiteralPath $labDestination) { throw 'Destino já existe; escolha outro arquivo' }
        Invoke-LabDocker @labRun microlab-ops:local export --confirmed-idle
        $labHelper = & docker create -v microlab-workspace:/workspace --entrypoint /bin/true microlab-ops:local
        if ($LASTEXITCODE -ne 0) { throw 'Falha ao preparar exportação' }
        try {
            [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($labDestination)) | Out-Null
            Invoke-LabDocker cp "${labHelper}:/workspace/export/recovery.tgz" $labDestination
        } finally { & docker rm $labHelper | Out-Null }
        Write-Host 'Arquivo exportado. Contém credenciais: mantenha privado.'
    } else {
        Invoke-LabDocker @labRun microlab-ops:local @labArguments
    }
} catch {
    Write-Error $_
    exit 1
}
