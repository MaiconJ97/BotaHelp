(defun c:BOTA (/ *error* oldLuprec cfg sel ent pPick pCab pVert
                 rGiro tamImpl rBarra distSeg tol endParam i p1 p2 u n segLen
                 side base rel tProj pFoot dPerp maxDelta t1 t2 tc
                 candidates candidate bestScore pTang centro nSegGiro
                 score c entGiro entBarra giroData ptsGiro
                 lastBefore lastAfter entCab2 entCabJoin joinOk)

  (vl-load-com)

  ;; -------------------------
  ;; Restaurar variables
  ;; -------------------------

  (defun _restore ()
    (if oldLuprec
      (setvar "LUPREC" oldLuprec)
    )
  )

  (defun *error* (msg)
    (_restore)
    (if (and msg (/= msg "Function cancelled") (/= msg "quit / exit abort"))
      (prompt (strcat "\nError: " msg))
    )
    (princ)
  )

  ;; -------------------------
  ;; Funciones auxiliares
  ;; -------------------------

  (defun _pt3 (p)
    (list (car p) (cadr p) 0.0)
  )

  (defun _v+ (a b)
    (list (+ (car a) (car b)) (+ (cadr a) (cadr b)) 0.0)
  )

  (defun _v- (a b)
    (list (- (car a) (car b)) (- (cadr a) (cadr b)) 0.0)
  )

  (defun _v* (s v)
    (list (* s (car v)) (* s (cadr v)) 0.0)
  )

  (defun _dot (a b)
    (+ (* (car a) (car b)) (* (cadr a) (cadr b)))
  )

  (defun _len (v)
    (sqrt (+ (* (car v) (car v)) (* (cadr v) (cadr v))))
  )

  (defun _unit (v / l)
    (setq l (_len v))
    (if (> l 1e-12)
      (_v* (/ 1.0 l) v)
      nil
    )
  )

  (defun _ceil (x / i)
    (setq i (fix x))
    (if (> x i)
      (1+ i)
      i
    )
  )

  (defun _asin (x)
    (cond
      ((>= x 1.0) (/ pi 2.0))
      ((<= x -1.0) (- (/ pi 2.0)))
      (T (atan (/ x (sqrt (- 1.0 (* x x))))))
    )
  )

  (defun _nseg-inscribed (r distMax / x n)
    ;; Calcula cantidad de segmentos para que la distancia
    ;; entre vertices sea como maximo distMax.

    (setq x (/ distMax (* 2.0 r)))

    (if (> x 1.0)
      (setq x 1.0)
    )

    (setq n
      (_ceil
        (/ pi (_asin x))
      )
    )

    (max 8 n)
  )

  (defun _polarpt (c a r)
    (list
      (+ (car c) (* r (cos a)))
      (+ (cadr c) (* r (sin a)))
      0.0
    )
  )

  (defun _lwpoly-open (pts color / data)
    ;; Crea una LWPOLYLINE abierta.
    ;; color nil = por capa

    (setq data
      (append
        (list
          (cons 0 "LWPOLYLINE")
          (cons 100 "AcDbEntity")
          (cons 8 (getvar "CLAYER"))
        )

        (if color
          (list (cons 62 color))
          nil
        )

        (list
          (cons 100 "AcDbPolyline")
          (cons 90 (length pts))
          (cons 70 0)
        )

        (apply 'append
          (mapcar
            '(lambda (p)
              (list
                (cons 10 (list (car p) (cadr p)))
                (cons 42 0.0)
              )
            )
            pts
          )
        )
      )
    )

    (entmakex data)
  )

  (defun _circleSegGapDirectional (cen r pAnchor pSide nSeg color
                                        / a step pPlus pMinus vSide
                                          scorePlus scoreMinus dir dirKeep
                                          gapCount pts i pGap e)
    ;; Circulo interno como LWPOLYLINE abierta con un hueco de 2 segmentos.
    ;;
    ;; pAnchor = pTang, punto comun con la cabecera.
    ;; pSide   = referencia del lado donde se genera la bota.
    ;;           En BOTA se reutiliza pVert; no se pide ningun punto extra.
    ;;
    ;; REGLA:
    ;; 1) Primero elimina DOS segmentos consecutivos desde pAnchor,
    ;;    solamente hacia el lado CONTRARIO a pSide.
    ;; 2) pAnchor queda como extremo real del circulo para poder hacer JOIN
    ;;    con la cabecera despues.

    (setq a        (angle cen pAnchor))
    (setq step     (/ (* 2.0 pi) nSeg))
    (setq gapCount 2)

    ;; Vecinos inmediatos de pAnchor en los dos sentidos.
    (setq pPlus  (_polarpt cen (+ a step) r))
    (setq pMinus (_polarpt cen (- a step) r))

    ;; Referencia hacia el lado donde se genero la bota.
    (setq vSide (_v- pSide pAnchor))

    ;; El sentido con menor producto escalar es el mas contrario a pSide.
    (setq scorePlus  (_dot (_v- pPlus  pAnchor) vSide))
    (setq scoreMinus (_dot (_v- pMinus pAnchor) vSide))

    (if (<= scorePlus scoreMinus)
      (setq dir 1.0)
      (setq dir -1.0)
    )

    ;; El arco conservado se recorre en el sentido contrario al corte.
    (setq dirKeep (- dir))

    ;; pAnchor se conserva como primer extremo.
    ;; Se recorren todos los segmentos salvo los 2 eliminados.
    (setq pts (list pAnchor))
    (setq i 1)

    (repeat (- nSeg gapCount)
      (setq pts
        (append pts
          (list
            (_polarpt cen (+ a (* dirKeep i step)) r)
          )
        )
      )
      (setq i (1+ i))
    )

    (setq pGap (car (last pts)))
    (setq e (_lwpoly-open pts color))

    ;; Devuelve:
    ;; (entidad pTang nuevo-extremo direccion-cortada lista-puntos)
    (list e pAnchor pGap dir pts)
  )

  (defun _circle-entity (cen r color / data)
    ;; Crea un circulo normal.
    ;; color nil = por capa
    ;; color 6   = magenta/morado AutoCAD

    (setq data
      (append
        (list
          (cons 0 "CIRCLE")
          (cons 100 "AcDbEntity")
          (cons 8 (getvar "CLAYER"))
        )

        (if color
          (list (cons 62 color))
          nil
        )

        (list
          (cons 100 "AcDbCircle")
          (cons 10 cen)
          (cons 40 r)
        )
      )
    )

    (entmakex data)
  )

  (defun _breakatpoint (e pt / oldOsm oldCmd pObj res)
    ;; Usa BREAKATPOINT real.
    ;; Proyecta el punto sobre la entidad para evitar errores por tolerancia.

    (if e
      (progn
        (setq pObj
          (vl-catch-all-apply
            'vlax-curve-getClosestPointTo
            (list e pt)
          )
        )

        (if (vl-catch-all-error-p pObj)
          (setq pObj pt)
          (setq pObj (_pt3 pObj))
        )

        (setq oldOsm (getvar "OSMODE"))
        (setq oldCmd (getvar "CMDECHO"))

        (setvar "OSMODE" 0)
        (setvar "CMDECHO" 0)

        (setq res
          (vl-catch-all-apply
            'vl-cmdf
            (list "_.BREAKATPOINT" (list e pObj) "_non" pObj)
          )
        )

        (if (vl-catch-all-error-p res)
          (setq res
            (vl-catch-all-apply
              'vl-cmdf
              (list "BREAKATPOINT" (list e pObj) "_non" pObj)
            )
          )
        )

        (setvar "OSMODE" oldOsm)
        (setvar "CMDECHO" oldCmd)

        res
      )
    )
  )

  (defun _dir-from-joint (e pJoint / pStart pEnd dStart dEnd endPar total delta pTest v)
    ;; Vector unitario que sale desde pJoint hacia el interior del tramo.
    ;; Permite distinguir cual de los dos tramos de cabecera queda a cada lado
    ;; despues de BREAKATPOINT.

    (if (and e (entget e))
      (progn
        (setq pStart
          (vl-catch-all-apply
            'vlax-curve-getStartPoint
            (list e)
          )
        )
        (setq pEnd
          (vl-catch-all-apply
            'vlax-curve-getEndPoint
            (list e)
          )
        )

        (if (or (vl-catch-all-error-p pStart)
                (vl-catch-all-error-p pEnd))
          nil
          (progn
            (setq pStart (_pt3 pStart))
            (setq pEnd   (_pt3 pEnd))
            (setq dStart (distance pJoint pStart))
            (setq dEnd   (distance pJoint pEnd))

            (setq endPar
              (vl-catch-all-apply
                'vlax-curve-getEndParam
                (list e)
              )
            )

            (if (vl-catch-all-error-p endPar)
              nil
              (progn
                (setq total
                  (vl-catch-all-apply
                    'vlax-curve-getDistAtParam
                    (list e endPar)
                  )
                )

                (if (or (vl-catch-all-error-p total)
                        (<= total 1e-9))
                  nil
                  (progn
                    (setq delta (min 1.0 (* total 0.10)))
                    (setq delta (max delta 0.001))

                    (if (> delta total)
                      (setq delta (* total 0.5))
                    )

                    ;; pJoint debe ser uno de los extremos.
                    (if (<= dStart dEnd)
                      (setq pTest
                        (vl-catch-all-apply
                          'vlax-curve-getPointAtDist
                          (list e delta)
                        )
                      )
                      (setq pTest
                        (vl-catch-all-apply
                          'vlax-curve-getPointAtDist
                          (list e (- total delta))
                        )
                      )
                    )

                    (if (vl-catch-all-error-p pTest)
                      nil
                      (progn
                        (setq v (_v- (_pt3 pTest) pJoint))
                        (_unit v)
                      )
                    )
                  )
                )
              )
            )
          )
        )
      )
      nil
    )
  )

  (defun _select-opposite-pvert (e1 e2 pJoint ptsGiro / vKeep v1 v2 s1 s2)
    ;; Selecciona EXCLUSIVAMENTE el tramo contrario al lado usado para
    ;; generar la bota.
    ;;
    ;; _circleSegGapDirectional ya uso pVert para decidir el lado del corte.
    ;; Por eso el primer segmento CONSERVADO del circulo (vKeep) apunta hacia
    ;; el lado que debe mantenerse. El tramo correcto de la cabecera para JOIN
    ;; es el que sale desde pTang en el sentido mas opuesto a vKeep.
    ;;
    ;; No existe fallback al tramo incorrecto.

    (setq vKeep
      (if (and ptsGiro (> (length ptsGiro) 1))
        (_unit
          (_v-
            (cadr ptsGiro)
            pJoint
          )
        )
        nil
      )
    )

    (if (not vKeep)
      nil
      (progn
        (setq v1
          (if (and e1 (entget e1))
            (_dir-from-joint e1 pJoint)
            nil
          )
        )
        (setq v2
          (if (and e2 (entget e2))
            (_dir-from-joint e2 pJoint)
            nil
          )
        )

        (cond
          ;; Dos tramos: toma el mas opuesto al arco conservado.
          ((and v1 v2)
            (setq s1 (_dot v1 vKeep))
            (setq s2 (_dot v2 vKeep))
            (if (<= s1 s2) e1 e2)
          )

          ;; Un solo tramo reconocible: solo lo acepta si realmente apunta
          ;; al lado contrario. Nunca fuerza el JOIN al lado equivocado.
          (v1
            (if (< (_dot v1 vKeep) 0.0)
              e1
              nil
            )
          )

          (v2
            (if (< (_dot v2 vKeep) 0.0)
              e2
              nil
            )
          )

          (T nil)
        )
      )
    )
  )

  (defun _join-two (eBase eAdd / oldCmd oldOsm res)
    ;; JOIN real entre dos entidades que ya comparten pTang.
    ;; No prolonga entidades y no agrega ningun segmento.
    ;; eBase = circulo interno recortado.
    ;; eAdd  = tramo correcto de la cabecera.

    (if (and eBase eAdd (entget eBase) (entget eAdd))
      (progn
        (setq oldCmd (getvar "CMDECHO"))
        (setq oldOsm (getvar "OSMODE"))

        (setvar "CMDECHO" 0)
        (setvar "OSMODE" 0)

        (setq res
          (vl-catch-all-apply
            'vl-cmdf
            (list "_.JOIN" eBase eAdd "")
          )
        )

        (setvar "OSMODE" oldOsm)
        (setvar "CMDECHO" oldCmd)

        ;; JOIN correcto: eAdd es absorbida por eBase.
        (and
          (not (vl-catch-all-error-p res))
          (entget eBase)
          (not (entget eAdd))
        )
      )
      nil
    )
  )

  ;; -------------------------
  ;; Inicio del comando
  ;; -------------------------

  (setq tol 1e-8)

  ;; Parametros preconfigurados
  (if (not *BOTA_RGIRO*)   (setq *BOTA_RGIRO* 10.000))
  (if (not *BOTA_IMPL*)    (setq *BOTA_IMPL* 36.578))
  (if (not *BOTA_DISTSEG*) (setq *BOTA_DISTSEG* 0.700))

  (setq oldLuprec (getvar "LUPREC"))
  (setvar "LUPREC" 3)

  (prompt "\nBOTA - Maniobra segmentada.")
  (prompt "\nSelecciona la cabecera cerca de la zona deseada: ")
  (setq sel (entsel))

  (if (not sel)
    (prompt "\nNo se selecciono cabecera.")
    (progn

      (setq ent   (car sel))
      (setq pPick (_pt3 (cadr sel)))

      ;; Punto de la polilinea mas cercano al click.
      (setq pCab
        (vl-catch-all-apply
          'vlax-curve-getClosestPointTo
          (list ent pPick)
        )
      )

      (if (vl-catch-all-error-p pCab)
        (prompt "\nLa entidad seleccionada no es una curva valida.")
        (progn

          (setq pCab (_pt3 pCab))

          (prompt "\nSelecciona el vertice que debe tocar el circulo externo: ")
          (setq pVert (getpoint))

          (if (not pVert)
            (prompt "\nNo se selecciono vertice.")
            (progn

              (setq pVert (_pt3 pVert))

              ;; -------------------------------------------------
              ;; Configuracion de parametros
              ;; Enter = usa valores guardados/preconfigurados
              ;; C     = configurar
              ;; -------------------------------------------------

              (initget "C")
              (setq cfg
                (getkword
                  (strcat
                    "\nParametros actuales:"
                    " Radio Interno=" (rtos *BOTA_RGIRO* 2 3)
                    " | Implemento=" (rtos *BOTA_IMPL* 2 3)
                    " | Segmentos=" (rtos *BOTA_DISTSEG* 2 3)
                    "\nPresione Enter para usar estos parametros o [C] para configurar: "
                  )
                )
              )

              (if (= cfg "C")
                (progn

                  ;; Radio de giro
                  (setq rGiro
                    (getdist
                      (strcat
                        "\nRadio de giro de la maquina <"
                        (rtos *BOTA_RGIRO* 2 3)
                        ">: "
                      )
                    )
                  )

                  (if (not rGiro)
                    (setq rGiro *BOTA_RGIRO*)
                  )

                  ;; Tamaño del implemento
                  (setq tamImpl
                    (getdist
                      (strcat
                        "\nTamaño del implemento <"
                        (rtos *BOTA_IMPL* 2 3)
                        ">: "
                      )
                    )
                  )

                  (if (not tamImpl)
                    (setq tamImpl *BOTA_IMPL*)
                  )

                  ;; Distancia maxima entre vertices
                  (setq distSeg
                    (getdist
                      (strcat
                        "\nDistancia maxima entre vertices <"
                        (rtos *BOTA_DISTSEG* 2 3)
                        ">: "
                      )
                    )
                  )

                  (if (not distSeg)
                    (setq distSeg *BOTA_DISTSEG*)
                  )
                )

                ;; Enter = usa parametros actuales
                (progn
                  (setq rGiro   *BOTA_RGIRO*)
                  (setq tamImpl *BOTA_IMPL*)
                  (setq distSeg *BOTA_DISTSEG*)
                )
              )

              ;; Radio externo calculado:
              ;; Radio externo = Radio interno + Tamaño del implemento / 2
              (if (and rGiro tamImpl)
                (setq rBarra (+ rGiro (/ tamImpl 2.0)))
              )

              (if (or (not rGiro) (not tamImpl) (not rBarra) (not distSeg)
                      (<= rGiro 0.0)
                      (<= tamImpl 0.0)
                      (<= rBarra 0.0)
                      (<= distSeg 0.0))
                (prompt "\nDatos invalidos. Revisa radio de giro, implemento y distancia entre vertices.")
                (progn

                  ;; Guarda valores para reutilizar.
                  (setq *BOTA_RGIRO*   rGiro)
                  (setq *BOTA_IMPL*    tamImpl)
                  (setq *BOTA_RBARRA*  rBarra)
                  (setq *BOTA_DISTSEG* distSeg)

                  ;; Busca soluciones en todos los tramos de la polilinea.
                  (setq candidates nil)

                  (setq endParam
                    (vl-catch-all-apply
                      'vlax-curve-getEndParam
                      (list ent)
                    )
                  )

                  (if (vl-catch-all-error-p endParam)
                    (prompt "\nNo fue posible leer la polilinea.")
                    (progn

                      (setq i 0)

                      (while (< i endParam)

                        (setq p1
                          (vl-catch-all-apply
                            'vlax-curve-getPointAtParam
                            (list ent i)
                          )
                        )

                        (setq p2
                          (vl-catch-all-apply
                            'vlax-curve-getPointAtParam
                            (list ent (1+ i))
                          )
                        )

                        (if
                          (and
                            (not (vl-catch-all-error-p p1))
                            (not (vl-catch-all-error-p p2))
                          )
                          (progn

                            (setq p1 (_pt3 p1))
                            (setq p2 (_pt3 p2))

                            (setq u (_unit (_v- p2 p1)))

                            (if u
                              (progn

                                (setq segLen (distance p1 p2))

                                (if (> segLen tol)
                                  (progn

                                    ;; Normal del tramo.
                                    (setq n (list (- (cadr u)) (car u) 0.0))

                                    ;; Coloca el centro del lado donde esta el vertice seleccionado.
                                    (setq side
                                      (if (>= (_dot (_v- pVert p1) n) 0.0)
                                        1.0
                                        -1.0
                                      )
                                    )

                                    ;; Linea de centros paralela al tramo.
                                    (setq base
                                      (_v+ p1 (_v* (* side rGiro) n))
                                    )

                                    ;; Proyeccion del vertice sobre la linea de centros.
                                    (setq rel   (_v- pVert base))
                                    (setq tProj (_dot rel u))
                                    (setq pFoot (_v+ base (_v* tProj u)))
                                    (setq dPerp (distance pVert pFoot))

                                    ;; Solo hay solucion si la linea de centros pasa
                                    ;; a distancia <= radio externo.
                                    (if (<= dPerp (+ rBarra tol))
                                      (progn

                                        (setq maxDelta
                                          (sqrt
                                            (max 0.0
                                              (- (* rBarra rBarra)
                                                 (* dPerp dPerp)
                                              )
                                            )
                                          )
                                        )

                                        (setq t1 (+ tProj maxDelta))
                                        (setq t2 (- tProj maxDelta))

                                        ;; Revisa las dos soluciones posibles.
                                        (foreach tc (list t1 t2)

                                          ;; La tangencia debe caer dentro del tramo real.
                                          (if (and
                                                (>= tc (- tol))
                                                (<= tc (+ segLen tol))
                                              )
                                            (progn

                                              ;; Ajusta por tolerancia.
                                              (if (< tc 0.0)
                                                (setq tc 0.0)
                                              )

                                              (if (> tc segLen)
                                                (setq tc segLen)
                                              )

                                              ;; Punto de tangencia real sobre la cabecera.
                                              (setq pTang
                                                (_v+ p1 (_v* tc u))
                                              )

                                              ;; Centro comun.
                                              (setq centro
                                                (_v+ pTang (_v* (* side rGiro) n))
                                              )

                                              ;; Puntuacion: cercania al click hecho en la cabecera.
                                              (setq score (distance pTang pCab))

                                              (setq candidates
                                                (cons
                                                  (list score pTang centro)
                                                  candidates
                                                )
                                              )
                                            )
                                          )
                                        )
                                      )
                                    )
                                  )
                                )
                              )
                            )
                          )
                        )

                        (setq i (1+ i))
                      )

                      ;; Elige la solucion mas cercana al click.
                      (if candidates
                        (progn

                          (setq candidate (car candidates))
                          (setq bestScore (car candidate))

                          (foreach c candidates
                            (if (< (car c) bestScore)
                              (progn
                                (setq candidate c)
                                (setq bestScore (car c))
                              )
                            )
                          )

                          (setq pTang (cadr candidate))
                          (setq centro (caddr candidate))

                          ;; Calcula cantidad de segmentos automaticamente
                          ;; solamente para el circulo menor.
                          (setq nSegGiro (_nseg-inscribed rGiro distSeg))

                          ;; -------------------------------------------------
                          ;; 1) PRIMERO: elimina 2 segmentos del circulo interno
                          ;;    hacia el lado CONTRARIO al vertice seleccionado.
                          ;;
                          ;;    En el comando BOTA, pVert tambien funciona como
                          ;;    referencia del lado donde se genera la bota.
                          ;;    No se pide linea de guiado ni punto adicional.
                          ;; -------------------------------------------------
                          (setq giroData
                            (_circleSegGapDirectional
                              centro rGiro pTang pVert nSegGiro nil
                            )
                          )

                          (setq entGiro (car giroData))
                          (setq ptsGiro (nth 4 giroData))

                          ;; -------------------------------------------------
                          ;; 2) DESPUES: conecta el circulo a la cabecera.
                          ;;
                          ;;    No se prolonga nada.
                          ;;    Circulo y cabecera ya comparten pTang.
                          ;;
                          ;;    BREAKATPOINT convierte pTang en extremo real
                          ;;    de la cabecera y luego JOIN toma SIEMPRE el
                          ;;    tramo contrario al lado donde se genero la bota.
                          ;; -------------------------------------------------

                          ;; Guarda el ultimo objeto antes de partir la cabecera
                          ;; para detectar el segundo tramo creado.
                          (setq lastBefore (entlast))

                          (_breakatpoint ent pTang)

                          (setq lastAfter (entlast))

                          (setq entCab2
                            (if (and lastAfter (/= lastAfter lastBefore))
                              lastAfter
                              nil
                            )
                          )

                          ;; No hay fallback al otro lado.
                          (setq entCabJoin
                            (_select-opposite-pvert
                              ent entCab2 pTang ptsGiro
                            )
                          )

                          (setq joinOk
                            (if entCabJoin
                              (_join-two entGiro entCabJoin)
                              nil
                            )
                          )

                          (if (not entCabJoin)
                            (prompt
                              "\nAviso: no fue posible identificar el tramo de cabecera contrario al lado de la bota."
                            )
                            (if (not joinOk)
                              (prompt
                                "\nAviso: se identifico el tramo correcto, pero AutoCAD no pudo ejecutar JOIN."
                              )
                            )
                          )

                          ;; Circulo externo:
                          ;; circulo normal, morado/magenta, sin convertir a polilinea.
                          (setq entBarra
                            (_circle-entity centro rBarra 6)
                          )

                          (prompt
                            (strcat
                              "\nRadio Interno: " (rtos rGiro 2 3)
                              " - Radio Externo: " (rtos rBarra 2 3)
                            )
                          )
                        )
                        (progn
                          (prompt "\nNo hay solucion valida en la polilinea completa.")
                          (prompt "\nPuede ser que el radio externo no alcance el vertice seleccionado con ese radio de giro.")
                          (prompt "\nPrueba aumentar el tamaño del implemento, seleccionar otro vertice o revisar el lado de la cabecera.")
                        )
                      )
                    )
                  )
                )
              )
            )
          )
        )
      )
    )
  )

  (_restore)
  (princ)
)

(princ "\n---------------------------------------------")
(princ "\nBOTA cargado correctamente.")
(princ "\nAutor: Maicon J.")
(princ "\nVersion: 1.1 - corte direccional + JOIN cabecera")
(princ "\nComando: BOTA")
(princ "\nUso interno. Prohibida la modificacion o redistribucion sin autorizacion.")
(princ "\n---------------------------------------------")
(princ)