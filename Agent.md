# Guia para agentes

## Proposito del repositorio

Este repositorio contiene rutinas AutoLISP para Autodesk Civil 3D/AutoCAD que
asisten en operaciones de diseno y edicion de geometria BOTA. Los comandos
principales expuestos son `BOTA`, `BOTA2` y `BOTA3`.

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
- Respetar el idioma y estilo de comentarios del archivo que se este editando.
- Mantener los cambios acotados al comportamiento solicitado; no mezclar
  refactorizaciones masivas ni cambios de formato no relacionados.

## Flujo de trabajo y validacion

1. Identificar primero la variante que se carga en el entorno de Civil 3D. No
   asumir que el archivo mas reciente es el que usa el usuario.
2. Editar la rutina fuente `.lsp` correspondiente; no editar los artefactos
   compilados como sustituto del codigo fuente.
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

El proyecto utiliza Git y dispone de pruebas automatizadas. Desde la raiz,
ejecute `.\ribbon\build.ps1` para compilar y comprobar el empaquetado, la
extraccion de la fuente y las pruebas locales de AutoLISP y del cargador.
Requiere un SDK .NET 8, Node.js y las bibliotecas instaladas de AutoCAD 2026.
La salida se genera en `dist/BotaHelp.dll` y no se versiona.

Estas comprobaciones no abren Civil 3D. La validacion funcional manual en la
aplicacion sigue siendo necesaria al cambiar geometria, dialogos o el Ribbon.
