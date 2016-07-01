$root = $MyInvocation.MyCommand.Definition | Split-Path -Parent;
$enc = New-Object System.Text.UTF8Encoding($False);

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
        $s.value = "{72FDA47E-B202-4BAB-8AD9-0FB0F33A5015}";
    } elseif ($s.name -eq "guidInteractiveWindow") {
        $s.value =  "{4C65B4B3-E8C7-46E8-AB0E-DA1CE46DA7EC}";
    } elseif ($s.name -eq "guidInteractiveWindowCmdSet") {
        $s.value = "{F27554FA-3DF4-4649-A81C-1B97C932E78B}";
    }
}

$vsct.Save("$root\VisualStudio\InteractiveWindow.vsct");

"Update items in extension.vsixmanifest"
$vsix = [xml](gc $root\VisualStudio\source.extension.vsixmanifest)
$vsix.PackageManifest.Metadata.Identity.Id = "045BB34E-CAF1-45D8-8103-BF029D5A78A5";
$vsix.PackageManifest.Metadata.DisplayName = "Python Tools Interactive Window Components";
$vsix.Save("$root\VisualStudio\source.extension.vsixmanifest")

"Update GUIDs in Guids.cs"
[System.IO.File]::WriteAllLines(
    "$root\VisualStudio\Guids.cs",
    ((gc $root\VisualStudio\Guids.cs) |
        %{ $_ -replace 'InteractiveToolWindowIdString = "[\w\-]+"', 'InteractiveToolWindowIdString = "4C65B4B3-E8C7-46E8-AB0E-DA1CE46DA7EC"' } |
        %{ $_ -replace 'InteractiveWindowPackageIdString = "[\w\-]+"', 'InteractiveWindowPackageIdString = "72FDA47E-B202-4BAB-8AD9-0FB0F33A5015"' } |
        %{ $_ -replace 'InteractiveCommandSetIdString = "[\w\-]+"', 'InteractiveCommandSetIdString = "F27554FA-3DF4-4649-A81C-1B97C932E78B"' }),
    $enc
)

"Update VSInteractiveWindow project"
$proj = [xml](gc $root\VisualStudio\VisualStudioInteractiveWindow.csproj)

foreach ($e in $proj.Project.PropertyGroup) {
    if ($e.RootNamespace) {
        $e.RootNamespace = "Microsoft.PythonTools";
    }
    if ($e.AssemblyName) {
        $e.AssemblyName = "Microsoft.PythonTools.VsInteractiveWindow";
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
        $e.RootNamespace = "Microsoft.PythonTools";
    }
    if ($e.AssemblyName) {
        $e.AssemblyName = "Microsoft.PythonTools.InteractiveWindow";
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
        %{ $_ -replace 'Microsoft\.VisualStudio\.InteractiveWindow', 'Microsoft.PythonTools.InteractiveWindow' } |
        %{ $_ -replace 'Microsoft\.VisualStudio\.VsInteractiveWindow', 'Microsoft.PythonTools.VsInteractiveWindow' }
    ), $enc);
}