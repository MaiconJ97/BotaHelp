# BotaHelp

BotaHelp reúne rutinas AutoLISP para generar maniobras BOTA y concordancias
segmentadas en Autodesk AutoCAD y Civil 3D. El código está en
[`bota_help.lsp`](bota_help.lsp).

## Demostración

[Ver la demostración de BotaHelp en video](docs/demo/botahelp-demo.mp4).

## Instalación

Para usar la fuente independiente:

1. En AutoCAD o Civil 3D, ejecute `APPLOAD`.
2. Cargue `bota_help.lsp`.
3. Escriba `BOTAH` para ver la ayuda resumida o `BOTAC` para configurar los
   valores antes de ejecutar una maniobra.

Para usar la pestaña Ribbon en Civil 3D/AutoCAD 2026 (x64, .NET 8), compile
el complemento desde PowerShell en la raíz del repositorio:

```powershell
.\ribbon\build.ps1
```

Necesita un SDK .NET 8, Node.js y las bibliotecas instaladas de AutoCAD 2026.
El script ejecuta las pruebas y genera `dist/BotaHelp.dll`. Cargue esa DLL
con `NETLOAD` para acceder a los comandos, la configuración y la ayuda desde
el Ribbon. La DLL incluye la fuente AutoLISP. Si el Ribbon está oculto,
escriba `BOTAHELP`. Los compilados se generan en su equipo y no se incluyen
en el repositorio. Las [instrucciones de la DLL](ribbon/README.md) explican
la compilación y la carga.

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
| Activar densificacion | `BOTA3` | Activado | Agrega vertices en todo el recorrido de la maniobra y en las extensiones de entrada y salida. |
| Longitud adicional en entrada y salida | `BOTA3` | 5 m | Longitud sobre la cabecera antes del giro y sobre la guia despues del fillet. Admite cero. |
| Distancia Max. Vertices en el recorrido | `BOTA3` | 1 m | Limite de separacion medido a lo largo de la polilinea dentro de todo el tramo densificado. Debe ser positivo. |
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

## Densificación opcional de BOTA3

En `BOTAC`, use **Ativar densificacao de BOTA3** para activar o desactivar esta
opcion. **Extensao antes/depois da manobra (m)** define la longitud adicional
en cada extremo y **Distancia Max. Vertices no percurso (m)** define el limite
de separacion. Los valores iniciales son 5 m por extremo y 1 m entre vertices.

El límite abarca un tramo continuo: la cabecera antes de la entrada, el giro,
la recta intermedia, el fillet y la guía después de la salida. La rutina
conserva los vértices que ya estén más próximos, la forma de los arcos y los
anchos de la polilínea. Si falta longitud en un extremo, usa la disponible
sin prolongarlo. Fuera de este intervalo no agrega vértices.

Al desactivar la casilla, se conserva la distribución de vértices de la
maniobra actual y las dos medidas quedan guardadas para volver a activarla.
Los perfiles guardan tanto la casilla como las medidas; los perfiles antiguos
usan la opción activada con 5 m y 1 m. Los límites propios del círculo y del
fillet siguen vigentes: la densificación solo subdivide los segmentos que
superen el límite general. Para usarla, cargue la fuente `bota_help.lsp`.

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
