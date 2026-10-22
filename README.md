# BotaHelp

Rutinas AutoLISP para Autodesk AutoCAD y Civil 3D que generan maniobras BOTA y
concordancias segmentadas. La fuente activa es
[`bota_help_v5_pt.lsp`](bota_help_v5_pt.lsp).

## Instalacion

Para usar una pestaña Ribbon conservando AutoLISP, cargue
[`dist/BotaHelp-1.0.23.dll`](dist/BotaHelp-1.0.23.dll) con `NETLOAD` en Civil 3D/AutoCAD 2026
(x64, .NET 8). La pestaña **BotaHelp** incluye los comandos, configuración y
ayuda. Si el Ribbon está oculto, escriba `BOTAHELP`. Consulte las
[instrucciones de la DLL](ribbon/README.md) para distribución y compilación.

También puede seguir cargando la fuente independiente:

1. En AutoCAD o Civil 3D, ejecute `APPLOAD`.
2. Cargue `bota_help_v5_pt.lsp`.
3. Escriba `BOTAH` para ver la ayuda resumida o `BOTAC` para configurar los
   valores antes de ejecutar una maniobra.

Los comandos trabajan en el plano XY y generan polilineas abiertas. Use copias
de las entidades originales mientras valida el resultado de cada maniobra.

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

## Seleccion y lado de maniobra

En `BOTA2` y `BOTA3` se realizan dos selecciones:

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

La elección del lado de los offsets y del sentido inicial del giro usa los
mismos criterios de `BOTA2`, con los puntos completos de ambos clics. El
cruce elegido centra la búsqueda de la maniobra, incluso al rotar el dibujo
o invertir el sentido de creación de las polilíneas.

En `BOTAFILLET`, el clic sobre la cabecera selecciona el tramo que recibira la
concordancia y el clic sobre la linea selecciona su brazo. Cuando ambas
entidades se cruzan, la rutina las parte en la interseccion, conserva los
tramos seleccionados y crea una unica polilinea continua entre ellos.

## Parametros

Configure los valores con `BOTAC`. Los parametros se comparten automaticamente
entre los dibujos de una misma instancia de Civil 3D/AutoCAD: el ultimo cambio
valido confirmado se usa al abrir `BOTAC` o ejecutar un comando BOTA en otro
dibujo. Tambien se aplican a dibujos abiertos posteriormente en esa sesion.
Incluye todas las opciones de `BOTAC` y el factor de recta de `BOTA3`.
La primera carga de BotaHelp establece los valores iniciales; recargarlo
recupera la configuracion compartida. No se modifican maniobras ya dibujadas.
La sincronizacion termina al cerrar la instancia y no alcanza otras instancias.

Use los perfiles para conservar o transferir valores entre sesiones. Na mesma janela, **Salvar arquivo**
exporta todos os parametros para um perfil `.txt` e **Carregar arquivo** restaura
um perfil previamente salvo. O arquivo e validado antes de alterar a configuracao
atual e nao executa codigo AutoLISP. Tambien pode modificarlos durante la
ejecucion de cada comando.

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

La opcion **Conectar a cabecera** de `BOTAC` controla si las maniobras BOTA
unen el tramo resultante a la cabecera cuando la geometria lo permite. En
`BOTA` y `BOTA2`, desactivar **Cortar circulo interno** conserva los dos
segmentos que normalmente se eliminan: el circulo queda completo pero sigue
abierto con ambos extremos en la tangencia, por lo que el flujo de BREAK y
JOIN se mantiene.

En `BOTA3`, la opcion `L` ajusta la longitud objetivo de la recta entre
el giro y el fillet como factor del radio de giro. El valor inicial es
`0.75`: con radio de 10 m, el objetivo es 7.5 m. Si no cabe, el solver
puede usar una recta menor. Se conservan los valores ya elegidos en la
sesion; para probar este ajuste en una sesion abierta, ingrese `L` y `0.75`.

## Densificacion opcional de BOTA3

En `BOTAC`, use **Ativar densificacao de BOTA3** para activar o desactivar esta
opcion. **Extensao antes/depois da manobra (m)** define la longitud adicional
en cada extremo y **Distancia Max. Vertices no percurso (m)** define el limite
de separacion. Los valores iniciales son 5 m por extremo y 1 m entre vertices.

El limite se aplica a un tramo continuo: cabecera antes de la entrada, giro,
recta intermedia, fillet y guia despues de la salida. Se conservan los vertices
que ya esten mas proximos, la forma de los arcos y los anchos de la polilinea.
Si un extremo tiene menos longitud disponible, se usa solo esa longitud, sin
prolongarlo. Fuera de este intervalo no se agregan vertices.

Desactivar la casilla conserva la distribucion de vertices de la maniobra
actual y mantiene guardadas las dos medidas para volver a activarla. La casilla
y las medidas se guardan en los perfiles; los perfiles antiguos usan la opcion
activada con 5 m y 1 m. Los limites particulares del circulo y del fillet siguen
aplicandose: la densificacion solo subdivide los segmentos que excedan su
limite general. Para usar la funcion, cargue la fuente `bota_help_v5_pt.lsp`.

## Opciones durante el comando

| Comando | Enter | `R` | `C` | `B` | `A` |
| --- | --- | --- | --- | --- | --- |
| `BOTA` | Usa los valores actuales. | Cambia solo el radio de giro. | Ajusta radio, implemento y vertices. | No aplica. | No aplica. |
| `BOTA2` | Usa los valores actuales. | Cambia solo el radio de giro. | Ajusta los parametros generales, incluida seguridad. | No aplica. | No aplica. |
| `BOTA3` | Usa los valores actuales. | Solicita primero el radio de giro y luego el radio de fillet. | Ajusta parametros generales. | Ajusta radio y vertices del fillet. | No aplica. |
| `BOTAFILLET` | Usa el radio configurado. | Cambia solo el radio de concordancia. | No aplica. | Ajusta radio y distancia maxima entre vertices. | Selecciona radio y distancia de vertices por angulo. |

## BOTAFILLET automatico por angulo

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

Para encontrar la concordancia, `BOTAFILLET` analiza los segmentos consecutivos de
la cabecera y de la guia dentro de una ventana radial definida por el radio de
concordancia. Esto permite conservar y evaluar polilineas con vertices cortos,
por ejemplo de 0.5 m, sin elegir un tramo distante.

## Requisitos y limites

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
Al resolver esa tangencia, BOTA2 usa el centro mas cercano al cruce de
referencia de los offsets y admite una correccion maxima de `0.05 m` por
imprecision numerica. El centro final se reproyecta a distancia exacta del
radio interno sobre la cabecera.
  Si los offsets no se cruzan de forma real, la ultima comprobacion usa una
  extension virtual de hasta `1 m`, sin modificar ninguna entidad.
- `BOTA3` limita la cabecera y la guia a una zona de trabajo local de al menos
  50 m desde el clic en la cabecera.
- Revise visualmente el resultado antes de continuar el trazado. No hay una
  suite de pruebas automatizadas para estas rutinas.

## Archivos del repositorio

- `bota_help_v5_pt.lsp`: fuente principal y version que se debe cargar.
- `bota_help_v4*.lsp` y `BOTA*_*.lsp`: variantes anteriores o auxiliares,
  conservadas como referencia.
- `.fas` y `.vlx`: artefactos compilados; no se editan manualmente.
