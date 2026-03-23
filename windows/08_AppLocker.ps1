. "Z:\FUNCIONES\instalacion.ps1"
verificar_instalacion -pak "RSAT-AD-PowerShell"
verificar_instalacion -pak "GPMC"
Import-Module ActiveDirectory
Import-Module GroupPolicy

$dominio = "DC=practica,DC=local"
$gpoName = "AppLocker-Politicas"
$xmlPath = "Z:\windows\AppLockerPolicy.xml"

$hashNotepadW10    = "0x0C386FA6ABFDEFFBBEFF5BCE97D461340A23D1981458607BD9E5EEFF4066789A"
$hashNotepadW10Len = "201216"

function Crear-AppLocker {
    $sidCuates   = (Get-ADGroup -Identity "Cuates").SID.Value
    $sidNoCuates = (Get-ADGroup -Identity "NoCuates").SID.Value

    if (-not (Get-GPO -Name $gpoName -ErrorAction SilentlyContinue)) {
        New-GPO -Name $gpoName | Out-Null
        Write-Host "GPO creada: $gpoName"
    } else {
        Write-Host "GPO ya existe: $gpoName"
    }

    $xml = @"
<AppLockerPolicy Version="1">
  <RuleCollection Type="Exe" EnforcementMode="Enabled">

    <FilePathRule Id="fd686d83-a829-4351-8ff4-27c7de5755d2"
                  Name="Permitir todo a Administradores"
                  Description=""
                  UserOrGroupSid="S-1-5-32-544"
                  Action="Allow">
      <Conditions>
        <FilePathCondition Path="%WINDIR%\*"/>
      </Conditions>
    </FilePathRule>

    <FilePathRule Id="a2e5b3c1-1234-4abc-8def-aabbccddeeff"
                  Name="Cuates - Permitir Bloc de Notas"
                  Description=""
                  UserOrGroupSid="$sidCuates"
                  Action="Allow">
      <Conditions>
        <FilePathCondition Path="%SYSTEM32%\notepad.exe"/>
      </Conditions>
    </FilePathRule>

    <FileHashRule Id="b3f6a2d4-5678-4bcd-9abc-000000000002"
                  Name="NoCuates - Bloquear Bloc de Notas por Hash"
                  Description=""
                  UserOrGroupSid="$sidNoCuates"
                  Action="Deny">
      <Conditions>
        <FileHashCondition>
          <FileHash Type="SHA256"
                    Data="$hashNotepadW10"
                    SourceFileName="notepad.exe"
                    SourceFileLength="$hashNotepadW10Len"/>
        </FileHashCondition>
      </Conditions>
    </FileHashRule>

  </RuleCollection>
</AppLockerPolicy>
"@

    $xml | Out-File -FilePath $xmlPath -Encoding UTF8
    Write-Host "XML generado en: $xmlPath"

    Set-AppLockerPolicy -XmlPolicy $xmlPath -Merge
    Write-Host "Politica AppLocker aplicada."

    foreach ($uo in @("Cuates", "NoCuates")) {
        try {
            New-GPLink -Name $gpoName -Target "OU=$uo,$dominio" -ErrorAction Stop | Out-Null
            Write-Host "GPO vinculada a OU: $uo"
        } catch {
            Write-Host "GPO ya vinculada a: $uo"
        }
    }

    sc.exe config AppIDSvc start= auto | Out-Null
    sc.exe start AppIDSvc | Out-Null
    Write-Host "Servicio AppIDSvc iniciado."
    Write-Host "AppLocker configurado correctamente."
}

function Ver-AppLocker {
    Write-Host ""
    $pol = Get-AppLockerPolicy -Effective
    foreach ($col in $pol.RuleCollections) {
        Write-Host "Coleccion: $($col.RuleCollectionType) - Modo: $($col.EnforcementMode)"
        foreach ($rule in $col) {
            Write-Host "  Regla: $($rule.Name) | Accion: $($rule.Action) | SID: $($rule.UserOrGroupSid)"
        }
    }
}

function Show-Menu-AppLocker {
    Clear-Host
    Write-Host "============================================================"
    Write-Host "        APPLOCKER - CONTROL DE EJECUCION"
    Write-Host "============================================================"
    Write-Host ""
    Write-Host "  Cuates   : Bloc de Notas PERMITIDO (regla de path)"
    Write-Host "  NoCuates : Bloc de Notas BLOQUEADO (regla de hash)"
    Write-Host "             El bloqueo persiste aunque renombren el .exe"
    Write-Host ""
    Write-Host "  [1]  Crear y aplicar politicas AppLocker"
    Write-Host "  [2]  Ver politicas efectivas"
    Write-Host "  [0]  Volver al menu principal"
    Write-Host ""
    Write-Host "============================================================"
}

do {
    Show-Menu-AppLocker
    $op = Read-Host "Selecciona una opcion"

    switch ($op) {
        "1" { Crear-AppLocker }
        "2" { Ver-AppLocker }
        "0" { Write-Host "Volviendo al menu principal..." }
        default { Write-Host "Opcion invalida." }
    }

    if ($op -ne "0") {
        Write-Host ""
        Read-Host "Presiona ENTER para continuar"
    }

} while ($op -ne "0")