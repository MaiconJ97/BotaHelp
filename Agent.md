# Guia para agentes

## Proposito del repositorio

Este proyecto contiene rutinas AutoLISP para trazar maniobras de pulverizacion
agricola en Autodesk Civil 3D/AutoCAD. Los comandos principales son `BOTA`,
`BOTA2` y `BOTA3`.

## Que es una maniobra BOTA

BOTA es una maniobra de giro de una maquina con implemento. Su objetivo es
garantizar la cobertura total de la parcela durante el giro. Una falla de
pulverizacion es una zona que el implemento deja sin cubrir. Para construir
el recorrido, la rutina usa la cabecera, el radio de giro de la maquina y el
ancho del implemento, cuyo alcance determina la cobertura. Las variantes
automaticas tambien usan una linea guia.

En BOTA3, comprobar la cobertura a lo largo del giro, la recta intermedia y
el fillet hacia la guia, incluidos los espacios entre esos tramos. El fillet
debe conectar la maniobra sin dejar una falla de pulverizacion en el medio.
La conexion debe cumplir tanto la tangencia y continuidad de la polilinea
como la cobertura del implemento.

La cabecera es la polilinea donde se ubica y conecta el giro. La linea guia
orienta las variantes automaticas y, en BOTA3, recibe la conexion final.
El circulo interno usa el radio de giro de la maquina; el externo representa
el alcance del implemento, con radio `radio de giro + ancho / 2`.

Con `BOTA`, se selecciona manualmente el punto que debe tocar el circulo
externo. `BOTA2` define la maniobra con la cabecera y la guia; `BOTAM` agrega
un punto para indicar el lado del giro. `BOTA3` une el giro con una recta
intermedia, que puede reducirse a cero, y una concordancia tangente (fillet)
hacia la guia. `BOTAFILLET` crea solamente la concordancia.

Las rutinas trabajan en el plano XY y entregan polilineas. Al modificar el
codigo, conservar la relacion entre el recorrido de la maquina, el alcance
del implemento y los puntos de conexion.

## Estructura relevante

- `bota_help.lsp` es la fuente principal e incluye `BOTA`, `BOTA2` (`B2`),
  `BOTAM`, `BOTA3` (`B3`), `BOTAFILLET` (`BOTAF`, `BF`), `BOTAC` y `BOTAH`.
- `ribbon/` contiene el complemento .NET y su script de compilacion. La DLL
  incorpora la fuente principal como recurso.
- `tests/` contiene las pruebas automatizadas y los casos para Civil 3D.
- `tools/ribbon-preview/` permite generar vistas previas de los iconos.
- `dist/`, `.fas`, `.vlx` y `.prv` son artefactos locales ignorados por Git.
  No se editan como sustituto de las fuentes. Las versiones anteriores se
  consultan en el historial de Git.

## Convenciones de implementacion

- Mantener compatibilidad con AutoLISP y Visual LISP de AutoCAD/Civil 3D.
- Conservar la cobertura de pulverizacion al modificar la geometria de una
  maniobra. En BOTA3, esto incluye los ajustes del giro, la recta, el fillet
  y los vertices, ademas del espacio intermedio de la conexion.
- Todos los objetos deben ingresar como polilineas y salir como polilineas.
- Declarar los comandos con `c:NOMBRE` y cargar la automatizacion COM mediante
  `vl-load-com` cuando se utilicen sus funciones.
- Conservar los helpers privados con el prefijo propio de cada comando, como
  `b3_` para `BOTA3`, para evitar colisiones entre rutinas cargadas.
- Declarar las variables locales en la lista de argumentos de cada `defun`.
- `T` es una constante booleana: nunca declararla como variable local, asignarle
  un valor ni dejarla como cabeza de una expresion ejecutable. El error `bad
  function: T` suele indicar una estructura de parentesis o una rama de control
  mal formada; en flujo geometrico critico preferir `if` anidados con retorno
  explicito sobre una rama por defecto `(T ...)`.
- Cuando se modifiquen variables de sistema de AutoCAD, guardar su valor y
  restaurarlo tanto en el flujo normal como en el manejador local `*error*`.
- El manejador `*error*` debe eliminar entidades auxiliares temporales y tratar
  las cancelaciones normales sin mostrar errores innecesarios.
- Respetar el idioma y el estilo de los comentarios del archivo.
- Limitar los cambios al comportamiento solicitado. Evitar refactorizaciones
  masivas y cambios de formato ajenos a la tarea.

## Flujo de trabajo y validacion

El usuario realiza las pruebas. No ejecutar pruebas automatizadas ni
abrir AutoCAD/Civil 3D para validar cambios salvo que lo solicite expresamente.
Para generar la DLL sin pruebas, usar `.\ribbon\build.ps1 -SkipChecks`.
La validacion funcional de los pasos siguientes queda a su cargo.

1. Identificar que variante carga el usuario en Civil 3D; puede ser distinta
   del archivo mas reciente.
2. Editar la fuente `.lsp` correspondiente. Los compilados se generan desde
   esa fuente y no deben usarse como sustituto para editar el codigo.
3. Cargar la rutina en Civil 3D y ejecutar el comando afectado con un dibujo de
   prueba representativo.
4. Probar el caso correcto, una seleccion o entrada invalida y la cancelacion
   del comando.
5. Confirmar que se restauran las variables de sistema modificadas y que no
   permanecen entidades auxiliares tras un error o una cancelacion.
6. Revisar la linea de comandos de AutoCAD para detectar errores de AutoLISP o
   de automatizacion COM.
7. Tras tocar estructuras de control, comprobar el balance de parentesis y que
   `T` no se haya convertido accidentalmente en una llamada de funcion.

El proyecto usa Git y tiene pruebas automatizadas. `.\ribbon\build.ps1`
compila, comprueba el empaquetado y la extraccion de la fuente, y ejecuta las
pruebas locales de AutoLISP y del cargador. El agente debe incluir
`-SkipChecks` al compilar para dejar la ejecucion de las pruebas al usuario.
El script requiere un SDK .NET 8, Node.js y las bibliotecas instaladas de
AutoCAD 2026. Genera `dist/BotaHelp.dll`, que no se versiona.

Las pruebas automatizadas no abren Civil 3D. Los cambios de geometria,
dialogos o Ribbon requieren tambien validacion manual en la aplicacion.
