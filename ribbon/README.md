# BotaHelp Ribbon

Complemento para Civil 3D / AutoCAD 2026 de 64 bits con .NET 8. La DLL incluye
una copia de [`bota_help.lsp`](../bota_help.lsp) y crea una pestaña
BotaHelp con botones para BOTA, BOTA2, BOTA3, BOTAM, BOTAFILLET,
configuración y ayuda. Los cálculos y los diálogos se ejecutan en AutoLISP.

## Compilar y comprobar

Desde PowerShell, en la raíz del repositorio:

```powershell
.\ribbon\build.ps1
```

Necesita un SDK .NET 8 para Windows x64, Node.js en el PATH y las bibliotecas
de AutoCAD 2026 instaladas. El script busca primero el SDK local de BotaHelp
y luego `dotnet` en el PATH. También puede indicar las rutas:

```powershell
.\ribbon\build.ps1 -DotNet 'C:\ruta\dotnet.exe' -AutoCADDir 'C:\Program Files\Autodesk\AutoCAD 2026'
```

El script compila la DLL y comprueba que contiene exactamente la fuente
actual y que puede extraerla. Después ejecuta las pruebas locales de AutoLISP
y del cargador. Si pasan, copia el complemento a `dist/BotaHelp.dll`.
La carpeta `dist/` se genera en su equipo y Git la ignora; sus archivos no se
versionan. Estas pruebas no abren ni controlan Civil 3D. Compruebe el aspecto
del Ribbon y los resultados geométricos en la aplicación.

El producto instalado suministra las bibliotecas de Autodesk y los componentes
WPF; no se distribuyen con el complemento. Para usar otra versión de AutoCAD/Civil 3D
o una revisión con otro runtime, compruebe la compatibilidad y recompile
para ese entorno si hace falta.

## Cargar la DLL

1. Compile el complemento y copie `dist/BotaHelp.dll` a una carpeta permanente
   donde tenga permiso de escritura, por ejemplo BotaHelp dentro de Documentos.
2. En Civil 3D/AutoCAD 2026, ejecute `NETLOAD` y seleccione esa DLL.
3. Abra la pestaña **BotaHelp**. Si el Ribbon está oculto, escriba `BOTAHELP`.
4. Use los botones o escriba los comandos habituales, incluidos `B2`, `B3` y `BF`.

Para distribuir el complemento basta con la DLL. No hace falta copiar el LSP
ni instalar un archivo CUIX. En el primer uso, el complemento extrae el AutoLISP
incorporado a `BotaHelp.Runtime-<identificador>.lsp` junto a la DLL. Si no puede
escribir en esa carpeta, usa `%LOCALAPPDATA%\BotaHelp\Runtime`. El complemento
verifica el archivo generado y lo restaura desde la DLL, por lo que debe
editar la fuente original.

La carga respeta las ubicaciones de confianza de AutoCAD. Si AutoCAD bloquea
el código, utilice una ubicación de confianza aprobada para la DLL y el LSP
generado. El complemento no modifica `SECURELOAD` ni `TRUSTEDPATHS`.

El complemento carga las rutinas cuando el dibujo activo queda libre después
de `NETLOAD` o de activar otro dibujo. Si la carga no se completó, los botones
vuelven a intentarlo. Puede abrir la ayuda con su botón o con `BOTAH`; la
carga desde la DLL no la abre automáticamente. Al cambiar de espacio de
trabajo, el complemento vuelve a crear las pestañas.

Los parámetros se comparten entre dibujos de la misma instancia, incluidos
los abiertos posteriormente. La sincronización termina al cerrar la instancia;
use los perfiles de `BOTAC` para conservar valores entre sesiones.

`NETLOAD` carga el complemento para la sesión actual. El proyecto no configura
la carga automática al iniciar Civil 3D. Para reemplazar una DLL que ya está
en uso, cierre Civil 3D antes de copiar la nueva versión.

## Actualizar el AutoLISP incorporado

Edite `bota_help.lsp` y vuelva a ejecutar `.\ribbon\build.ps1`. La DLL conserva
la fuente del momento de la compilación. Para incorporar cambios posteriores
del LSP independiente, debe volver a compilarla.

Use `-OutputName BotaHelp-1.0.23.dll` para generar un archivo con otro nombre
cuando una versión anterior esté cargada y bloqueada por AutoCAD.
`BOTAHELPINFO` muestra la versión y ruta de la DLL y los identificadores de
la fuente incorporada y cargada para diagnosticar cargas antiguas.

## Vista previa de iconos

Para generar una vista previa local con el SDK .NET 8:

```powershell
dotnet run --project .\tools\ribbon-preview\BotaHelp.IconPreview.csproj -c Release -- .\dist\BotaHelp-icons.png
```

Genere primero `dist/` mediante la compilación del complemento. La herramienta
crea la vista previa y los PNG individuales en esa carpeta; no se versionan.
