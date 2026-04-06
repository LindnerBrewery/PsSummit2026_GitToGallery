# {Name}

{Description}

## Installation

```powershell
Install-Module -Name {Name} -Repository psgallery-group
```

## Usage

```powershell
Import-Module {Name}
Get-Command -Module {Name}
```

## Building

```powershell
.\build.ps1 -Task Test
```

## Testing

```powershell
Invoke-Pester -Path .\tests\
```

## License

See [LICENSE](LICENSE) for details.
