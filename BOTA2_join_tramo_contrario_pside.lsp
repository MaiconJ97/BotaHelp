(defun c:BOTA2 (/ *error* oldLuprec cfg sel ent guia guiaLocal pPick pCab pSide pVert
                  rGiro tamImpl seguridad rBarra distSeg offCabDist offGuiaDist
                  offCab offGuia tol radioTrabajo stepGuia endParam i p1 p2 u n segLen side base rel
                  tProj pFoot dPerp maxDelta t1 t2 tc candidates candidate
                  bestScore pTang centro nSegGiro score c giroData entGiro entBarra ptsGiro
                  pGapIni pGapFin lastBefore lastAfter entCab2 entCabJoin joinOk)

  (vl-load-com)

  ;; -------------------------
  ;; Restaurar variables
  ;; -------------------------

  (defun b2_restore ()
    (if oldLuprec
      (setvar "LUPREC" oldLuprec)
    )
  )

  (defun *error* (msg)
    (b2_restore)
    (if (and msg (/= msg "Function cancelled") (/= msg "quit / exit abort"))
      (prompt (strcat "\nError: " msg))
    )
    (princ)
  )

  ;; -------------------------
  ;; Funciones auxiliares
  ;; -------------------------

  (defun b2_pt3 (p)
    (list (car p) (cadr p) 0.0)
  )

  (defun b2_v+ (a b)
    (list (+ (car a) (car b)) (+ (cadr a) (cadr b)) 0.0)
  )

  (defun b2_v- (a b)
    (list (- (car a) (car b)) (- (cadr a) (cadr b)) 0.0)
  )

  (defun b2_v* (s v)
    (list (* s (car v)) (* s (cadr v)) 0.0)
  )

  (defun b2_dot (a b)
    (+ (* (car a) (car b)) (* (cadr a) (cadr b)))
  )

  (defun b2_len (v)
    (sqrt (+ (* (car v) (car v)) (* (cadr v) (cadr v))))
  )

  (defun b2_unit (v / l)
    (setq l (b2_len v))
    (if (> l 1e-12)
      (b2_v* (/ 1.0 l) v)
      nil
    )
  )

  (defun b2_ceil (x / i)
    (setq i (fix x))
    (if (> x i)
      (1+ i)
      i
    )
  )

  (defun b2_asin (x)
    (cond
      ((>= x 1.0) (/ pi 2.0))
      ((<= x -1.0) (- (/ pi 2.0)))
      (T (atan (/ x (sqrt (- 1.0 (* x x))))))
    )
  )

  (defun b2_nseg_inscribed (r distMax / x n)
    (setq x (/ distMax (* 2.0 r)))
    (if (> x 1.0)
      (setq x 1.0)
    )
    (setq n
      (b2_ceil
        (/ pi (b2_asin x))
      )
    )
    (max 8 n)
  )

  (defun b2_polarpt (c a r)
    (list
      (+ (car c) (* r (cos a)))
      (+ (cadr c) (* r (sin a)))
      0.0
    )
  )

  (defun b2_lwpoly_open (pts color / data)
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

  (defun b2_circle_gap_directional (cen r pAnchor pSide nSeg color
                                   / a step pPlus pMinus vSide scorePlus scoreMinus
                                     dir dirKeep gapCount pts i pGap e)
    ;; Circulo interno como polilinea ABIERTA con un hueco DIRECCIONAL.
    ;;
    ;; pAnchor = punto de tangencia con la cabecera.
    ;; pSide   = punto elegido por el usuario para indicar el lado de la bota.
    ;;
    ;; Se eliminan DOS segmentos consecutivos DESDE pAnchor, pero solamente
    ;; hacia el lado CONTRARIO a pSide.
    ;;
    ;; Ejemplo:
    ;;   si pSide queda hacia la derecha de pAnchor,
    ;;   se eliminan los dos segmentos que salen hacia la izquierda.
    ;;
    ;; pAnchor se conserva como extremo del arco porque ya pertenece a la
    ;; cabecera. Luego solo sera necesario conectar el otro extremo del hueco.

    (setq a        (angle cen pAnchor))
    (setq step     (/ (* 2.0 pi) nSeg))
    (setq gapCount 2)

    ;; Vertices vecinos a pAnchor en ambos sentidos del circulo.
    (setq pPlus  (b2_polarpt cen (+ a step) r))
    (setq pMinus (b2_polarpt cen (- a step) r))

    ;; Vector desde la tangencia hacia el punto que indica el lado elegido.
    (setq vSide (b2_v- pSide pAnchor))

    ;; Cuanto apunta cada sentido hacia pSide.
    ;; El menor producto escalar corresponde al sentido mas OPUESTO a pSide.
    (setq scorePlus  (b2_dot (b2_v- pPlus  pAnchor) vSide))
    (setq scoreMinus (b2_dot (b2_v- pMinus pAnchor) vSide))

    (if (<= scorePlus scoreMinus)
      (setq dir 1.0)   ;; elimina hacia +step
      (setq dir -1.0)  ;; elimina hacia -step
    )

    ;; El arco que permanece debe recorrerse en el sentido contrario al corte.
    (setq dirKeep (- dir))

    ;; Empieza exactamente en pAnchor y recorre todo el circulo excepto
    ;; los dos segmentos eliminados.
    (setq pts (list pAnchor))
    (setq i 1)

    (repeat (- nSeg gapCount)
      (setq pts
        (append pts
          (list
            (b2_polarpt cen (+ a (* dirKeep i step)) r)
          )
        )
      )
      (setq i (1+ i))
    )

    ;; El ultimo punto es el nuevo extremo despues de los dos segmentos cortados.
    (setq pGap (car (last pts)))
    (setq e (b2_lwpoly_open pts color))

    ;; Devuelve:
    ;; (entidad-del-arco punto-tangencia nuevo-extremo direccion-eliminada)
    (list e pAnchor pGap dir pts)
  )

  (defun b2_closest_point (e pt / p)
    ;; Punto real mas cercano de una curva a pt.
    (setq p
      (vl-catch-all-apply
        'vlax-curve-getClosestPointTo
        (list e pt)
      )
    )

    (if (vl-catch-all-error-p p)
      nil
      (b2_pt3 p)
    )
  )

  (defun b2_connect_points (p1 p2 color)
    ;; Conexion independiente entre el circulo recortado y la cabecera.
    ;; Se crea DESPUES de haber generado el hueco del circulo.
    (if (and p1 p2 (> (distance p1 p2) 1e-8))
      (b2_lwpoly_open (list p1 p2) color)
      nil
    )
  )

  (defun b2_circle_entity (cen r color / data)
    ;; Circulo normal.
    ;; color 6 = magenta/morado.

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

  (defun b2_delete_ent (e)
    (if (and e (entget e))
      (vl-catch-all-apply
        'vla-delete
        (list (vlax-ename->vla-object e))
      )
    )
  )

  (defun b2_offset_one (e dist / obj res)
    (if (and e dist)
      (progn
        (setq obj (vlax-ename->vla-object e))
        (setq res
          (vl-catch-all-apply
            'vlax-invoke
            (list obj 'Offset dist)
          )
        )
        (cond
          ((vl-catch-all-error-p res) nil)
          ((= (type res) 'LIST) (car res))
          (T res)
        )
      )
      nil
    )
  )

  (defun b2_dist_to_ent (e pt / p)
    (if (and e pt)
      (progn
        (setq p
          (vl-catch-all-apply
            'vlax-curve-getClosestPointTo
            (list e pt)
          )
        )
        (if (vl-catch-all-error-p p)
          1e99
          (distance pt (b2_pt3 p))
        )
      )
      1e99
    )
  )

  (defun b2_offset_select (e dist pSide / objP objM enP enM dP dM)
    ;; Crea offset positivo y negativo.
    ;; Mantiene el que queda mas cerca del punto de lado indicado.

    (setq objP (b2_offset_one e dist))
    (setq objM (b2_offset_one e (- dist)))

    (setq enP (if objP (vlax-vla-object->ename objP) nil))
    (setq enM (if objM (vlax-vla-object->ename objM) nil))

    (cond
      ((and enP enM)
        (setq dP (b2_dist_to_ent enP pSide))
        (setq dM (b2_dist_to_ent enM pSide))

        (if (<= dP dM)
          (progn
            (b2_delete_ent enM)
            enP
          )
          (progn
            (b2_delete_ent enP)
            enM
          )
        )
      )

      (enP enP)
      (enM enM)
      (T nil)
    )
  )

  (defun b2_triplets (lst / out)
    (setq out nil)
    (while (and lst (caddr lst))
      (setq out
        (cons
          (list (car lst) (cadr lst) (caddr lst))
          out
        )
      )
      (setq lst (cdddr lst))
    )
    (reverse out)
  )

  (defun b2_intersections (e1 e2 mode / o1 o2 res)
    (if (and e1 e2)
      (progn
        (setq o1 (vlax-ename->vla-object e1))
        (setq o2 (vlax-ename->vla-object e2))

        (setq res
          (vl-catch-all-apply
            'vlax-invoke
            (list o1 'IntersectWith o2 mode)
          )
        )

        (if (or (vl-catch-all-error-p res) (not res))
          nil
          (b2_triplets res)
        )
      )
      nil
    )
  )

  (defun b2_best_point (pts pref / best bestD d p)
    (setq best nil)
    (setq bestD 1e99)

    (foreach p pts
      (setq p (b2_pt3 p))
      (setq d (distance p pref))
      (if (< d bestD)
        (progn
          (setq best p)
          (setq bestD d)
        )
      )
    )

    best
  )

  (defun b2_intersection_best (e1 e2 pref / pts)
    ;; Primero intenta interseccion real.
    ;; Si no encuentra, intenta extendiendo ambas entidades.

    (setq pts (b2_intersections e1 e2 0))

    (if (not pts)
      (setq pts (b2_intersections e1 e2 3))
    )

    (if pts
      (b2_best_point pts pref)
      nil
    )
  )

  (defun b2_curve_local_points (e pRef radio step / p0 d0 total dStart dEnd d pts pt)
    ;; Extrae puntos de la curva dentro de un radio desde pRef.
    ;; Se usa para crear una guia local temporal sin modificar la guia original.

    (setq p0
      (vl-catch-all-apply
        'vlax-curve-getClosestPointTo
        (list e pRef)
      )
    )

    (if (vl-catch-all-error-p p0)
      nil
      (progn
        (setq p0 (b2_pt3 p0))

        (if (> (distance p0 pRef) radio)
          nil
          (progn

            (setq d0
              (vl-catch-all-apply
                'vlax-curve-getDistAtPoint
                (list e p0)
              )
            )

            (setq total
              (vl-catch-all-apply
                'vlax-curve-getDistAtParam
                (list e (vlax-curve-getEndParam e))
              )
            )

            (if (or (vl-catch-all-error-p d0) (vl-catch-all-error-p total))
              nil
              (progn

                ;; Busca limite hacia atras
                (setq d d0)
                (setq dStart d0)

                (while (>= d 0.0)
                  (setq pt
                    (vl-catch-all-apply
                      'vlax-curve-getPointAtDist
                      (list e d)
                    )
                  )

                  (if (or (vl-catch-all-error-p pt)
                          (> (distance (b2_pt3 pt) pRef) radio))
                    (setq d -1.0)
                    (progn
                      (setq dStart d)
                      (setq d (- d step))
                    )
                  )
                )

                ;; Busca limite hacia adelante
                (setq d d0)
                (setq dEnd d0)

                (while (<= d total)
                  (setq pt
                    (vl-catch-all-apply
                      'vlax-curve-getPointAtDist
                      (list e d)
                    )
                  )

                  (if (or (vl-catch-all-error-p pt)
                          (> (distance (b2_pt3 pt) pRef) radio))
                    (setq d (+ total step))
                    (progn
                      (setq dEnd d)
                      (setq d (+ d step))
                    )
                  )
                )

                ;; Crea lista de puntos
                (setq pts nil)
                (setq d dStart)

                (while (<= d dEnd)
                  (setq pt
                    (vl-catch-all-apply
                      'vlax-curve-getPointAtDist
                      (list e d)
                    )
                  )

                  (if (not (vl-catch-all-error-p pt))
                    (setq pts (append pts (list (b2_pt3 pt))))
                  )

                  (setq d (+ d step))
                )

                ;; Asegura punto final
                (setq pt
                  (vl-catch-all-apply
                    'vlax-curve-getPointAtDist
                    (list e dEnd)
                  )
                )

                (if (not (vl-catch-all-error-p pt))
                  (setq pts (append pts (list (b2_pt3 pt))))
                )

                ;; Necesita minimo 2 puntos
                (if (> (length pts) 1)
                  pts
                  nil
                )
              )
            )
          )
        )
      )
    )
  )

  (defun b2_local_poly_from_curve (e pRef radio step / pts)
    ;; Crea una polilinea temporal con la parte local de la guia.

    (setq pts (b2_curve_local_points e pRef radio step))

    (if pts
      (b2_lwpoly_open pts nil)
      nil
    )
  )

  (defun b2_breakatpoint (e pt / oldOsm oldCmd pObj res)
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
          (setq pObj (b2_pt3 pObj))
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

  (defun b2_dir_from_joint (e pJoint / pStart pEnd dStart dEnd endPar total delta pTest v)
    ;; Devuelve un vector unitario que sale desde pJoint hacia el interior
    ;; del tramo e. Se usa para saber hacia que lado de pTang continua
    ;; cada uno de los dos tramos generados por BREAKATPOINT.

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
            (setq pStart (b2_pt3 pStart))
            (setq pEnd   (b2_pt3 pEnd))
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

                (if (or (vl-catch-all-error-p total) (<= total 1e-9))
                  nil
                  (progn
                    ;; Muestra local pequena para identificar el sentido del tramo.
                    ;; Nunca supera 1 unidad ni 10% de la longitud del tramo.
                    (setq delta (min 1.0 (* total 0.10)))
                    (setq delta (max delta 0.001))
                    (if (> delta total)
                      (setq delta (* total 0.5))
                    )

                    ;; pJoint debe ser uno de los extremos. Se toma el extremo
                    ;; que quede mas cerca para tolerar pequenas imprecisiones.
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
                        (setq v (b2_v- (b2_pt3 pTest) pJoint))
                        (b2_unit v)
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

  (defun b2_select_opposite_pside (e1 e2 pJoint ptsGiro / vKeep v1 v2 s1 s2)
    ;; Selecciona SIEMPRE el tramo de cabecera contrario al lado de pSide.
    ;;
    ;; La funcion b2_circle_gap_directional ya decidio, usando pSide,
    ;; cual de los dos sentidos del circulo se conserva y cual se elimina.
    ;; Por eso aqui usamos el PRIMER segmento conservado del circulo como
    ;; referencia inequívoca:
    ;;
    ;;   - vKeep = sentido del circulo que queda, hacia el lado de pSide.
    ;;   - se elige el tramo de cabecera cuyo sentido desde pTang sea
    ;;     MAS OPUESTO a vKeep.
    ;;
    ;; De esta forma no depende de que pSide este exactamente alineado con
    ;; la cabecera y funciona tambien con cabeceras inclinadas.

    (setq vKeep
      (if (and ptsGiro (> (length ptsGiro) 1))
        (b2_unit
          (b2_v-
            (cadr ptsGiro)
            pJoint
          )
        )
        nil
      )
    )

    (cond
      ((not vKeep)
        nil
      )

      ((and e1 (entget e1) e2 (entget e2))
        (setq v1 (b2_dir_from_joint e1 pJoint))
        (setq v2 (b2_dir_from_joint e2 pJoint))

        (cond
          ((and v1 v2)
            ;; Menor producto escalar = tramo mas opuesto al
            ;; primer segmento conservado del circulo.
            (setq s1 (b2_dot v1 vKeep))
            (setq s2 (b2_dot v2 vKeep))
            (if (<= s1 s2) e1 e2)
          )
          (v1 e1)
          (v2 e2)
          (T nil)
        )
      )

      ((and e1 (entget e1)) e1)
      ((and e2 (entget e2)) e2)
      (T nil)
    )
  )

  (defun b2_join_two (eBase eAdd / oldCmd oldOsm res)
    ;; Une dos entidades que ya comparten un extremo.
    ;; No prolonga, no crea segmentos y no modifica la geometria antes del JOIN.
    ;; Devuelve T si la segunda entidad fue absorbida por la primera.

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

        ;; En JOIN, eBase es el objeto fuente. Si tuvo exito,
        ;; normalmente eAdd deja de existir porque fue incorporado.
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

  ;; Radio fijo de trabajo.
  ;; La guia solo se usa dentro de este radio desde el click en cabecera.
  (setq radioTrabajo 50.000)

  ;; Parametros preconfigurados
  (if (not *BOTA_RGIRO*)     (setq *BOTA_RGIRO* 10.000))
  (if (not *BOTA_IMPL*)      (setq *BOTA_IMPL* 36.578))
  (if (not *BOTA_DISTSEG*)   (setq *BOTA_DISTSEG* 0.700))
  (if (not *BOTA_SEGURIDAD*) (setq *BOTA_SEGURIDAD* 0.500))

  (setq oldLuprec (getvar "LUPREC"))
  (setvar "LUPREC" 3)

  (prompt "\nBOTA2 - Maniobra por linea de guiado.")
  (prompt "\nSelecciona la cabecera cerca de la zona deseada: ")
  (setq sel (entsel))

  (if (not sel)
    (prompt "\nNo se selecciono cabecera.")
    (progn

      (setq ent   (car sel))
      (setq pPick (b2_pt3 (cadr sel)))

      (setq pCab
        (vl-catch-all-apply
          'vlax-curve-getClosestPointTo
          (list ent pPick)
        )
      )

      (if (vl-catch-all-error-p pCab)
        (prompt "\nLa entidad seleccionada como cabecera no es una curva valida.")
        (progn

          (setq pCab (b2_pt3 pCab))

          (prompt "\nSelecciona la linea de guiado: ")
          (setq sel (entsel))

          (if (not sel)
            (prompt "\nNo se selecciono linea de guiado.")
            (progn

              (setq guia (car sel))

              (prompt "\nIndica un punto del lado donde se generara la bota: ")
              (setq pSide (getpoint))

              (if (not pSide)
                (prompt "\nNo se indico lado.")
                (progn

                  (setq pSide (b2_pt3 pSide))

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
                        " | Seguridad=" (rtos *BOTA_SEGURIDAD* 2 3)
                        " | Segmentos=" (rtos *BOTA_DISTSEG* 2 3)
                        "\nPresione Enter para usar estos parametros o [C] para configurar: "
                      )
                    )
                  )

                  (if (= cfg "C")
                    (progn

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

                      (setq tamImpl
                        (getdist
                          (strcat
                            "\nTamano del implemento <"
                            (rtos *BOTA_IMPL* 2 3)
                            ">: "
                          )
                        )
                      )
                      (if (not tamImpl)
                        (setq tamImpl *BOTA_IMPL*)
                      )

                      (setq seguridad
                        (getdist
                          (strcat
                            "\nSeguridad para linea de guiado <"
                            (rtos *BOTA_SEGURIDAD* 2 3)
                            ">: "
                          )
                        )
                      )
                      (if (not seguridad)
                        (setq seguridad *BOTA_SEGURIDAD*)
                      )

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
                      (setq rGiro     *BOTA_RGIRO*)
                      (setq tamImpl   *BOTA_IMPL*)
                      (setq seguridad *BOTA_SEGURIDAD*)
                      (setq distSeg   *BOTA_DISTSEG*)
                    )
                  )

                  ;; Calculos principales
                  (if (and rGiro tamImpl seguridad distSeg)
                    (progn
                      (setq rBarra      (+ rGiro (/ tamImpl 2.0)))
                      (setq offCabDist  (/ tamImpl 2.0))
                      (setq offGuiaDist (+ (/ tamImpl 2.0) seguridad))
                      (setq stepGuia    (max 0.500 (min 2.000 distSeg)))
                    )
                  )

                  (if (or (not rGiro) (not tamImpl) (not seguridad) (not rBarra) (not distSeg)
                          (<= rGiro 0.0)
                          (<= tamImpl 0.0)
                          (< seguridad 0.0)
                          (<= rBarra 0.0)
                          (<= distSeg 0.0))
                    (prompt "\nDatos invalidos. Revisa radio, implemento, seguridad y distancia entre vertices.")
                    (progn

                      ;; Guarda valores para reutilizar.
                      (setq *BOTA_RGIRO*     rGiro)
                      (setq *BOTA_IMPL*      tamImpl)
                      (setq *BOTA_SEGURIDAD* seguridad)
                      (setq *BOTA_DISTSEG*   distSeg)

                      ;; Crea tramo local temporal de la guia dentro del radio de trabajo
                      (setq guiaLocal
                        (b2_local_poly_from_curve guia pCab radioTrabajo stepGuia)
                      )

                      (if (not guiaLocal)
                        (prompt "\nNo fue posible crear el tramo local de la linea de guiado dentro del radio de trabajo.")
                        (progn

                          ;; Offsets temporales
                          (setq offCab
                            (b2_offset_select ent offCabDist pSide)
                          )

                          (setq offGuia
                            (b2_offset_select guiaLocal offGuiaDist pSide)
                          )

                          (if (or (not offCab) (not offGuia))
                            (progn
                              (if offCab (b2_delete_ent offCab))
                              (if offGuia (b2_delete_ent offGuia))
                              (if guiaLocal (b2_delete_ent guiaLocal))
                              (prompt "\nNo fue posible crear los offsets.")
                            )
                            (progn

                              ;; Punto calculado por interseccion de offsets.
                              ;; Se toma la interseccion mas cercana al click sobre la cabecera.
                              (setq pVert
                                (b2_intersection_best offCab offGuia pCab)
                              )

                              ;; Borra auxiliares temporales
                              (b2_delete_ent offCab)
                              (b2_delete_ent offGuia)
                              (b2_delete_ent guiaLocal)

                              (if (not pVert)
                                (prompt "\nNo se encontro interseccion entre los offsets dentro de la zona de trabajo.")
                                (progn

                                  ;; Busca soluciones en todos los tramos de la cabecera,
                                  ;; pero solo acepta las que esten dentro del radio de trabajo.
                                  (setq candidates nil)

                                  (setq endParam
                                    (vl-catch-all-apply
                                      'vlax-curve-getEndParam
                                      (list ent)
                                    )
                                  )

                                  (if (vl-catch-all-error-p endParam)
                                    (prompt "\nNo fue posible leer la cabecera.")
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

                                            (setq p1 (b2_pt3 p1))
                                            (setq p2 (b2_pt3 p2))

                                            (setq u (b2_unit (b2_v- p2 p1)))

                                            (if u
                                              (progn

                                                (setq segLen (distance p1 p2))

                                                (if (> segLen tol)
                                                  (progn

                                                    ;; Normal del tramo.
                                                    (setq n (list (- (cadr u)) (car u) 0.0))

                                                    ;; Centro del lado donde esta el punto calculado.
                                                    (setq side
                                                      (if (>= (b2_dot (b2_v- pVert p1) n) 0.0)
                                                        1.0
                                                        -1.0
                                                      )
                                                    )

                                                    ;; Linea de centros paralela al tramo.
                                                    (setq base
                                                      (b2_v+ p1 (b2_v* (* side rGiro) n))
                                                    )

                                                    ;; Proyeccion del punto calculado sobre la linea de centros.
                                                    (setq rel   (b2_v- pVert base))
                                                    (setq tProj (b2_dot rel u))
                                                    (setq pFoot (b2_v+ base (b2_v* tProj u)))
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
                                                                (b2_v+ p1 (b2_v* tc u))
                                                              )

                                                              ;; Centro comun.
                                                              (setq centro
                                                                (b2_v+ pTang (b2_v* (* side rGiro) n))
                                                              )

                                                              ;; Puntuacion: cercania al click inicial en cabecera.
                                                              (setq score (distance pTang pCab))

                                                              ;; Radio fijo de trabajo:
                                                              ;; evita que la bota se genere lejos de la zona clicada.
                                                              (if (<= score radioTrabajo)
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
                                        )

                                        (setq i (1+ i))
                                      )

                                      ;; Elige la solucion mas cercana al click de cabecera.
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

                                          ;; Segmentacion del circulo interno
                                          (setq nSegGiro (b2_nseg_inscribed rGiro distSeg))

                                          ;; -------------------------------------------------
                                          ;; 1) PRIMERO elimina dos segmentos del circulo,
                                          ;;    SOLO hacia el lado contrario a pSide.
                                          ;;
                                          ;;    pTang se mantiene como extremo porque ya
                                          ;;    coincide con la cabecera.
                                          ;; -------------------------------------------------
                                          (setq giroData
                                            (b2_circle_gap_directional
                                              centro rGiro pTang pSide nSegGiro nil
                                            )
                                          )

                                          (setq entGiro (car giroData))
                                          (setq pGapIni (cadr giroData)) ;; = pTang
                                          (setq pGapFin (caddr giroData))
                                          (setq ptsGiro (nth 4 giroData))

                                          ;; -------------------------------------------------
                                          ;; 2) DESPUES une el circulo con la cabecera.
                                          ;;
                                          ;;    NO prolonga ninguna entidad.
                                          ;;    NO crea ningun segmento adicional.
                                          ;;    Ambas geometrías ya comparten pTang.
                                          ;;
                                          ;;    Primero se hace BREAKATPOINT en la cabecera
                                          ;;    para que pTang sea un extremo real.
                                          ;;    Luego se ejecuta JOIN entre el arco y el tramo
                                          ;;    de cabecera que comparte ese extremo.
                                          ;; -------------------------------------------------

                                          ;; Guarda el ultimo objeto para detectar el segundo
                                          ;; tramo creado por BREAKATPOINT, si AutoCAD lo crea.
                                          (setq lastBefore (entlast))

                                          ;; Convierte pTang en extremo de la cabecera.
                                          (b2_breakatpoint ent pTang)

                                          (setq lastAfter (entlast))
                                          (setq entCab2
                                            (if (and lastAfter (/= lastAfter lastBefore))
                                              lastAfter
                                              nil
                                            )
                                          )

                                          ;; Elige SIEMPRE el tramo contrario a pSide usando el
                                          ;; sentido del arco conservado como referencia.
                                          ;; No hay fallback al otro tramo: si el JOIN falla,
                                          ;; se conserva la geometria sin unir al lado incorrecto.
                                          (setq entCabJoin
                                            (b2_select_opposite_pside
                                              ent entCab2 pTang ptsGiro
                                            )
                                          )

                                          (setq joinOk
                                            (if entCabJoin
                                              (b2_join_two entGiro entCabJoin)
                                              nil
                                            )
                                          )

                                          (if (not entCabJoin)
                                            (prompt
                                              "\nAviso: no fue posible identificar el tramo de cabecera contrario a pSide."
                                            )
                                            (if (not joinOk)
                                              (prompt
                                                "\nAviso: se identifico el tramo contrario a pSide, pero AutoCAD no pudo ejecutar JOIN."
                                              )
                                            )
                                          )

                                          ;; Circulo externo normal, morado
                                          (setq entBarra
                                            (b2_circle_entity centro rBarra 6)
                                          )

                                          (prompt
                                            (strcat
                                              "\nRadio Interno: " (rtos rGiro 2 3)
                                              " - Radio Externo: " (rtos rBarra 2 3)
                                            )
                                          )
                                        )
                                        (progn
                                          (prompt "\nNo hay solucion valida dentro del radio de trabajo.")
                                          (prompt "\nPrueba hacer click mas cerca de la zona deseada o aumentar el radioTrabajo fijo en el codigo.")
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
              )
            )
          )
        )
      )
    )
  )

  (b2_restore)
  (princ)
)

(princ "\n---------------------------------------------")
(princ "\nBOTA2 cargado correctamente.")
(princ "\nAutor: Maicon J.")
(princ "\nVersion: 1.2 - corte direccional + conexion integrada")
(princ "\nComando: BOTA2")
(princ "\nUso interno. Prohibida la modificacion o redistribucion sin autorizacion.")
(princ "\n---------------------------------------------")
(princ)