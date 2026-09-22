# BotaHelp

Rutinas AutoLISP para Autodesk AutoCAD y Civil 3D que generan maniobras BOTA y
concordancias segmentadas. La fuente activa es
[`bota_help_v5_pt.lsp`](bota_help_v5_pt.lsp).

## Instalacion

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
| `BOTA2` | Maniobra definida por una cabecera y una linea guia. El primer clic sobre la cabecera define el lado de giro; el clic sobre la guia define la referencia del offset opuesto. |
| `BOTA3` | Variante de `BOTA2` que agrega una concordancia (fillet) automatica hacia la linea guia. |
| `BOTAF` | Crea una concordancia segmentada y tangente entre una cabecera y una linea, sin generar offsets BOTA. |
| `BOTAC` | Abre la configuracion de parametros. |
| `BOTAH` | Abre la ayuda resumida dentro de AutoCAD/Civil 3D. |

## Seleccion y lado de maniobra

En `BOTA2` y `BOTA3` se realizan dos selecciones:

1. Haga clic en la cabecera cerca de la zona de trabajo. Este clic define el
   lado donde se genera la maniobra.
2. Haga clic en la linea guia. Este clic define la referencia de la guia; su
   offset se calcula en el lado contrario al definido para la cabecera.

En `BOTAF`, el clic sobre la cabecera selecciona el tramo que recibira la
concordancia y el clic sobre la linea selecciona su brazo. Cuando ambas
entidades se cruzan, la rutina las parte en la interseccion, conserva los
tramos seleccionados y crea una unica polilinea continua entre ellos.

## Parametros

Configure valores para a sessao com `BOTAC`. Na mesma janela, **Salvar arquivo**
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
| Radio de concordancia | `BOTAF` | 10 m | Radio usado por `BOTAF` en modo configurado. |
| Distancia Max. Vertices | `BOTAF` | 1.5 m | Separacion maxima de vertices de la concordancia en modo configurado. |

La opcion **Conectar a cabecera** de `BOTAC` controla si las maniobras BOTA
unen el tramo resultante a la cabecera cuando la geometria lo permite. En
`BOTA` y `BOTA2`, desactivar **Cortar circulo interno** conserva los dos
segmentos que normalmente se eliminan: el circulo queda completo pero sigue
abierto con ambos extremos en la tangencia, por lo que el flujo de BREAK y
JOIN se mantiene.

## Opciones durante el comando

| Comando | Enter | `R` | `C` | `B` | `A` |
| --- | --- | --- | --- | --- | --- |
| `BOTA` | Usa los valores actuales. | Cambia solo el radio de giro. | Ajusta radio, implemento y vertices. | No aplica. | No aplica. |
| `BOTA2` | Usa los valores actuales. | Cambia solo el radio de giro. | Ajusta los parametros generales, incluida seguridad. | No aplica. | No aplica. |
| `BOTA3` | Usa los valores actuales. | Solicita primero el radio de giro y luego el radio de fillet. | Ajusta parametros generales. | Ajusta radio y vertices del fillet. | No aplica. |
| `BOTAF` | Usa el radio configurado. | Cambia solo el radio de concordancia. | No aplica. | Ajusta radio y distancia maxima entre vertices. | Selecciona radio y distancia de vertices por angulo. |

## BOTAF automatico por angulo

Con `A`, `BOTAF` calcula el angulo interno entre los brazos definidos por los
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

Para encontrar la concordancia, `BOTAF` analiza los segmentos consecutivos de
la cabecera y de la guia dentro de una ventana radial definida por el radio de
concordancia. Esto permite conservar y evaluar polilineas con vertices cortos,
por ejemplo de 0.5 m, sin elegir un tramo distante.

## Requisitos y limites

- Seleccione entidades que AutoCAD pueda tratar como curvas y que tengan una
  geometria valida cerca de los clics.
- En `BOTAF`, la cabecera y la linea deben cruzarse para que el corte se haga
  en esa interseccion. Si no se cruzan, se usa como referencia el punto elegido
  sobre la cabecera, pero puede no existir una solucion tangente valida.
- Un radio demasiado grande, un tramo insuficiente o una geometria que provoque
  cruces de la concordancia se rechazan para evitar modificar la cabecera de
  forma incorrecta.
- `BOTA2` requiere una interseccion real, o una punta de la guia apoyada sobre
  la cabecera. Antes de calcular offsets, crea una copia temporal de la guia,
  la corta en esa interseccion y nuevamente a `1.5 x implemento` hacia el clic
  de la guia. Solo ese tramo aislado recibe el offset; la guia original queda
  intacta. Si Civil 3D no permite el offset de la cabecera completa, BOTA2 usa
  temporalmente un tramo de cabecera de `2 x implemento` a cada lado de la
  interseccion. La cabecera original se corta unicamente en la tangencia final
  del circulo.
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
