# BotaHelp

Español | [Português (Brasil)](README.pt-BR.md)

BotaHelp reúne rutinas AutoLISP para generar maniobras BOTA y concordancias
segmentadas en Autodesk AutoCAD y Civil 3D. El código está en
[`bota_help.lsp`](bota_help.lsp).

La maniobra BOTA es un giro de una máquina de pulverización cuyo objetivo es
cubrir toda la parcela sin dejar zonas sin pulverizar.
El recorrido considera el radio de giro y el ancho del implemento. En BOTA3,
el fillet que conecta el giro con la guía debe mantener esa cobertura también
en el espacio intermedio de la conexión.

## Demostración

[Ver la demostración de BotaHelp en video](docs/demo/botahelp-demo.mp4).

## Instalación

Elija cómo quiere usar BotaHelp:

| Forma de uso | Comando de carga | Archivo |
| --- | --- | --- |
| Ribbon completo, con botones, configuración, ayuda y comandos | `NETLOAD` | La DLL de [Releases](https://github.com/MaiconJ97/BotaHelp/releases/latest). |
| Solo comandos, sin la pestaña Ribbon | `APPLOAD` | `bota_help.lsp`. |

### Ribbon completo

1. Descargue [BotaHelp-1.0.25.dll](https://github.com/MaiconJ97/BotaHelp/releases/download/v1.0.25/BotaHelp-1.0.25.dll)
   y guárdela en una carpeta permanente donde tenga permiso de escritura.
2. En Civil 3D/AutoCAD 2026 (x64, .NET 8), ejecute `NETLOAD` y seleccione esa DLL.
3. Abra la pestaña **BotaHelp** para usar los botones. Si el Ribbon está oculto,
   escriba `BOTAHELP`.

La DLL incluye la fuente AutoLISP y los comandos. Para esta opción basta con
cargar la DLL. Si va a reemplazar una versión ya cargada, cierre Civil 3D/AutoCAD
y vuelva a abrirlo antes de cargar la nueva.

### Solo comandos

1. En AutoCAD o Civil 3D, ejecute `APPLOAD`.
2. Cargue `bota_help.lsp`.
3. Escriba `BOTAH` para ver la ayuda resumida o `BOTAC` para configurar los
   valores antes de ejecutar una maniobra.

Esta opción permite ejecutar los comandos por su nombre y no crea la pestaña
Ribbon.

### Compilar la DLL (opcional)

También puede generar la DLL desde el código fuente. En PowerShell, desde
la raíz del repositorio:

```powershell
.\ribbon\build.ps1
```

Para compilar necesita un SDK .NET 8, Node.js y las bibliotecas instaladas
de AutoCAD 2026. El script ejecuta las pruebas y genera `dist/BotaHelp.dll`,
que se carga con `NETLOAD`. Añada `-SkipChecks` para compilar sin ejecutar
las pruebas. Los compilados se generan en su equipo; las DLL para descargar
se distribuyen en Releases. Las [instrucciones de la DLL](ribbon/README.md)
explican la compilación y la carga.

Los comandos trabajan en el plano XY y generan polilíneas abiertas. Trabaje
con copias de las entidades originales mientras comprueba cada maniobra.

## Comandos

| Comando | Uso |
| --- | --- |
| `BOTA` | Maniobra segmentada manual. Seleccione la cabecera y luego el punto/vertice que debe tocar el circulo externo del implemento. |
| `BOTA2` (`B2`) | Maniobra definida por una cabecera y una linea guia. El primer clic sobre la cabecera define el lado de giro; el clic sobre la guia define la referencia del offset opuesto. |
| `BOTAM` (BotaM) | Maniobra de BOTA2 con un punto adicional para indicar manualmente el lado del giro. |
| `BOTA3` (`B3`) | Variante de `BOTA2` que agrega una concordancia (fillet) automatica hacia la linea guia. |
| `BOTAFILLET` (`BOTAF`, `BF`) | Crea una concordancia segmentada y tangente entre una cabecera y una linea, sin generar offsets BOTA. |
| `BOTAC` | Abre la configuracion de parametros. |
| `BOTAH` | Abre la ayuda resumida dentro de AutoCAD/Civil 3D. |

## Selección y lado de maniobra

Para ejecutar `BOTA2` y `BOTA3`, haga dos selecciones:

1. Haga clic en la cabecera cerca de la zona de trabajo. Este clic define el
   lado donde se genera la maniobra.
2. Haga clic en la linea guia. Este clic define la referencia de la guia; su
   offset se calcula en el lado contrario al definido para la cabecera.

En `BOTA3`, cuando la guía va y vuelve o tiene varias pasadas próximas, el
clic identifica la pasada que debe recibir la conexión. La búsqueda del
fillet y el cruce con la cabecera quedan limitados a ese tramo continuo.
Si la concordancia no cabe allí, se cancela sin conectar con la pasada vecina.

`BOTA3` no mide ni limita el ángulo entre la cabecera y la guía. La conexión
se calcula cuando la geometría permite usar los radios configurados.

Para elegir el lado de los offsets y el sentido inicial del giro, la rutina
usa los mismos criterios de `BOTA2` y los puntos completos de ambos clics.
La búsqueda de la maniobra se centra en el cruce elegido, incluso al rotar
el dibujo o invertir el sentido de creación de las polilíneas.

En `BOTAFILLET`, el clic sobre la cabecera selecciona el tramo que recibirá
la concordancia y el clic sobre la línea selecciona su brazo. Si ambas
entidades se cruzan, la rutina las corta en la intersección, conserva los
tramos seleccionados y los une en una sola polilínea continua.

## Parámetros

Configure los valores con `BOTAC`. Los dibujos de una misma instancia de
Civil 3D/AutoCAD comparten el último cambio válido que confirme. Al abrir
`BOTAC` o ejecutar un comando BOTA en otro dibujo, la rutina recupera esos
valores, también en los dibujos que abra después durante la sesión.
Se comparten todas las opciones de `BOTAC` y el factor de recta de `BOTA3`.
BotaHelp establece los valores iniciales en la primera carga y recupera la
configuración compartida al recargarlo. Las maniobras ya dibujadas conservan
su geometría. La sincronización termina al cerrar la instancia y no se
extiende a otras instancias.

Use los perfiles para guardar o transferir valores entre sesiones. En la
misma ventana, **Salvar arquivo** exporta todos los parámetros a un perfil
`.txt` y **Carregar arquivo** recupera un perfil guardado. La rutina valida
el archivo antes de cambiar la configuración y no ejecuta código AutoLISP
al cargarlo. También puede ajustar los valores durante cada comando.

| Parametro | Aplica a | Valor inicial | Descripcion |
| --- | --- | ---: | --- |
| Radio de giro | `BOTA`, `BOTA2`, `BOTA3` | 10 m | Radio interno de giro de la maquina. |
| Implemento | `BOTA`, `BOTA2`, `BOTA3` | 36.578 m | Ancho total del implemento. El radio externo es `radio de giro + implemento / 2`. |
| Distancia Max. Vertices Circulo | `BOTA`, `BOTA2`, `BOTA3` | 0.9 m | Separacion maxima de vertices del circulo de maniobra. |
| Cortar circulo interno | `BOTA`, `BOTA2` | Activado | Elimina dos segmentos junto a la tangencia. Desactivado conserva el circulo completo, abierto en la tangencia. |
| Seguridad linea guia | `BOTA2`, `BOTA3` | 0.2 m | Distancia adicional aplicada al offset de la guia. |
| Radio Fillet | `BOTA3` | 30 m | Radio de la concordancia entre la maniobra y la guia. |
| Distancia Max. Vertices Fillet | `BOTA3` | 1.5 m | Separacion maxima de vertices en el fillet de `BOTA3`. |
| Controlar distancia entre vertices | `BOTA3` | Activado | Redistribuye los vértices del recorrido y comprueba la separación mínima y máxima. |
| Longitud adicional en entrada y salida | `BOTA3` | 5 m | Longitud sobre la cabecera antes del giro y sobre la guia despues del fillet. Admite cero. |
| Distancia Max. Vertices en el recorrido | `BOTA3` | 1.5 m | Separación máxima a lo largo de la polilínea dentro del tramo controlado. Debe ser positiva. |
| Distancia Min. Vertices en el recorrido | `BOTA3` | 0.8 m | Separación mínima en el mismo tramo. Debe estar entre cero y el máximo; cero conserva el control solo del máximo. |
| Radio de concordancia | `BOTAFILLET` | 10 m | Radio usado por `BOTAFILLET` en modo configurado. |
| Distancia Max. Vertices | `BOTAFILLET` | 1.5 m | Separacion maxima de vertices de la concordancia en modo configurado. |

La opción **Conectar a cabecera** de `BOTAC` une el tramo de la maniobra BOTA
a la cabecera cuando la geometría lo permite. En `BOTA` y `BOTA2`, desactivar
**Cortar circulo interno** conserva los dos segmentos que normalmente se
eliminan. El círculo queda completo y abierto, con ambos extremos en la
tangencia; el flujo de BREAK y JOIN se mantiene.

En `BOTA3`, la opción `L` define la longitud deseada de la recta entre el giro
y el fillet como factor del radio de giro. El valor inicial es `0.75`: con
un radio de 10 m, la recta deseada mide 7.5 m. Si no cabe, la rutina puede
usar una más corta. Los valores elegidos durante la sesión se conservan;
para probar este ajuste en una sesión abierta, ingrese `L` y `0.75`.

## Distancia entre vértices de BOTA3

En `BOTAC`, active **Controlar distancia entre vertices de BOTA3** y defina
**Distancia Min. Vertices no percurso (m)** y
**Distancia Max. Vertices no percurso (m)**. Los valores iniciales son
0.8 m y 1.5 m. La distancia se mide a lo largo de la polilínea entre vértices
consecutivos; en un arco se usa su longitud, no la cuerda entre sus extremos.

El control abarca el giro, la recta intermedia y el fillet, incluidas sus
uniones. **Extensao antes/depois da manobra (m)** añade un tramo sobre la
cabecera antes de la entrada y sobre la guía después de la salida, con 5 m
por extremo como valor inicial. Si falta longitud, usa la disponible sin
prolongar las entidades. Fuera de ese intervalo conserva los vértices.

Con un mínimo mayor que cero, este rango tiene prioridad sobre los máximos
individuales del círculo y del fillet en BOTA3. La rutina reparte los vértices
del giro entre sus tangencias y redistribuye los tramos rectos o los arcos
de una misma circunferencia. Conserva los quiebres y las variaciones de ancho;
no elimina un vértice si eso cambia la forma. Si un tramo no admite una división
dentro del rango, conserva sus vértices y continúa con los demás. Por ejemplo,
una recta de 1.51 m entre puntos obligatorios queda sin densificar con un mínimo
de 0.8 m y un máximo de 1.5 m.

Antes de sustituir los originales, comprueba ambos límites en los tramos
ajustados, con una tolerancia numérica de 0.000001 m. Al concluir, la línea
de comandos indica cuántos tramos quedaron sin densificar y sus distancias
inicial y final desde el inicio de la polilínea resultante. Esos tramos pueden
conservar separaciones menores que el mínimo o mayores que el máximo. Un error
al procesar la geometría o escribir el resultado sigue cancelando la maniobra
y conserva los originales.

Al desactivar la casilla, se omite el control y los valores quedan guardados.
Un mínimo de cero conserva la densificación anterior: agrega vértices para
cumplir el máximo y mantiene los existentes, aunque estén más próximos.
Los perfiles guardan el mínimo, el máximo y las extensiones. Los perfiles y
sesiones anteriores conservan su máximo y usan cero como mínimo; si tampoco
incluían opciones de densificación, usan el control activado, 5 m de extensión
y 1 m de máximo. Para aplicar el rango nuevo en una sesión existente, confirme
0.8 m y 1.5 m en `BOTAC`. Cargue la fuente `bota_help.lsp` o una DLL recompilada.

## Opciones durante el comando

| Comando | Enter | `R` | `C` | `B` | `A` |
| --- | --- | --- | --- | --- | --- |
| `BOTA` | Usa los valores actuales. | Cambia solo el radio de giro. | Ajusta radio, implemento y vertices. | No aplica. | No aplica. |
| `BOTA2` | Usa los valores actuales. | Cambia solo el radio de giro. | Ajusta los parametros generales, incluida seguridad. | No aplica. | No aplica. |
| `BOTA3` | Usa los valores actuales. | Solicita primero el radio de giro y luego el radio de fillet. | Ajusta parametros generales. | Ajusta radio y vertices del fillet. | No aplica. |
| `BOTAFILLET` | Usa el radio configurado. | Cambia solo el radio de concordancia. | No aplica. | Ajusta radio y distancia maxima entre vertices. | Selecciona radio y distancia de vertices por angulo. |

## BOTAFILLET automático por ángulo

Con `A`, `BOTAFILLET` calcula el angulo interno entre los brazos definidos por los
dos clics y busca una franja configurada. Si el angulo no pertenece a una
franja, no modifica la geometria.

Configuracion inicial:

| Angulo interno | Radio | Dist. Vert. |
| --- | ---: | ---: |
| 87 a menos de 90 grados | 10 m | 0.7 m |
| 90 a menos de 120 grados | 12.5 m | 1.0 m |
| 120 a menos de 135 grados | 15 m | 1.2 m |
| 135 a 180 grados | 18 m | 1.2 m |

Las cuatro franjas se modifican en `BOTAC`. Deben estar entre 0 y 180 grados,
no solaparse y tener radio y distancia de vertices mayores que cero.

Para encontrar la concordancia, `BOTAFILLET` analiza los segmentos consecutivos
de la cabecera y de la guía dentro de una ventana radial definida por el radio
de concordancia. Así puede conservar y evaluar polilíneas con vértices cortos,
por ejemplo de 0.5 m, sin elegir un tramo distante.

## Requisitos y límites

- Seleccione entidades que AutoCAD pueda tratar como curvas y que tengan una
  geometria valida cerca de los clics.
- En `BOTAFILLET`, la cabecera y la linea deben cruzarse para que el corte se haga
  en esa interseccion. Si no se cruzan, se usa como referencia el punto elegido
  sobre la cabecera, pero puede no existir una solucion tangente valida.
- Un radio demasiado grande, un tramo insuficiente o una geometria que provoque
  cruces de la concordancia se rechazan para evitar modificar la cabecera de
  forma incorrecta.
- `BOTA2` requiere una interseccion real, o una punta de la guia apoyada sobre
  la cabecera. Antes de calcular offsets, crea una copia temporal de la guia y
  conserva una ventana de `0.2 x implemento` al lado opuesto del clic y
  `1.5 x implemento` hacia el clic. Solo ese tramo aislado recibe el offset;
  la guia original queda intacta. Antes de cualquier offset, BOTA2 tambien usa
  una copia temporal de la cabecera de `2 x implemento` a cada lado de la
  interseccion. La cabecera original se corta unicamente en la tangencia final
  del circulo.
  Para resolver esa tangencia, BOTA2 usa el centro más cercano al cruce de
  referencia de los offsets y admite una corrección máxima de `0.05 m` por
  imprecisión numérica. El centro final se reproyecta a la distancia exacta
  del radio interno sobre la cabecera.
  Si los offsets no se cruzan de forma real, la ultima comprobacion usa una
  extension virtual de hasta `1 m`, sin modificar ninguna entidad.
- `BOTA3` limita la cabecera y la guia a una zona de trabajo local de al menos
  50 m desde el clic en la cabecera.
- Revise visualmente el resultado antes de continuar el trazado. Las pruebas
  automatizadas locales no sustituyen la validación funcional en Civil 3D.

## Archivos del repositorio

- `bota_help.lsp`: fuente principal para cargar con `APPLOAD`.
- `ribbon/`: código del complemento .NET e instrucciones de compilación.
- `tests/`: pruebas automatizadas y casos para ejecutar en Civil 3D.
- `tools/ribbon-preview/`: herramienta para generar vistas previas de iconos.
- `dist/`: salida local de compilación, ignorada por Git junto con los
  artefactos `.fas`, `.vlx` y `.prv`, logs y backups.

Las fuentes anteriores se conservan en el historial de Git.

## Licencia

Este proyecto se distribuye bajo la [licencia MIT](LICENSE).
Copyright (c) 2026 Maicon Marcarini.
