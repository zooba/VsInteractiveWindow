$root = $MyInvocation.MyCommand.Definition | Split-Path -Parent;
$enc = New-Object System.Text.UTF8Encoding($True);

$vsct = [xml](gc $root\VisualStudio\InteractiveWindow.vsct)
$ct = $vsct.CommandTable;

"Update GUIDs in VSCT file"
foreach ($s in ($ct.KeyBindings.KeyBinding | ?{ $_.editor -eq "guidCSharpEditorFactory" })) {
    $ct.KeyBindings.RemoveChild($s) | Out-Null;
}
foreach ($s in ($ct.Symbols.Symbol | ?{ $_.name -eq "guidCSharpEditorFactory" })) {
    $ct.Symbols.RemoveChild($s) | Out-Null;
}
foreach ($s in ($ct.Buttons.Button | ?{ $_.name -eq "cmdidExecuteInInteractiveWindow" -or $_.name -eq "cmdidCopyToInteractiveWindow" })) {
    $cs.Buttons.RemoveChild($s) | Out-Null;
}

foreach ($s in $ct.Symbols.GuidSymbol) {
    if ($s.name -eq "guidInteractiveWindowPkg") {
        $s.value = "{7452F388-1BE9-4C43-877B-B4995F5E6A8E}";
    } elseif ($s.name -eq "guidInteractiveWindow") {
        $s.value =  "{E3C7B480-1DE8-41C8-AF17-16F696C78503}";
    } elseif ($s.name -eq "guidInteractiveWindowCmdSet") {
        $s.value = "{5682C825-8362-4536-98EE-4E23F289B41E}";
    }
}
foreach ($s in $ct.Commands.Buttons.Button.Strings) {
    $s.CanonicalName = $s.CanonicalName -replace '\.InteractiveConsole\.(\w+)', '.RInteractiveConsole.$1'
    $s.LocCanonicalName = $s.LocCanonicalName -replace '\.InteractiveConsole\.(\w+)', '.RInteractiveConsole.$1'
}

$vsct.Save("$root\VisualStudio\InteractiveWindow.vsct");

"Update items in extension.vsixmanifest"
$vsix = [xml](gc $root\VisualStudio\source.extension.vsixmanifest)
$vsix.PackageManifest.Metadata.Identity.Id = "AA5311F2-6AAA-45AE-A06F-07F9954BC190";
$vsix.PackageManifest.Metadata.DisplayName = "R Tools Interactive Window Components";
$vsix.Save("$root\VisualStudio\source.extension.vsixmanifest")

"Update GUIDs in Guids.cs"
[System.IO.File]::WriteAllLines(
    "$root\VisualStudio\Guids.cs",
    ((gc $root\VisualStudio\Guids.cs) |
        %{ $_ -replace 'InteractiveToolWindowIdString = "[\w\-]+"', 'InteractiveToolWindowIdString = "E3C7B480-1DE8-41C8-AF17-16F696C78503"' } |
        %{ $_ -replace 'InteractiveWindowPackageIdString = "[\w\-]+"', 'InteractiveWindowPackageIdString = "7452F388-1BE9-4C43-877B-B4995F5E6A8E"' } |
        %{ $_ -replace 'InteractiveCommandSetIdString = "[\w\-]+"', 'InteractiveCommandSetIdString = "5682C825-8362-4536-98EE-4E23F289B41E"' }),
    $enc
)

"Update VSInteractiveWindow project"
$proj = [xml](gc $root\VisualStudio\VisualStudioInteractiveWindow.csproj)

foreach ($e in $proj.Project.PropertyGroup) {
    if ($e.RootNamespace) {
        $e.RootNamespace = "Microsoft.R";
    }
    if ($e.AssemblyName) {
        $e.AssemblyName = "Microsoft.R.VsInteractiveWindow";
    }
}

foreach ($s in $proj.Project.ImportGroup.Import) {
    if ($s.Project -match 'VSL\.Settings\.targets$') {
        $s.Project = "..\Before.targets";
    } elseif ($s.Project -match 'VSL\.Imports\.targets$') {
        $s.Project = "..\After.targets";
    }
}

foreach ($e in $proj.Project.ItemGroup) {
    foreach ($s in ($e.ProjectReference | ?{ $_.Include -match 'VisualStudio\.csproj$'})) {
        $e.RemoveChild($s) | Out-Null;
    }
    foreach ($s in ($e.ProjectReference | ?{ $_.Include -match 'Editor\\InteractiveWindow\.csproj$'})) {
        $s.Include = '..\Editor\InteractiveWindow.csproj';
    }
    foreach ($s in ($e.Compile | ?{ $_.Include -match 'ProvideRoslynBindingRedirection\.cs$' -or $_.Include -match 'AssemblyRedirects\.cs$'})) {
        $e.RemoveChild($s) | Out-Null;
    }
}

$proj.Save("$root\VisualStudio\VisualStudioInteractiveWindow.csproj")

"Update InteractiveWindow project"
$proj = [xml](gc $root\Editor\InteractiveWindow.csproj)

foreach ($e in $proj.Project.PropertyGroup) {
    if ($e.RootNamespace) {
        $e.RootNamespace = "Microsoft.R.InteractiveWindow";
    }
    if ($e.AssemblyName) {
        $e.AssemblyName = "Microsoft.R.InteractiveWindow";
    }
}

foreach ($s in $proj.Project.ImportGroup.Import) {
    if ($s.Project -match 'VSL\.Settings\.targets$') {
        $s.Project = "..\Before.targets";
    } elseif ($s.Project -match 'VSL\.Imports\.targets$') {
        $s.Project = "..\After.targets";
    }
}

foreach ($e in $proj.Project.ItemGroup) {
    foreach ($s in $e.ProjectReference) {
        $e.RemoveChild($s) | Out-Null;
    }
    foreach ($s in $e.Compile) {
        if ($s.Include -match '\.\.\\\.\.\\Compilers\\Core\\Portable\\InternalUtilities\\(.+)$') {
            $s.Include = '..\' + $Matches[1];
        }
    }
}

$proj.Save("$root\Editor\InteractiveWindow.csproj")

"Update namespaces in source files"
gci "$root\VisualStudio\*.cs", "$root\Editor\*.cs" -r | %{
    [System.IO.File]::WriteAllLines($_, ((gc $_) | 
        %{ $_ -replace 'namespace Microsoft\.VisualStudio', 'using Microsoft.VisualStudio;
namespace Microsoft.R' } |
        %{ $_ -replace 'Microsoft\.VisualStudio\.InteractiveWindow', 'Microsoft.R.InteractiveWindow' } |
        %{ $_ -replace 'Microsoft\.VisualStudio\.VsInteractiveWindow', 'Microsoft.R.VsInteractiveWindow' } |
        %{ $_ -replace '\(int\)OLE\.', '(int)Microsoft.VisualStudio.OLE.' }
    ), $enc);
}

[System.IO.File]::WriteAllLines("$root\Editor\SmartUpDownOption.cs", ((gc "$root\Editor\SmartUpDownOption.cs") |
    %{ $_ -replace 'OptionName = ".+";', 'OptionName = "RInteractiveSmartUpDown";' }
), $enc);
[System.IO.File]::WriteAllLines("$root\Editor\PredefinedInteractiveContentTypes.cs", ((gc "$root\Editor\PredefinedInteractiveContentTypes.cs") |
    %{ $_ -replace '(\w+) = "(Interactive .+)";', '$1 = "R $2";' }
), $enc);
[System.IO.File]::WriteAllLines("$root\Editor\Output\OutputClassifierProvider.cs", ((gc "$root\Editor\Output\OutputClassifierProvider.cs") |
    %{ $_ -replace 'Name = "(Interactive .+)";', 'Name = "R $1";' }
), $enc);
[System.IO.File]::WriteAllLines("$root\Editor\Commands\PredefinedInteractiveCommandsContentTypes.cs", ((gc "$root\Editor\Commands\PredefinedInteractiveCommandsContentTypes.cs") |
    %{ $_ -replace 'Name = "(Interactive .+)";', 'Name = "R $1";' }
), $enc);

"Download VSSDK tools (if needed)"
if (-not (Test-Path "$root\packages\Microsoft.VSSDK.BuildTools*\build\Microsoft.VSSDK.BuildTools.props")) {
    Invoke-WebRequest https://dist.nuget.org/win-x86-commandline/latest/nuget.exe -OutFile "$root\nuget.exe"
    & "$root\nuget.exe" install Microsoft.VSSDK.BuildTools -OutputDirectory "$root\packages"
    & "$root\nuget.exe" install MicroBuild.Core -OutputDirectory "$root\packages"
    del "$root\nuget.exe"
}

"Create EditorAssemblyInfo.cs file"
copy "$root\EditorAssemblyInfo.R.cs" "$root\EditorAssemblyInfo.cs" -Force

"Finished! Ready to build"
