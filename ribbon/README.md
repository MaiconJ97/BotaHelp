# BotaHelp Ribbon

Complemento para **Civil 3D / AutoCAD 2026 de 64 bits con .NET 8**. La DLL
incluye una copia de la fuente AutoLISP actual y crea una pestaña **BotaHelp**
con iconos y botones para BOTA, BOTA2, BOTA3, BOTAM, BOTAFILLET, configuración y
ayuda. Los cálculos y los diálogos siguen ejecutándose en AutoLISP.

La version 1.0.22 comparte automaticamente los parametros de BOTA entre
dibujos de la misma instancia, incluidos los abiertos despues. Cada comando
y la ventana de configuracion recuperan los ultimos valores confirmados.
La sincronizacion es en memoria y termina al cerrar AutoCAD/Civil 3D.

## Cargar la DLL

1. Copie `dist/BotaHelp-1.0.22.dll` a una carpeta permanente donde tenga permiso de
   escritura, por ejemplo una carpeta BotaHelp dentro de Documentos.
2. En Civil 3D, ejecute `NETLOAD` y seleccione esa DLL.
3. Abra la pestaña **BotaHelp**. Si el Ribbon está oculto, escriba `BOTAHELP`.
4. Use los botones o escriba los comandos habituales, incluidos `B2`, `B3` y `BF`.

Si utilizó la versión 1.0.18 con iconos ampliados, reinicie Civil 3D y vuelva
a cargar la versión actual con iconos de 32 × 32. Restablezca `RIBBONICONRESIZE` en `1` si lo había cambiado.

Solo se necesita distribuir **la DLL**: no hace falta copiar manualmente
el LSP ni instalar un archivo CUIX. En el primer uso se extrae automáticamente
el AutoLISP incorporado a `BotaHelp.Runtime-<identificador>.lsp` junto a la DLL.
Si esa carpeta no permite escribir, se usa `%LOCALAPPDATA%\BotaHelp\Runtime`.
No edite ese archivo generado: se verifica y se recupera desde la DLL.

La carga respeta las ubicaciones de confianza de AutoCAD. Si AutoCAD bloquea
el código, utilice una ubicación de confianza aprobada para la DLL y el LSP
generado. El complemento no modifica `SECURELOAD` ni `TRUSTEDPATHS`.

Las rutinas se cargan al quedar libre el dibujo activo después de `NETLOAD`
o de activar otro dibujo. Los botones reintentan la carga si no se completó.
La ayuda sigue disponible
en su botón y mediante `BOTAH`, pero no aparece automáticamente durante la
carga desde la DLL. La configuración, perfiles y densificación funcionan como
en la fuente actual. Las pestañas se recrean al cambiar de espacio de trabajo.

`NETLOAD` carga el complemento en la sesión actual. Este proyecto no registra
una carga automática al iniciar Civil 3D. Para reemplazar una DLL ya cargada,
cierre Civil 3D antes de copiar la nueva versión.

La versión 1.0.2 adapta los iconos a las referencias de las maniobras: BOTA y
BOTA2 muestran el giro circular blanco con guías amarillas y verdes, y BOTA3
muestra el retorno amarillo con su guía naranja. Los iconos son vectoriales y
su [vista previa](../dist/BotaHelp-icons-1.0.2.png) incluye el tamaño real de 32 px.
También conserva el Enter explícito de la versión 1.0.1 al pulsar un botón.
La versión 1.0.3 muestra el botón de concordancia como **Fillet Automatico**.
Reinicie Civil 3D y cargue `dist/BotaHelp-1.0.22.dll` con `NETLOAD` para actualizar.
La confirmación de parámetros después de seleccionar las entidades se mantiene.

La versión 1.0.4 inicia los comandos del Ribbon por su nombre, igual que al
escribirlos, para permitir repetirlos con Enter. En el primer uso, la carga
del AutoLISP termina antes de iniciar el comando interactivo; si falla, muestra
el motivo y permite reintentar. Las selecciones de cabecera y guía reciben su
mensaje directamente en `entsel`, para mostrarlo junto al cursor cuando la
entrada dinámica está activada. Se conservan los valores de `DYNMODE` y
`DYNPROMPT` del usuario. También se protegen las consultas del Ribbon durante
el inicio y cierre de dibujos. La causa del «error inesperado» comunicado
todavía requiere el texto exacto del error para confirmarse.

La versión 1.0.5 organiza los grupos de izquierda a derecha como
**Preferencias**, **Manobra Bota** (BOTA, BOTA2, BOTA3 y BotaM) y
**Manobras** (Fillet Automatico).

La versión 1.0.6 corrige el lado manual de `BOTAM`: el arco sale desde la
tangencia hacia el punto indicado. El corte y la conexión con la cabecera
quedan al lado opuesto, tanto con el corte del círculo activado como
desactivado. La fuente `bota_help_v5_pt.lsp` incluye la misma corrección.

La versión 1.0.7 cambia el corte de las copias temporales a `BREAK` con dos
puntos idénticos y conversión de WCS a UCS. Se mantienen las comprobaciones
de extremos y longitud antes de aceptar los tramos y se conserva el detalle
del error de copia o corte en el aviso. La comprobación local no sustituye
la confirmación del caso comunicado en Civil 3D.

La versión 1.0.8 actualiza el estado de los botones al iniciar y terminar
comandos y expresiones AutoLISP, también al cancelar o fallar, y al cambiar
de dibujo. La actualización se realiza cuando AutoCAD vuelve a estar libre,
para que los botones no conserven el estado deshabilitado del comando anterior.

La versión 1.0.9 divide directamente las copias de polilíneas ligeras abiertas
por sus vértices y bulges. El tramo temporal de BOTA2/BOTAM deja de depender
de `BREAK` y de detectar su resultado con `entlast`. Se conservan los arcos,
los anchos, las propiedades y las comprobaciones de extremos y longitud.
La corrección también está en `bota_help_v5_pt.lsp` y conserva el ajuste del
lado manual de BOTAM. Las polilíneas antiguas siguen usando el corte nativo.

La versión 1.0.10 restaura exactamente el AutoLISP incorporado en la DLL
1.0.5, anterior al ajuste del lado de BOTAM. Revierte también los cambios
posteriores de corte temporal y división directa. El LSP independiente y el
incorporado en la DLL vuelven a ser idénticos a esa fuente anterior. Se
conservan la distribución del Ribbon y su actualización de botones.

La versión 1.0.11 conserva byte por byte el LSP restaurado de la versión 1.0.5.
Elimina los comandos .NET que duplicaban BOTA, BOTA2, B2, BOTA3, B3, BOTAM y
los demás comandos AutoLISP. Los botones envían sus nombres directamente a
AutoCAD una vez cargada la fuente, sin envolver la rutina con `Application.Invoke`.
`BOTAHELPINFO` muestra la versión y ruta de la DLL y los identificadores de
la fuente incorporada y cargada para diagnosticar cargas de versiones antiguas.

La versión 1.0.12 limita BOTA3 al pase continuo de la guía indicado por el
clic. El cruce con la cabecera, la copia de offsets y el fillet respetan ese
mismo pase; los retornos vecinos no compiten como candidatos. Si no cabe un
fillet en el pase seleccionado, se informa del fallo sin conectar a otro.
Este cambio está en `bota_help_v5_pt.lsp` y en la DLL; los helpers compartidos
de BOTA2 y BOTAM se conservan como en la fuente restaurada.

La versión 1.0.13 elimina la medición y la comprobación del ángulo de trabajo
de BOTA3. Se mantienen la validación de las polilíneas de entrada y la
selección de la pasada indicada por el clic. La geometría debe permitir una
concordancia con los radios configurados.

La versión 1.0.14 alinea el sentido de BOTA3 con los criterios de BOTA2:
usa los clics completos para elegir los lados de offset, centra la ventana
de cabecera en el cruce y elige el centro más cercano a ese cruce. La
referencia de corte queda opuesta a la intersección de offsets, igual que
en BOTA2. Se mantienen la pasada de guía seleccionada y el fillet de BOTA3;
el código de BOTA2 y sus cortes compartidos no se modifica.

La versión 1.0.15 muestra BOTA, BOTA2 y BOTA3 con fondo transparente: elimina
el recuadro oscuro y la cuadrícula de sus iconos y conserva los trazos de las
maniobras. La [vista previa](../dist/BotaHelp-icons-1.0.15.png) muestra los
iconos sobre superficies claras y oscuras, ampliados y a 32 px.

La versión 1.0.16 renombra la maniobra manual a **BotaM** en el Ribbon y a
`BOTAM` en AutoLISP, ayuda y catálogo de comandos. Conserva su funcionamiento.

La versión 1.0.17 actualiza los iconos según las nuevas referencias: BOTA,
BOTA2 y BotaM comparten la maniobra con círculo; BOTA3 muestra el retorno
curvo. Todos conservan el fondo transparente. La [vista previa](../dist/BotaHelp-icons-1.0.17.png)
permite compararlos sobre fondos claros y oscuros.

La versión 1.0.19 centra el símbolo «?» del botón Ajuda usando los límites
visibles del carácter. Conserva los iconos de 32 × 32 y el fondo transparente.
La [vista previa](../dist/BotaHelp-icons-1.0.19.png) incluye el botón de ayuda.

La versión 1.0.20 aplica los mismos tonos amarillo y naranja de BOTA a
Configuracao, Ajuda y Fillet Automatico. Mantiene los iconos de 32 × 32,
el fondo transparente y el símbolo de ayuda centrado.
La [vista previa](../dist/BotaHelp-icons-1.0.20.png) muestra todos los iconos.

La versión 1.0.21 corrige en BOTAC la etiqueta de seguridad a
«Seguranca (BOTA2 / BOTA3)», coherente con la ayuda y el uso del parámetro
en ambos comandos. No modifica los cálculos de las maniobras.

## Actualizar el AutoLISP incorporado

Edite `bota_help_v5_pt.lsp` y vuelva a compilar la DLL. Cada compilación incorpora
la fuente que existe en ese momento. Una DLL distribuida no utiliza cambios
posteriores realizados en el LSP independiente.

Desde PowerShell, en la raíz del repositorio:

```powershell
.\ribbon\build.ps1
```

El script requiere un SDK .NET 8 para Windows x64 y las bibliotecas de AutoCAD
2026. Busca primero el SDK local de BotaHelp y luego `dotnet` en el PATH. Puede
indicar explícitamente las rutas:

```powershell
.\ribbon\build.ps1 -DotNet 'C:\ruta\dotnet.exe' -AutoCADDir 'C:\Program Files\Autodesk\AutoCAD 2026'
```

Use `-OutputName BotaHelp-1.0.22.dll` para generar un archivo con otro nombre
cuando una versión anterior esté cargada y bloqueada por AutoCAD.

Se ejecutan la compilación, las comprobaciones del recurso incorporado y de su
extracción, y las pruebas locales de AutoLISP y del cargador. Si pasan, se copia
el único archivo de distribución a `dist/BotaHelp.dll`. Estas comprobaciones no
abren ni controlan Civil 3D; el comportamiento visual del Ribbon requiere
verificación en la aplicación.

Las bibliotecas de Autodesk y los componentes WPF son suministrados por el
producto instalado; no se redistribuyen junto con el complemento. Otras
versiones de AutoCAD/Civil 3D o revisiones con otro runtime requieren comprobar
su compatibilidad y, cuando corresponda, recompilar para ese entorno.
