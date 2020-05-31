<#A powershell script to replace all words in files #>
Param(
    [Parameter(Mandatory, HelpMessage="The script will replace this old value.")]
    [string]$Old,
    [Parameter(Mandatory, HelpMessage="The script will replace the old value with this new value.")]
    [string]$New,
    [Parameter(HelpMessage="The script will only run for all direct files in the path and its subdirectories.")]
    [string]$StartPath="C:/",
    [Parameter(HelpMessage="The script will only be executed against the provided extensions. An empty array means that all extensions will be targeted.")]
    [array]$Extensions=@(),
    [Parameter(HelpMessage="The script will not be executed against the provided extensions.")]
    [array]$Exceptions=@()
)

# Here we explicitly execute the methods: first assert input, then execute the script
Assert-Input $Old $New $StartPath $Extensions $Exceptions
Write-Information "Input is successfully validated."
Start-Purge $Old $New $StartPath $Extensions $Exceptions
Write-Information "Files have successfully been purged."

function Assert-Input([string]$OldValue, [string]$NewValue, [string]$StartPath, [array]$Extensions, [array]$Exceptions) {
    Assert-ValidValues $Old $New
    Assert-ValidPath $StartPath
    Assert-ValidExtensions $Extensions $Exceptions
}

<#Asserts that the old and new value provided are valid.#>
function Assert-ValidValues([string]$OldValue, [string]$NewValue) {
    if($OldValue -eq $NewValue) {
        Write-Error "Old value is the same as the new value. Script doesn't bother executing."
        Exit -1
    }
    if(!$OldValue) {
        Write-Error "Old value cannot be empty!"
        Exit -1
    }    
}

<#Asserts that the path provided exists.#>
function Assert-ValidPath([string]$Path) {
    if(-not (Test-Path $Path)) {
        Write-Error "Provided path must exist!"
        Exit -1
    }
}

<#Asserts that the extensions provided do not overlap with the exceptions provided.#>
function Assert-ValidExtensions([array]$Extensions, [array]$Exceptions) {
    foreach($extension in $Extensions) {
        if($Exceptions.Contains($extension)) {
            Write-Error "Provided array of extensions cannot have the same element as exceptions array!"
            Exit -1
        }
    }
}

<#Starts the purging of files.#>
function Start-Purge([string]$Old, [String]$New, [string]$StartPath, [array]$Extensions, [array]$Exceptions){
   $isPathDirectory = Test-Path -Path $StartPath -PathType Container

   if($isPathDirectory) {
        Start-DirectoryPurge $Old $New $StartPath, $Extensions $Exceptions
   }
   else {
        Start-FilePurge $StartPath $Old $New
   }
}

<#Goes over every file in the directory to purge#>
function Start-DirectoryPurge([string]$Old, [String]$New, [string]$Directory, [array]$Extensions, [array]$Exceptions) {
    Start-FilesPurge $Directory 
    
    foreach($path in Get-ChildItem $Directory) {
        $isPathDirectory = Test-Path -Path $path -PathType Container
        if($isPathDirectory) {
            Start-FilesPurge $Directory $Old $New
        }
    }
}

<#Replaces old value with new value for all direct files in directory#>
function Start-FilesPurge([string]$Directory, [string]$Old, [string]$New) {
   foreach($path in Get-ChildItem $Directory) {

        $isPathDirectory = Test-Path -Path $path -PathType Container
        if($isPathDirectory -or -not (Should-FileBePurged $path $Extensions $Exceptions)) {
            continue
        }

        try {
            Start-FilePurge $path $Old $New   
        }
        catch {
            Write-Warning $file + " could not be purged."
        }
   }
}

<#Replaces old value with new value for file#>
function Start-FilePurge([string]$FilePath, [string]$Old, [string]$New) {
    (Get-Content -path $FilePath -Raw) -replace $Old, $New
}

<# Returns whether or not the file must be purged based on the extensions to purge and the exceptions not to purge.#>
function Should-FileBePurged([string]$FilePath, [array]$Extensions, [array]$Exceptions) {
    $extension = [IO.Path]::GetExtension($FilePath)
    $extension = Remove-ExtensionDot $extension
     
    $isExtensionAnException = Contains-Extension $Exceptions $extension
    # When count is 0, all extensions should be purged
    $isExtensionProvidedToPurge = ($Extensions.Count -eq 0) -or (Contain-Extension $Extensions $extension)
    
    return -not $isExtensionAnException -and $isExtensionProvidedToPurge
}

<#Returns whether or not a list of extensions contains an element. Dots as prefix are removed.#>
function Contains-Extension([array]$Extensions, [string]$Element) {
    foreach($extension in $Extensions) {
        $extension = Remove-ExtensionDot $extension
        if($Element -eq $extension) {
            return True
        }
    }
    return False
}

<#Removes the prefix dot of an extension if it contains one.#>
function Remove-ExtensionDot([string]$extension) {
    if(-not $extension) {
        return $extension
    }

    if($extension[0] == '.') {
        return $extension.Substring(1)
    }
}

