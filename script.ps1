function Check-Letter {
    param([string]$Letter)
    if (-not $Letter) { throw "Aucune lettre fournie." }
    $Letter = $Letter.Trim().ToUpper()
    if ($Letter -notmatch '^[A-Z]$') { throw "La lettre doit etre un seul caractere A-Z." }
    return $Letter
}

function Get-PathFromServer {
    param([string]$Server)
    if (-not $Server) { throw "Aucun serveur fourni." }
    return "\\$Server\"
}

function Is-Letter-InUse {
    param([string]$Letter)
    try {
        $drv = Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Name -eq $Letter }
        return [bool]$drv
    } catch {
        $out = net use | Select-String "^[A-Z]:"
        return $out -match ("^${Letter}:")
    }
}

function Map-Drive {
    param(
        [string]$Letter,
        [string]$Path,
        [string]$User
    )
    try {
        $Letter = Check-Letter $Letter
        if (-not $Path) { throw "Path vide." }

        if (Is-Letter-InUse -Letter $Letter) {
            Write-Host "La lettre ${Letter}: est deja utilisee."
            $replace = Read-Host "Souhaitez-vous supprimer l'emplacement existant et le remplacer ? (O/N)"
            if ($replace -ne "O") {
                Write-Host "Abandon de la connexion."
                return
            }
            Remove-Drive -Letter $Letter -Force
        }

        Write-Host "Connexion ${Letter}: -> $Path ..."
        net use "${Letter}:" ${Path} /user:$User /persistent:yes
        if ($LASTEXITCODE -ne 0) {
            Write-Host "Erreur lors du montage !" -ForegroundColor Red
            Write-Host $result
            Write-Host "Si le probleme persiste, veuillez reessayer avec l'addresse IP de la cible !"
            Write-Host "${IpTarget}"
        } else {
            Write-Host "Connexion reussie !" -ForegroundColor Green
        }
    } catch {
        Write-Host "Erreur dans Map-Drive : $_" -ForegroundColor Red
    }
}

function Remove-Drive {
    param([string]$Letter)
    try {
        $Letter = Check-Letter $Letter
        if (-not (Is-Letter-InUse -Letter $Letter)) {
            Write-Host "La lettre ${Letter}: n'est pas utilisee."
            return
        }
        Write-Host "Suppression de ${Letter}: ..."
        $cmd = "net use ${Letter}: /delete /y"
        $result = cmd.exe /c $cmd 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Host "Erreur lors de la suppression :" -ForegroundColor Red
            Write-Host $result
        } else {
            Write-Host "Emplacement supprime !" -ForegroundColor Green
        }
    } catch {
        Write-Host "Erreur dans Remove-Drive : $_" -ForegroundColor Red
    }
}

function Show-Status {
    Write-Host "Lecteurs reseaux actuels :"
    Get-PSDrive -PSProvider FileSystem | Where-Object { $_.DisplayRoot -or $_.Root } | Format-Table -AutoSize
    Write-Host "`nSortie de 'net use' :"
    net use
}

function Show-Menu {
    Clear-Host
    $nowDate = Get-Date -Format "dd/MM/yyyy"
    $nowTime = Get-Date -Format "HH:mm:ss"
    $hostname = $env:COMPUTERNAME
    Write-Host " "
    Write-Host " "
    Write-Host "===============================" -ForegroundColor Cyan
    Write-Host " Date : " -NoNewline -ForegroundColor Yellow
    Write-Host "$nowDate" -ForegroundColor Green
    Write-Host " Heure : " -NoNewline -ForegroundColor Yellow
    Write-Host "$nowTime" -ForegroundColor Green
    Write-Host " Compte operateur : " -NoNewline -ForegroundColor Yellow
    Write-Host "$User" -ForegroundColor Magenta
    Write-Host " Hostname : " -NoNewline -ForegroundColor Yellow
    Write-Host "$hostname" -ForegroundColor Blue
    Write-Host "===============================" -ForegroundColor Cyan
    Write-Host "===== " -NoNewline -ForegroundColor Cyan 
    Write-Host "MENU Lecteur Reseau" -NoNewline -ForegroundColor Yellow
    Write-Host " ====="  -ForegroundColor Cyan
    Write-Host "1) Monter un lecteur"
    Write-Host "2) Supprimer un lecteur"
    Write-Host "3) Statut / Lister lecteurs"
    Write-Host "4) Definir / Changer la cible"
    Write-Host "5) Quitter"
    Write-Host "6) Credit"
    Write-Host "===============================" -ForegroundColor Cyan
    Write-Host "Current target : " -NoNewline
    Write-Host $Server -ForegroundColor Magenta
    Write-Host "IP : " -NoNewline
    Write-Host $IpTarget -ForegroundColor Magenta
    Write-Host ""
}

Write-Host " "
Write-Host " "
Write-Host "Bonjour !" -ForegroundColor Green
Write-Host " "
$User = Read-Host "Identifiant de votre compte (ex: REDACTED )"

# Vérification de l'existence de l'utilisateur dans le domaine
$checkUserCmd = "net user $User /domain" #laisser ou retirer domain selon votre envirronement
$userCheckResult = cmd.exe /c $checkUserCmd 2>&1
$userCheckResultText = $userCheckResult -join "`n"

if (
    $userCheckResultText -match "Le nom d'utilisateur est introuvable" -or
    $userCheckResultText -match "The user name could not be found" -or
    $userCheckResultText -match "Le domaine spécifié n'existe pas" -or
    $userCheckResultText -match "The specified domain either does not exist" -or
    $userCheckResultText -match "Le domaine spécifié n’existe pas ou n’a pas pu être contacté" -or
    $userCheckResultText -match "L’erreur système 1355 s’est produite"
) {
    Write-Host "L'utilisateur '$User' n'existe pas dans le domaine ou le domaine est inaccessible." -ForegroundColor Red
    Read-Host "Appuyez sur Entree pour continuer..."
    exit 1
} elseif ($userCheckResultText -match "Nom d'utilisateur" -or $userCheckResultText -match "User name") {
    Write-Host "Utilisateur '$User' trouve dans le domaine !" -ForegroundColor Green
    Start-Sleep -Seconds 3.5
} else {
    Write-Host "Impossible de determiner si l'utilisateur existe. Resultat brut :" -ForegroundColor Yellow
    Write-Host $userCheckResultText
    Read-Host "Appuyez sur Entree pour continuer..."
    exit 1
}
$Server = "Aucune Cible Definie"
$IpTarget = "Non resolu"

do {
    Show-Menu
    $choice = Read-Host "Choix (1-6)"
    switch ($choice) {
        "1" {
            try {
                $Letter = Read-Host "Lettre a associer (A-Z)"
                $Letter = Check-Letter $Letter
                Map-Drive -Letter $Letter -Path $Path -User $User
            } catch {
                Write-Host "Erreur : $_" -ForegroundColor Red
            }
            Read-Host "Appuyez sur Entree pour continuer..."
        }
        "2" {
            try {
                $Letter = Read-Host "Lettre du lecteur a supprimer (A-Z)"
                $Letter = Check-Letter $Letter
                Remove-Drive -Letter $Letter
            } catch {
                Write-Host "Erreur : $_" -ForegroundColor Red
            }
            Read-Host "Appuyez sur Entree pour continuer..."
        }
        "3" {
            Show-Status
            Read-Host "Appuyez sur Entree pour continuer..."
        }
        "4" {
    $Server = Read-Host "Nom/IP de la machine cible (ex: REDACTED )" 
    try {
        $Path = Get-PathFromServer -Server $Server
        # Résolution IP uniquement ici
        $IpTarget = ""
        try {
            $IpTarget = [System.Net.Dns]::GetHostAddresses($Server) | Select-Object -First 1
        } catch {
            $IpTarget = "Non resolu"
        }
    } catch {
        Write-Host "Erreur sur le serveur : $_" -ForegroundColor Red
        $IpTarget = ""
    }
}
        "5" {
            Write-Host ""
            Write-Host "Au revoir !" -ForegroundColor Cyan
            Write-Host ""
            exit
        }
        "6" {
            Clear-Host
            Write-Host "==============================================" -ForegroundColor Cyan
            Write-Host "      Script de gestion lecteur reseau       " -ForegroundColor White
            Write-Host "==============================================" -ForegroundColor Cyan

            Write-Host " Developpe par :   " -ForegroundColor Gray -NoNewline
            Write-Host "REDACTED" -ForegroundColor DarkYellow

            #Write-Host " Entreprise     :  " -ForegroundColor Gray -NoNewline
            #Write-Host "" -ForegroundColor DarkYellow

            Write-Host " Version        :  " -ForegroundColor Gray -NoNewline
            Write-Host "Unique" -ForegroundColor DarkYellow

            Write-Host " Date           :  " -ForegroundColor Gray -NoNewline
            Write-Host "REDACTED" -ForegroundColor DarkYellow

            Write-Host " Contact        :  " -ForegroundColor Gray -NoNewline
            Write-Host "REDACTED" -ForegroundColor DarkYellow

            Write-Host ""
            Read-Host "Appuyez sur Entree pour revenir au menu"

        }
        default {
            Write-Host "Choix invalide. Reessayez." -ForegroundColor Yellow
            Start-Sleep -Seconds 1
        }
    }
} while ($true)


