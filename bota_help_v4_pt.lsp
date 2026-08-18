;; ============================================================
;; BOTA TOOLS - SUITE DE FERRAMENTAS DE MANOBRAS (Civil3D / AutoCAD)
;; Criador: Maicon Marcarini
;; Versao: 4.0
;; Comandos incluidos: BOTA / BOTA2 / BOTA3 / BOTAC / BOTAH
;; ============================================================

(vl-load-com)

;; ------------------------------------------------------------
;; INICIALIZACAO DE VARIAVEIS GLOBAIS COMPARTILHADAS
;; ------------------------------------------------------------
(if (not *BOTA_RGIRO*)     (setq *BOTA_RGIRO* 10.000))
(if (not *BOTA_IMPL*)      (setq *BOTA_IMPL* 36.578))
(if (not *BOTA_DISTSEG*)   (setq *BOTA_DISTSEG* 0.700))
(if (not *BOTA_SEGURIDAD*) (setq *BOTA_SEGURIDAD* 0.500))
(if (not *BOTA_FILLET_R*)   (setq *BOTA_FILLET_R* 30.000))
(if (not *BOTA_FILLET_SEG*) (setq *BOTA_FILLET_SEG* 1.500))
(if (not (boundp '*BOTA_CONECTAR_CAB*)) (setq *BOTA_CONECTAR_CAB* T))

;; ============================================================
;; COMANDO BOTAC - JANELA DCL DE CONFIGURACAO DE PARAMETROS
;; Criador: Maicon Marcarini
;; ============================================================

(defun _bota_show_dcl (/ dclFile fn dclId status _v_rGiro _v_tamImpl _v_distSeg _v_seguridad _v_filletR _v_filletSeg _v_joinCab)
  (vl-load-com)
  (setq dclFile (vl-filename-mktemp "bota_cfg" nil ".dcl"))
  (setq fn (open dclFile "w"))
  (if fn
    (progn
      (write-line "bota_config_dialog : dialog {" fn)
      (write-line "  label = \"Ferramentas BOTA - Configuracao de Parametros\";" fn)
      (write-line "  : column {" fn)
      (write-line "    children_alignment = centered;" fn)
      (write-line "    : boxed_column {" fn)
      (write-line "      label = \"Parametros Compartilhados (BOTA / BOTA2 / BOTA3)\";" fn)
      (write-line "      : edit_box { label = \"Raio de Giro da Maquina (m):\"; key = \"rGiro\"; edit_width = 12; }" fn)
      (write-line "      : edit_box { label = \"Tamanho do Implemento (m):\"; key = \"tamImpl\"; edit_width = 12; }" fn)
      (write-line "      : edit_box { label = \"Distancia Max. Vertices Circulo (m):\"; key = \"distSeg\"; edit_width = 12; }" fn)
      (write-line "    }" fn)
      (write-line "    : boxed_column {" fn)
      (write-line "      label = \"Seguranca (somente BOTA2)\";" fn)
      (write-line "      : edit_box { label = \"Seguranca Linha Guia (m):\"; key = \"seguridad\"; edit_width = 12; }" fn)
      (write-line "    }" fn)
      (write-line "    : boxed_column {" fn)
      (write-line "      label = \"Fillet (somente BOTA3)\";" fn)
      (write-line "      : edit_box { label = \"Raio do Fillet / Concordancia (m):\"; key = \"filletR\"; edit_width = 12; }" fn)
      (write-line "      : edit_box { label = \"Distancia Max. Vertices Fillet (m):\"; key = \"filletSeg\"; edit_width = 12; }" fn)
      (write-line "    }" fn)
      (write-line "    : boxed_column {" fn)
      (write-line "      label = \"Cabeceira\";" fn)
      (write-line "      : toggle { label = \"Conectar a cabeceira\"; key = \"joinCab\"; }" fn)
      (write-line "    }" fn)
      (write-line "    : spacer { height = 1; }" fn)
      (write-line "    : row {" fn)
      (write-line "      : button { label = \"Salvar / Aceitar\"; key = \"accept\"; is_default = true; width = 16; }" fn)
      (write-line "      : button { label = \"Cancelar\"; key = \"cancel\"; is_cancel = true; width = 16; }" fn)
      (write-line "    }" fn)
      (write-line "  }" fn)
      (write-line "}" fn)
      (close fn)

      (setq dclId (load_dialog dclFile))
      (if (new_dialog "bota_config_dialog" dclId)
        (progn
          (set_tile "rGiro"     (rtos *BOTA_RGIRO* 2 3))
          (set_tile "tamImpl"   (rtos *BOTA_IMPL* 2 3))
          (set_tile "distSeg"   (rtos *BOTA_DISTSEG* 2 3))
          (set_tile "seguridad" (rtos *BOTA_SEGURIDAD* 2 3))
          (set_tile "filletR"   (rtos *BOTA_FILLET_R* 2 3))
          (set_tile "filletSeg" (rtos *BOTA_FILLET_SEG* 2 3))
          (set_tile "joinCab"    (if *BOTA_CONECTAR_CAB* "1" "0"))

          (action_tile "accept"
            "(progn
               (setq _v_rGiro     (atof (get_tile \"rGiro\")))
               (setq _v_tamImpl   (atof (get_tile \"tamImpl\")))
               (setq _v_distSeg   (atof (get_tile \"distSeg\")))
               (setq _v_seguridad (atof (get_tile \"seguridad\")))
               (setq _v_filletR   (atof (get_tile \"filletR\")))
               (setq _v_filletSeg (atof (get_tile \"filletSeg\")))
               (setq _v_joinCab   (= (get_tile \"joinCab\") \"1\"))
               (if (and (> _v_rGiro 0.0)
                        (> _v_tamImpl 0.0)
                        (> _v_distSeg 0.0)
                        (>= _v_seguridad 0.0)
                        (> _v_filletR 0.0)
                        (> _v_filletSeg 0.0))
                 (progn
                   (setq *BOTA_RGIRO*     _v_rGiro)
                   (setq *BOTA_IMPL*      _v_tamImpl)
                   (setq *BOTA_DISTSEG*   _v_distSeg)
                   (setq *BOTA_SEGURIDAD* _v_seguridad)
                   (setq *BOTA_FILLET_R*   _v_filletR)
                   (setq *BOTA_FILLET_SEG* _v_filletSeg)
                   (setq *BOTA_CONECTAR_CAB* _v_joinCab)
                   (done_dialog 1)
                 )
                 (alert \"Por favor, informe valores numericos validos maiores que zero.\")
               )
             )"
          )

          (action_tile "cancel" "(done_dialog 0)")

          (setq status (start_dialog))
          (unload_dialog dclId)
          (vl-file-delete dclFile)
          (if (= status 1)
            (prompt "\nParametros BOTA atualizados corretamente.")
          )
          status
        )
        (progn
          (unload_dialog dclId)
          (vl-file-delete dclFile)
          (prompt "\nErro ao abrir a janela de dialogo DCL.")
          nil
        )
      )
    )
    nil
  )
)

(defun c:BOTAC ()
  (_bota_show_dcl)
  (princ)
)

;; ============================================================
;; COMANDO BOTAH - JANELA DE AJUDA
;; ============================================================

(defun _bota_show_help (/ dclFile fn dclId)
  (vl-load-com)
  (setq dclFile (vl-filename-mktemp "bota_help" nil ".dcl"))
  (setq fn (open dclFile "w"))
  (if fn
    (progn
      (write-line "bota_help_dialog : dialog {" fn)
      (write-line "  label = \"Ferramentas BOTA v4.0 - Ajuda\";" fn)
      (write-line "  : column {" fn)
      (write-line "    : boxed_column {" fn)
      (write-line "      label = \"Informacoes Gerais\";" fn)
      (write-line "      : paragraph {" fn)
      (write-line "        : text_part { label = \"Criador: Maicon Marcarini\"; }" fn)
      (write-line "        : text_part { label = \"Versao: 4.0\"; }" fn)
      (write-line "        : text_part { label = \"Proibida a modificacao ou redistribuicao sem autorizacao.\"; }" fn)
      (write-line "      }" fn)
      (write-line "    }" fn)
      (write-line "    : boxed_column {" fn)
      (write-line "      label = \"Comandos Disponiveis\";" fn)
      (write-line "      : paragraph {" fn)
      (write-line "        : text_part { label = \"BOTA  - Manobra manual selecionando o vertice onde deve passar o externo do implemento.\"; }" fn)
      (write-line "        : text_part { label = \"BOTA2 - Manobra automatica com cabeceira e linha guia.\"; }" fn)
      (write-line "        : text_part { label = \"BOTA3 - Manobra bota totalmente automatica.\"; }" fn)
      (write-line "        : text_part { label = \"BOTAC - Abre a janela de configuracao de parametros.\"; }" fn)
      (write-line "        : text_part { label = \"BOTAH - Mostra esta janela de ajuda.\"; }" fn)
      (write-line "      }" fn)
      (write-line "    }" fn)
      (write-line "    : boxed_column {" fn)
      (write-line "      label = \"Parametros Compartilhados (BOTA / BOTA2 / BOTA3)\";" fn)
      (write-line "      : paragraph {" fn)
      (write-line "        : text_part { label = \"Raio de Giro: raio interno de giro da maquina.\"; }" fn)
      (write-line "        : text_part { label = \"Implemento: largura total do implemento (barra).\"; }" fn)
      (write-line "        : text_part { label = \"Raio Externo = Raio de Giro + Implemento / 2.\"; }" fn)
      (write-line "        : text_part { label = \"Dist. Max. Vertices: segmentacao do circulo interno.\"; }" fn)
      (write-line "      }" fn)
      (write-line "    }" fn)
      (write-line "    : boxed_column {" fn)
      (write-line "      label = \"Parametro Exclusivo do BOTA2\";" fn)
      (write-line "      : paragraph {" fn)
      (write-line "        : text_part { label = \"Seguranca: distancia extra para garantir cobertura\"; }" fn)
      (write-line "        : text_part { label = \"entre a manobra e a linha guia.\"; }" fn)
      (write-line "      }" fn)
      (write-line "    }" fn)
      (write-line "    : boxed_column {" fn)
      (write-line "      label = \"Parametros Exclusivos do BOTA3\";" fn)
      (write-line "      : paragraph {" fn)
      (write-line "        : text_part { label = \"Raio Fillet: raio da concordancia (arco de conexao).\"; }" fn)
      (write-line "        : text_part { label = \"Fillet Seg.: distancia max. entre vertices da concordancia.\"; }" fn)
      (write-line "      }" fn)
      (write-line "    }" fn)
      (write-line "    : paragraph {" fn)
      (write-line "      : text_part { label = \"BOTA3 e um comando experimental.\"; }" fn)
      (write-line "    }" fn)
      (write-line "    : spacer { height = 1; }" fn)
      (write-line "    : row {" fn)
      (write-line "      fixed_width = true;" fn)
      (write-line "      alignment = centered;" fn)
      (write-line "      : button { label = \"Configurar (BOTAC)\"; key = \"go_config\"; width = 20; }" fn)
      (write-line "      : button { label = \"Fechar\"; key = \"cancel\"; is_cancel = true; width = 12; }" fn)
      (write-line "    }" fn)
      (write-line "  }" fn)
      (write-line "}" fn)
      (close fn)

      (setq dclId (load_dialog dclFile))
      (if (new_dialog "bota_help_dialog" dclId)
        (progn
          (action_tile "go_config" "(done_dialog 2)")
          (action_tile "cancel"    "(done_dialog 0)")

          (setq status (start_dialog))
          (unload_dialog dclId)
          (vl-file-delete dclFile)

          ;; Se o usuario pressionou "Configurar", abre BOTAC
          (if (= status 2)
            (_bota_show_dcl)
          )
        )
        (progn
          (unload_dialog dclId)
          (vl-file-delete dclFile)
          (prompt "\nErro ao abrir a janela de ajuda DCL.")
        )
      )
    )
  )
)

(defun c:BOTAH ()
  (_bota_show_help)
  (princ)
)
;; ============================================================
;; COMANDO BOTA (Version 1.1 - corte direccional + JOIN cabecera)
;; Maniobra seleccionando manualmente el vertice objetivo
;; ============================================================

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
      (prompt (strcat "\nErro: " msg))
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
  (if (not (boundp '*BOTA_CONECTAR_CAB*)) (setq *BOTA_CONECTAR_CAB* T))

  (setq oldLuprec (getvar "LUPREC"))
  (setvar "LUPREC" 3)

  (prompt "\nBOTA - Manobra segmentada.")
  (prompt "\nSelecione a cabeceira perto da zona desejada: ")
  (setq sel (entsel))

  (if (not sel)
    (prompt "\nNenhuma cabeceira selecionada.")
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
        (prompt "\nA entidade selecionada nao e uma curva valida.")
        (progn

          (setq pCab (_pt3 pCab))

          (prompt "\nSelecione o vertice que deve tocar o circulo externo: ")
          (setq pVert (getpoint))

          (if (not pVert)
            (prompt "\nNenhum vertice selecionado.")
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
                    "\nParametros atuais:"
                    " Raio Interno=" (rtos *BOTA_RGIRO* 2 3)
                    " | Implemento=" (rtos *BOTA_IMPL* 2 3)
                    " | Segmentos=" (rtos *BOTA_DISTSEG* 2 3)
                    " | Con.Cabeceira=" (if *BOTA_CONECTAR_CAB* "Sim" "Nao")
                    "\nPressione Enter para usar estes parametros ou [C] para configurar: "
                  )
                )
              )

              (if (= cfg "C")
                (progn

                  ;; Radio de giro
                  (setq rGiro
                    (getdist
                      (strcat
                        "\nRaio de giro da maquina <"
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
                        "\nTamanho do implemento <"
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
                (prompt "\nDados invalidos. Revise raio de giro, implemento e distancia entre vertices.")
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
                    (prompt "\nNao foi possivel ler a polilinha.")
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

                          (if *BOTA_CONECTAR_CAB*
                            (progn
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
                              "\nAviso: nao foi possivel identificar o trecho da cabeceira contrario ao lado da bota."
                            )
                            (if (not joinOk)
                              (prompt
                                "\nAviso: o trecho correto foi identificado, mas o AutoCAD nao conseguiu executar JOIN."
                              )
                            )
                          )
                            )
                            (prompt "\nConexao com cabeceira desativada para BOTA.")
                          )

                          ;; Circulo externo:
                          ;; circulo normal, morado/magenta, sin convertir a polilinea.
                          (setq entBarra
                            (_circle-entity centro rBarra 6)
                          )

                          (prompt
                            (strcat
                              "\nRaio Interno: " (rtos rGiro 2 3)
                              " - Raio Externo: " (rtos rBarra 2 3)
                            )
                          )
                        )
                        (progn
                          (prompt "\nNao ha solucao valida na polilinha completa.")
                          (prompt "\nPode ser que o raio externo nao alcance o vertice selecionado com esse raio de giro.")
                          (prompt "\nTente aumentar o tamanho do implemento, selecionar outro vertice ou revisar o lado da cabeceira.")
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

;; ============================================================
;; COMANDO BOTA2 (Version 1.2 - corte direccional + conexion integrada)
;; Maniobra usando cabecera y linea de guiado
;; ============================================================

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
      (prompt (strcat "\nErro: " msg))
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
    ;; IMPORTANTE:
    ;; Busca somente intersecao REAL entre os offsets.
    ;; Nao estende as entidades.
    ;; Se nao existir intersecao real, devolve nil.

    (setq pts (b2_intersections e1 e2 0))

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
  (if (not (boundp '*BOTA_CONECTAR_CAB*)) (setq *BOTA_CONECTAR_CAB* T))

  (setq oldLuprec (getvar "LUPREC"))
  (setvar "LUPREC" 3)

  (prompt "\nBOTA2 - Manobra por linha guia.")
  (prompt "\nSelecione a cabeceira perto da zona desejada: ")
  (setq sel (entsel))

  (if (not sel)
    (prompt "\nNenhuma cabeceira selecionada.")
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
        (prompt "\nA entidade selecionada como cabeceira nao e uma curva valida.")
        (progn

          (setq pCab (b2_pt3 pCab))

          (prompt "\nSelecione a linha guia: ")
          (setq sel (entsel))

          (if (not sel)
            (prompt "\nNenhuma linha guia selecionada.")
            (progn

              (setq guia (car sel))

              (prompt "\nClique no lado onde deseja criar a manobra (lado oposto ao giro da maquina): ")
              (setq pSide (getpoint))

              (if (not pSide)
                (prompt "\nNenhum lado indicado.")
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
                        "\nParametros atuais:"
                        " Raio Interno=" (rtos *BOTA_RGIRO* 2 3)
                        " | Implemento=" (rtos *BOTA_IMPL* 2 3)
                        " | Seguranca=" (rtos *BOTA_SEGURIDAD* 2 3)
                        " | Segmentos=" (rtos *BOTA_DISTSEG* 2 3)
                        " | Con.Cabeceira=" (if *BOTA_CONECTAR_CAB* "Sim" "Nao")
                        "\nPressione Enter para usar estes parametros ou [C] para configurar: "
                      )
                    )
                  )

                  (if (= cfg "C")
                    (progn

                      (setq rGiro
                        (getdist
                          (strcat
                            "\nRaio de giro da maquina <"
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
                            "\nTamanho do implemento <"
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
                            "\nSeguranca para linha guia <"
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
                    (prompt "\nDados invalidos. Revise raio, implemento, seguranca e distancia entre vertices.")
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
                        (prompt "\nNao foi possivel criar o trecho local da linha guia dentro do raio de trabalho.")
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
                              (prompt "\nNao foi possivel criar os offsets.")
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
                                (prompt "\nNao foi encontrada intersecao entre os offsets dentro da zona de trabalho.")
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
                                    (prompt "\nNao foi possivel ler a cabeceira.")
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

                                          (if *BOTA_CONECTAR_CAB*
                                            (progn
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
                                              "\nAviso: nao foi possivel identificar o trecho da cabeceira contrario a pSide."
                                            )
                                            (if (not joinOk)
                                              (prompt
                                                "\nAviso: o trecho contrario a pSide foi identificado, mas o AutoCAD nao conseguiu executar JOIN."
                                              )
                                            )
                                          )
                                            )
                                            (prompt "\nConexao com cabeceira desativada para BOTA2.")
                                          )

                                          ;; Circulo externo normal, morado
                                          (setq entBarra
                                            (b2_circle_entity centro rBarra 6)
                                          )

                                          (prompt
                                            (strcat
                                              "\nRaio Interno: " (rtos rGiro 2 3)
                                              " - Raio Externo: " (rtos rBarra 2 3)
                                            )
                                          )
                                        )
                                        (progn
                                          (prompt "\nNao ha solucao valida dentro do raio de trabalho.")
                                          (prompt "\nTente clicar mais perto da zona desejada ou aumentar o raio de trabalho fixo no codigo.")
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

;; ============================================================
;; COMANDO BOTA3 (Version 2.3 - FILLET MAX-EXTERNO + BREAK guia)
;; Maniobra con FILLET geometrico MAX-EXTERNO hacia linea de guiado
;; ============================================================

(defun c:BOTA3 (/ *error* oldLuprec cfg sel ent guia guiaLocal pPick pCab pSide pVert
                  rGiro tamImpl seguridad rBarra distSeg filletR filletDistSeg
                  offCabDist offGuiaDist offCab offGuia tol radioTrabajo stepGuia
                  endParam i p1 p2 u n segLen side base rel tProj pFoot dPerp
                  maxDelta t1 t2 tc candidates candidate bestScore pTang centro
                  nSegGiro score c entGiro entBarra ptsGiro lastBefore lastAfter
                  entCab2 entCabJoin joinOk tmpCircle tmpGuide tmpFillet filletData
                  giroData pGapIni pGapFin pFilCirc pFilGuide pPickFilCirc pPickFilGuide pGuiaPick
                  pGuideBase vGuide halfGuide dirKeep ptsCircle
                  ptsFillet entFillet joinFilletOk filletSol filletCenter filletMode
                  filletArcDir filletSweep filletTravel guideModel ptsBota)

  (vl-load-com)

  ;; -------------------------
  ;; Restaurar variables
  ;; -------------------------

  (defun b3_restore ()
    (if oldLuprec
      (setvar "LUPREC" oldLuprec)
    )
  )

  (defun *error* (msg)
    ;; Limpia auxiliares de FILLET si el comando se interrumpe.
    (if (and tmpCircle (entget tmpCircle))
      (b3_delete_ent tmpCircle)
    )
    (if (and tmpFillet (entget tmpFillet))
      (b3_delete_ent tmpFillet)
    )
    (if (and tmpGuide (entget tmpGuide))
      (b3_delete_ent tmpGuide)
    )

    (b3_restore)
    (if (and msg (/= msg "Function cancelled") (/= msg "quit / exit abort"))
      (prompt (strcat "\nErro: " msg))
    )
    (princ)
  )

  ;; -------------------------
  ;; Funciones auxiliares
  ;; -------------------------

  (defun b3_pt3 (p)
    (list (car p) (cadr p) 0.0)
  )

  (defun b3_v+ (a b)
    (list (+ (car a) (car b)) (+ (cadr a) (cadr b)) 0.0)
  )

  (defun b3_v- (a b)
    (list (- (car a) (car b)) (- (cadr a) (cadr b)) 0.0)
  )

  (defun b3_v* (s v)
    (list (* s (car v)) (* s (cadr v)) 0.0)
  )

  (defun b3_dot (a b)
    (+ (* (car a) (car b)) (* (cadr a) (cadr b)))
  )

  (defun b3_len (v)
    (sqrt (+ (* (car v) (car v)) (* (cadr v) (cadr v))))
  )

  (defun b3_unit (v / l)
    (setq l (b3_len v))
    (if (> l 1e-12)
      (b3_v* (/ 1.0 l) v)
      nil
    )
  )

  (defun b3_ceil (x / i)
    (setq i (fix x))
    (if (> x i)
      (1+ i)
      i
    )
  )

  (defun b3_asin (x)
    (cond
      ((>= x 1.0) (/ pi 2.0))
      ((<= x -1.0) (- (/ pi 2.0)))
      (T (atan (/ x (sqrt (- 1.0 (* x x))))))
    )
  )

  (defun b3_nseg_inscribed (r distMax / x n)
    (setq x (/ distMax (* 2.0 r)))
    (if (> x 1.0)
      (setq x 1.0)
    )
    (setq n
      (b3_ceil
        (/ pi (b3_asin x))
      )
    )
    (max 8 n)
  )

  (defun b3_polarpt (c a r)
    (list
      (+ (car c) (* r (cos a)))
      (+ (cadr c) (* r (sin a)))
      0.0
    )
  )

  (defun b3_lwpoly_open (pts color / data)
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

  (defun b3_circle_gap_directional (cen r pAnchor pSide nSeg color
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
    (setq pPlus  (b3_polarpt cen (+ a step) r))
    (setq pMinus (b3_polarpt cen (- a step) r))

    ;; Vector desde la tangencia hacia el punto que indica el lado elegido.
    (setq vSide (b3_v- pSide pAnchor))

    ;; Cuanto apunta cada sentido hacia pSide.
    ;; El menor producto escalar corresponde al sentido mas OPUESTO a pSide.
    (setq scorePlus  (b3_dot (b3_v- pPlus  pAnchor) vSide))
    (setq scoreMinus (b3_dot (b3_v- pMinus pAnchor) vSide))

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
            (b3_polarpt cen (+ a (* dirKeep i step)) r)
          )
        )
      )
      (setq i (1+ i))
    )

    ;; El ultimo punto es el nuevo extremo despues de los dos segmentos cortados.
    (setq pGap (car (last pts)))
    (setq e (b3_lwpoly_open pts color))

    ;; Devuelve:
    ;; (entidad-del-arco punto-tangencia nuevo-extremo direccion-eliminada)
    (list e pAnchor pGap dir pts)
  )

  (defun b3_closest_point (e pt / p)
    ;; Punto real mas cercano de una curva a pt.
    (setq p
      (vl-catch-all-apply
        'vlax-curve-getClosestPointTo
        (list e pt)
      )
    )

    (if (vl-catch-all-error-p p)
      nil
      (b3_pt3 p)
    )
  )

  (defun b3_connect_points (p1 p2 color)
    ;; Conexion independiente entre el circulo recortado y la cabecera.
    ;; Se crea DESPUES de haber generado el hueco del circulo.
    (if (and p1 p2 (> (distance p1 p2) 1e-8))
      (b3_lwpoly_open (list p1 p2) color)
      nil
    )
  )

  (defun b3_circle_entity (cen r color / data)
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

  (defun b3_delete_ent (e)
    (if (and e (entget e))
      (vl-catch-all-apply
        'vla-delete
        (list (vlax-ename->vla-object e))
      )
    )
  )

  (defun b3_offset_one (e dist / obj res)
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

  (defun b3_dist_to_ent (e pt / p)
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
          (distance pt (b3_pt3 p))
        )
      )
      1e99
    )
  )

  (defun b3_offset_select (e dist pSide / objP objM enP enM dP dM)
    ;; Crea offset positivo y negativo.
    ;; Mantiene el que queda mas cerca del punto de lado indicado.

    (setq objP (b3_offset_one e dist))
    (setq objM (b3_offset_one e (- dist)))

    (setq enP (if objP (vlax-vla-object->ename objP) nil))
    (setq enM (if objM (vlax-vla-object->ename objM) nil))

    (cond
      ((and enP enM)
        (setq dP (b3_dist_to_ent enP pSide))
        (setq dM (b3_dist_to_ent enM pSide))

        (if (<= dP dM)
          (progn
            (b3_delete_ent enM)
            enP
          )
          (progn
            (b3_delete_ent enP)
            enM
          )
        )
      )

      (enP enP)
      (enM enM)
      (T nil)
    )
  )

  (defun b3_triplets (lst / out)
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

  (defun b3_intersections (e1 e2 mode / o1 o2 res)
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
          (b3_triplets res)
        )
      )
      nil
    )
  )

  (defun b3_best_point (pts pref / best bestD d p)
    (setq best nil)
    (setq bestD 1e99)

    (foreach p pts
      (setq p (b3_pt3 p))
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

  (defun b3_intersection_best (e1 e2 pref / pts)
    ;; IMPORTANTE:
    ;; Busca somente intersecao REAL entre os offsets.
    ;; Nao estende as entidades.
    ;; Se nao existir intersecao real, devolve nil.

    (setq pts (b3_intersections e1 e2 0))

    (if pts
      (b3_best_point pts pref)
      nil
    )
  )

  (defun b3_curve_local_points (e pRef radio step / p0 d0 total dStart dEnd d pts pt)
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
        (setq p0 (b3_pt3 p0))

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
                          (> (distance (b3_pt3 pt) pRef) radio))
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
                          (> (distance (b3_pt3 pt) pRef) radio))
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
                    (setq pts (append pts (list (b3_pt3 pt))))
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
                  (setq pts (append pts (list (b3_pt3 pt))))
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

  (defun b3_local_poly_from_curve (e pRef radio step / pts)
    ;; Crea una polilinea temporal con la parte local de la guia.

    (setq pts (b3_curve_local_points e pRef radio step))

    (if pts
      (b3_lwpoly_open pts nil)
      nil
    )
  )

  (defun b3_breakatpoint (e pt / oldOsm oldCmd pObj res)
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
          (setq pObj (b3_pt3 pObj))
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

  (defun b3_dir_from_joint (e pJoint / pStart pEnd dStart dEnd endPar total delta pTest v)
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
            (setq pStart (b3_pt3 pStart))
            (setq pEnd   (b3_pt3 pEnd))
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
                        (setq v (b3_v- (b3_pt3 pTest) pJoint))
                        (b3_unit v)
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

  (defun b3_select_opposite_pside (e1 e2 pJoint ptsGiro / vKeep v1 v2 s1 s2)
    ;; Selecciona SIEMPRE el tramo de cabecera contrario al lado de pSide.
    ;;
    ;; La funcion b3_circle_gap_directional ya decidio, usando pSide,
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
        (b3_unit
          (b3_v-
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
        (setq v1 (b3_dir_from_joint e1 pJoint))
        (setq v2 (b3_dir_from_joint e2 pJoint))

        (cond
          ((and v1 v2)
            ;; Menor producto escalar = tramo mas opuesto al
            ;; primer segmento conservado del circulo.
            (setq s1 (b3_dot v1 vKeep))
            (setq s2 (b3_dot v2 vKeep))
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

  (defun b3_join_two (eBase eAdd / oldCmd oldOsm res)
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
  ;; Funciones BOTA3 - FILLET
  ;; -------------------------

  (defun b3_norm_2pi (a)
    (while (< a 0.0)
      (setq a (+ a (* 2.0 pi)))
    )
    (while (>= a (* 2.0 pi))
      (setq a (- a (* 2.0 pi)))
    )
    a
  )

  (defun b3_keep_direction (cen r pAnchor pSide nSeg / a step pPlus pMinus vSide scorePlus scoreMinus dir)
    ;; Devuelve el sentido (+1 / -1) del circulo que se conserva.
    ;; El sentido eliminado es el contrario a pSide, igual que en BOTA2.
    (setq a    (angle cen pAnchor))
    (setq step (/ (* 2.0 pi) nSeg))

    (setq pPlus  (b3_polarpt cen (+ a step) r))
    (setq pMinus (b3_polarpt cen (- a step) r))
    (setq vSide  (b3_v- pSide pAnchor))

    (setq scorePlus  (b3_dot (b3_v- pPlus  pAnchor) vSide))
    (setq scoreMinus (b3_dot (b3_v- pMinus pAnchor) vSide))

    (if (<= scorePlus scoreMinus)
      (setq dir 1.0)   ;; este seria el lado eliminado
      (setq dir -1.0)
    )

    (- dir)            ;; sentido que permanece
  )

  (defun b3_circle_arc_points (cen r pStart pEnd dir distMax / a0 a1 delta x maxAng n stepA i pts)
    ;; Segmenta solamente el arco util del circulo interno.
    ;; pStart = pTang sobre cabecera
    ;; pEnd   = punto exacto de tangencia con el fillet
    ;; dir    = sentido del arco a conservar (+1 / -1)
    ;; distMax = distancia maxima entre vertices del circulo

    (setq a0 (angle cen pStart))
    (setq a1 (angle cen pEnd))

    (if (> dir 0.0)
      (setq delta (b3_norm_2pi (- a1 a0)))
      (setq delta (b3_norm_2pi (- a0 a1)))
    )

    ;; Evita una geometria degenerada.
    (if (< delta 1e-10)
      (setq delta (* 2.0 pi))
    )

    ;; Angulo maximo para que la cuerda sea <= distMax.
    (setq x (/ distMax (* 2.0 r)))
    (if (> x 1.0) (setq x 1.0))
    (setq maxAng (* 2.0 (b3_asin x)))
    (if (< maxAng 1e-10)
      (setq maxAng delta)
    )

    (setq n (max 1 (b3_ceil (/ delta maxAng))))
    (setq stepA (/ delta n))

    (setq pts (list pStart))
    (setq i 1)

    (repeat (1- n)
      (setq pts
        (append pts
          (list
            (b3_polarpt
              cen
              (+ a0 (* dir i stepA))
              r
            )
          )
        )
      )
      (setq i (1+ i))
    )

    ;; Asegura tangencia exacta con el fillet.
    (setq pts (append pts (list pEnd)))
    pts
  )

  (defun b3_arc_segment_points (e pFrom distMax / pS pE endPar total n stepD i pts d)
    ;; Convierte un ARC real en una lista de puntos.
    ;; La separacion sobre el arco es <= distMax.
    ;; La lista se ordena comenzando en pFrom.

    (setq pS
      (vl-catch-all-apply
        'vlax-curve-getStartPoint
        (list e)
      )
    )
    (setq pE
      (vl-catch-all-apply
        'vlax-curve-getEndPoint
        (list e)
      )
    )

    (if (or (vl-catch-all-error-p pS)
            (vl-catch-all-error-p pE))
      nil
      (progn
        (setq pS (b3_pt3 pS))
        (setq pE (b3_pt3 pE))

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
                    (<= total 1e-10))
              nil
              (progn
                (setq n (max 1 (b3_ceil (/ total distMax))))
                (setq stepD (/ total n))
                (setq pts nil)
                (setq i 0)

                ;; Si pFrom esta mas cerca del inicio, recorre normal.
                ;; Si esta mas cerca del final, recorre inverso.
                (if (<= (distance pFrom pS) (distance pFrom pE))
                  (progn
                    (repeat (1+ n)
                      (setq d (* i stepD))
                      (if (> d total) (setq d total))
                      (setq pts
                        (append pts
                          (list
                            (b3_pt3
                              (vlax-curve-getPointAtDist e d)
                            )
                          )
                        )
                      )
                      (setq i (1+ i))
                    )
                  )
                  (progn
                    (repeat (1+ n)
                      (setq d (- total (* i stepD)))
                      (if (< d 0.0) (setq d 0.0))
                      (setq pts
                        (append pts
                          (list
                            (b3_pt3
                              (vlax-curve-getPointAtDist e d)
                            )
                          )
                        )
                      )
                      (setq i (1+ i))
                    )
                  )
                )

                pts
              )
            )
          )
        )
      )
    )
  )

  (defun b3_curve_tangent_at_pick (e pPick / p par der)
    ;; Vector tangente local de la guia exactamente en el tramo seleccionado.
    ;; El punto de click del usuario sirve para decidir QUE tramo de una
    ;; polilinea debe participar en el fillet.
    (setq p
      (vl-catch-all-apply
        'vlax-curve-getClosestPointTo
        (list e pPick)
      )
    )

    (if (vl-catch-all-error-p p)
      nil
      (progn
        (setq p (b3_pt3 p))
        (setq par
          (vl-catch-all-apply
            'vlax-curve-getParamAtPoint
            (list e p)
          )
        )
        (if (vl-catch-all-error-p par)
          nil
          (progn
            (setq der
              (vl-catch-all-apply
                'vlax-curve-getFirstDeriv
                (list e par)
              )
            )
            (if (vl-catch-all-error-p der)
              nil
              (b3_unit (b3_pt3 der))
            )
          )
        )
      )
    )
  )

  (defun b3_temp_extended_line (p dir halfLen / p1 p2)
    ;; LINEA TEMPORAL extendida en ambos sentidos.
    ;; Su unica funcion es impedir que FILLET se "enganche" a la punta de
    ;; la linea de guiado. La geometria final sigue usando la guia original.
    (if (and p dir (> halfLen 0.0))
      (progn
        (setq p1 (b3_v- p (b3_v* halfLen dir)))
        (setq p2 (b3_v+ p (b3_v* halfLen dir)))
        (entmakex
          (list
            (cons 0 "LINE")
            (cons 100 "AcDbEntity")
            (cons 8 (getvar "CLAYER"))
            (cons 100 "AcDbLine")
            (cons 10 p1)
            (cons 11 p2)
          )
        )
      )
      nil
    )
  )

  (defun b3_fillet_temp (eCircle eGuide pCircle pGuide rad
                         / oldRad oldTrim oldCmd oldOsm before after res)
    ;; Crea un FILLET real de AutoCAD SIN recortar las entidades de referencia.
    ;; Devuelve el ARC creado o nil.

    (setq oldRad  (getvar "FILLETRAD"))
    (setq oldTrim (getvar "TRIMMODE"))
    (setq oldCmd  (getvar "CMDECHO"))
    (setq oldOsm  (getvar "OSMODE"))

    (setvar "FILLETRAD" rad)
    (setvar "CMDECHO" 0)
    (setvar "OSMODE" 0)

    (setq before (entlast))

    (initcommandversion 1)

    (setq res
      (vl-catch-all-apply
        'vl-cmdf
        (list
          "_.FILLET"
          "_T" "_N"
          (list eCircle pCircle)
          (list eGuide  pGuide)
        )
      )
    )

    (setq after (entlast))

    (setvar "FILLETRAD" oldRad)
    (setvar "TRIMMODE" oldTrim)
    (setvar "CMDECHO" oldCmd)
    (setvar "OSMODE" oldOsm)

    (if
      (and
        (not (vl-catch-all-error-p res))
        after
        (/= after before)
        (entget after)
        (= (cdr (assoc 0 (entget after))) "ARC")
      )
      after
      nil
    )
  )

  (defun b3_fillet_direct (eGuide pGuide eTurn pTurn rad
                           / oldRad oldTrim oldCmd oldOsm before after res)
    ;; Ejecuta FILLET de la MISMA FORMA que el usuario lo hace manualmente:
    ;;   1) selecciona la linea de guiado en un PUNTO concreto;
    ;;   2) selecciona el circulo/polilinea en un PUNTO concreto.
    ;;
    ;; Los puntos de seleccion son fundamentales: AutoCAD los usa para
    ;; decidir que lado de cada objeto debe recortar y que solucion de fillet
    ;; debe generar. No se utilizan endpoints ni lineas temporales.

    (setq oldRad  (getvar "FILLETRAD"))
    (setq oldTrim (getvar "TRIMMODE"))
    (setq oldCmd  (getvar "CMDECHO"))
    (setq oldOsm  (getvar "OSMODE"))

    (setvar "FILLETRAD" rad)
    (setvar "TRIMMODE" 1)
    (setvar "CMDECHO" 0)
    (setvar "OSMODE" 0)

    (setq before (entlast))
    (initcommandversion 1)

    (setq res
      (vl-catch-all-apply
        'vl-cmdf
        (list
          "_.FILLET"
          (list eGuide pGuide)
          (list eTurn  pTurn)
        )
      )
    )

    (setq after (entlast))

    (setvar "FILLETRAD" oldRad)
    (setvar "TRIMMODE" oldTrim)
    (setvar "CMDECHO" oldCmd)
    (setvar "OSMODE" oldOsm)

    ;; Para dos entidades diferentes FILLET normalmente crea un ARC nuevo.
    ;; Si no aparece un ARC, devolvemos nil para no reconstruir geometria
    ;; sobre una solucion que no podemos identificar con seguridad.
    (if
      (and
        (not (vl-catch-all-error-p res))
        after
        (/= after before)
        (entget after)
        (= (cdr (assoc 0 (entget after))) "ARC")
      )
      after
      nil
    )
  )

  (defun b3_fillet_endpoints (eArc cen r eGuide / pS pE errS errE dGS dGE pCirc pGuide)
    ;; Identifica que extremo del fillet toca el circulo y cual toca la guia.

    (setq pS
      (vl-catch-all-apply
        'vlax-curve-getStartPoint
        (list eArc)
      )
    )
    (setq pE
      (vl-catch-all-apply
        'vlax-curve-getEndPoint
        (list eArc)
      )
    )

    (if (or (vl-catch-all-error-p pS)
            (vl-catch-all-error-p pE))
      nil
      (progn
        (setq pS (b3_pt3 pS))
        (setq pE (b3_pt3 pE))

        (setq errS (abs (- (distance pS cen) r)))
        (setq errE (abs (- (distance pE cen) r)))

        ;; En condiciones normales el menor error radial identifica
        ;; el extremo sobre el circulo.
        (if (<= errS errE)
          (progn
            (setq pCirc pS)
            (setq pGuide pE)
          )
          (progn
            (setq pCirc pE)
            (setq pGuide pS)
          )
        )

        ;; Validacion secundaria contra la guia.
        (setq dGS (b3_dist_to_ent eGuide pS))
        (setq dGE (b3_dist_to_ent eGuide pE))

        ;; Si la clasificacion radial fuera ambigua, prioriza el extremo
        ;; realmente mas cercano a la guia.
        (if (< (abs (- errS errE)) 1e-7)
          (if (<= dGS dGE)
            (progn
              (setq pGuide pS)
              (setq pCirc pE)
            )
            (progn
              (setq pGuide pE)
              (setq pCirc pS)
            )
          )
        )

        (list pCirc pGuide)
      )
    )
  )


  ;; -------------------------
  ;; BOTA3 v2 - Solver geometrico de FILLET
  ;; -------------------------

  (defun b3_rot90ccw (v)
    (list (- (cadr v)) (car v) 0.0)
  )

  (defun b3_rot90cw (v)
    (list (cadr v) (- (car v)) 0.0)
  )

  (defun b3_arc_delta_dir (cen pStart pEnd dir / a0 a1)
    ;; Barrido positivo en radianes siguiendo dir (+1 CCW / -1 CW).
    (setq a0 (angle cen pStart))
    (setq a1 (angle cen pEnd))
    (if (> dir 0.0)
      (b3_norm_2pi (- a1 a0))
      (b3_norm_2pi (- a0 a1))
    )
  )

  (defun b3_arc_points_center (cen r pStart pEnd dir distMax / delta x maxAng n stepA a0 i pts)
    ;; Segmenta un arco definido geometricamente por centro/radio/extremos.
    ;; Mantiene exactamente pStart y pEnd.
    (setq delta (b3_arc_delta_dir cen pStart pEnd dir))

    (if (< delta 1e-10)
      nil
      (progn
        (setq x (/ distMax (* 2.0 r)))
        (if (> x 1.0) (setq x 1.0))
        (setq maxAng (* 2.0 (b3_asin x)))
        (if (< maxAng 1e-10) (setq maxAng delta))

        (setq n (max 1 (b3_ceil (/ delta maxAng))))
        (setq stepA (/ delta n))
        (setq a0 (angle cen pStart))
        (setq pts (list pStart))
        (setq i 1)

        (repeat (1- n)
          (setq pts
            (append pts
              (list
                (b3_polarpt cen (+ a0 (* dir i stepA)) r)
              )
            )
          )
          (setq i (1+ i))
        )

        (append pts (list pEnd))
      )
    )
  )

  (defun b3_guide_model_near_circle (e cen / p par der u n)
    ;; Obtiene la recta local de la guia en el punto geometricamente mas
    ;; cercano al CENTRO del circulo. El click del usuario no participa.
    ;; Devuelve (p0 u n), con u tangente unitario y n normal unitario.
    (setq p
      (vl-catch-all-apply
        'vlax-curve-getClosestPointTo
        (list e cen)
      )
    )

    (if (vl-catch-all-error-p p)
      nil
      (progn
        (setq p (b3_pt3 p))
        (setq par
          (vl-catch-all-apply
            'vlax-curve-getParamAtPoint
            (list e p)
          )
        )

        (if (vl-catch-all-error-p par)
          nil
          (progn
            (setq der
              (vl-catch-all-apply
                'vlax-curve-getFirstDeriv
                (list e par)
              )
            )

            (if (vl-catch-all-error-p der)
              nil
              (progn
                (setq u (b3_unit (b3_pt3 der)))
                (if u
                  (progn
                    (setq n (b3_rot90ccw u))
                    (list p u n)
                  )
                  nil
                )
              )
            )
          )
        )
      )
    )
  )

  (defun b3_project_to_line (pt p0 u)
    (b3_v+
      p0
      (b3_v* (b3_dot (b3_v- pt p0) u) u)
    )
  )

  (defun b3_point_really_on_curve (e pt maxErr / q)
    ;; Evita aceptar una solucion ubicada solamente en la prolongacion
    ;; matematica de la guia. El punto de tangencia debe pertenecer a la
    ;; entidad real seleccionada.
    (setq q (b3_closest_point e pt))
    (and q (<= (distance q pt) maxErr))
  )

  (defun b3_fillet_externality (turnC turnR filC filR pStart pEnd dir
                                 / delta a0 fracs frac pt clear sum count)
    ;; Mide cuanto se mantiene el arco de FILLET por FUERA del circulo interno.
    ;;
    ;; Todos los candidatos externos tocan el circulo en pStart, por lo que
    ;; en ese punto la separacion siempre es 0. Para distinguir las distintas
    ;; soluciones externas, se muestrean varios puntos INTERIORES del arco y
    ;; se calcula la separacion radial media respecto al circulo de giro.
    ;;
    ;; Mayor valor = FILLET mas exterior / menos efecto de entrar al circulo.

    (setq delta (b3_arc_delta_dir filC pStart pEnd dir))

    (if (<= delta 1e-10)
      0.0
      (progn
        (setq a0 (angle filC pStart))
        (setq fracs (list 0.15 0.30 0.45 0.60 0.75 0.90))
        (setq sum 0.0)
        (setq count 0)

        (foreach frac fracs
          (setq pt
            (b3_polarpt
              filC
              (+ a0 (* dir delta frac))
              filR
            )
          )
          (setq clear (- (distance pt turnC) turnR))
          (setq sum (+ sum clear))
          (setq count (1+ count))
        )

        (if (> count 0)
          (/ sum count)
          0.0
        )
      )
    )
  )

  (defun b3_fillet_solver (cen r pTang pSide pVert guia filletR nSegGiro
                           / model p0 u n dirKeep modes mode dCenters sgn base w t0 foot
                             d2 h2 h ds f vCF pCirc pGuide turnRad turnTan filRad
                             tanCCW tanCW matchCCW matchCW arcDir sweep travel guideErr
                             modePenalty travelPenalty score externality candidates cand best bestScore
                             bestExternality candExternality maxGuideErr aTmp)
    ;; Busca TODAS las soluciones geometricas de un arco de radio filletR
    ;; tangente al circulo (cen,r) y a la recta local de la guia.
    ;;
    ;; No usa el punto de click para elegir el FILLET.
    ;;
    ;; BOTA3 v2.2: FILLET MAXIMAMENTE EXTERNO POR SEPARACION RADIAL.
    ;;
    ;; Se acepta UNICAMENTE tangencia EXTERNA entre el circulo interno
    ;; y el circulo geometrico del FILLET. Esto obliga a que ambos circulos
    ;; se toquen por fuera (distancia entre centros = r + filletR), evitando
    ;; que el FILLET grande envuelva al circulo interno o genere el efecto
    ;; visual de arco entrando dentro de la maniobra.
    ;;
    ;; Entre las soluciones externas validas se elige PRIMERO la que sea
    ;; MAXIMAMENTE EXTERNA respecto al circulo interno. Es decir: el arco
    ;; que, despues de abandonar la tangencia, mantiene la mayor separacion
    ;; radial media respecto al circulo de giro.
    ;;
    ;; Solamente si dos soluciones tienen practicamente la misma externalidad
    ;; se usa la puntuacion geometrica secundaria (pVert, sweep, recorrido).
    ;;
    ;; IMPORTANTE: no existe fallback a tangencia interna. Si no hay una
    ;; solucion externa valida sobre la guia REAL, el solver devuelve nil.

    (setq model (b3_guide_model_near_circle guia cen))
    (if (not model)
      nil
      (progn
        (setq p0 (car model))
        (setq u  (cadr model))
        (setq n  (caddr model))
        (setq dirKeep (b3_keep_direction cen r pTang pSide nSegGiro))
        (setq candidates nil)
        (setq maxGuideErr 0.050)

        ;; Cada elemento: (modo distancia-centros penalizacion)
        ;; modo 1 = tangencia EXTERNA.
        ;;
        ;; Para que el FILLET sea maximamente externo al circulo interno,
        ;; la distancia entre centros debe ser exactamente r + filletR.
        ;; No agregamos el modo de tangencia interna como respaldo.
        (setq modes
          (list
            (list 1 (+ filletR r) 0.0)
          )
        )

        (foreach mode modes
          (setq dCenters   (cadr mode))
          (setq modePenalty (caddr mode))

          ;; El centro del FILLET debe estar sobre una de las dos rectas
          ;; paralelas a la guia, separadas exactamente filletR.
          (foreach sgn (list 1.0 -1.0)
            (setq base (b3_v+ p0 (b3_v* (* sgn filletR) n)))

            ;; Interseccion: recta offset vs circulo de centros posibles
            ;; alrededor del centro de giro.
            (setq w    (b3_v- base cen))
            (setq t0   (- (b3_dot w u)))
            (setq foot (b3_v+ base (b3_v* t0 u)))
            (setq d2   (* (b3_len (b3_v- foot cen)) (b3_len (b3_v- foot cen))))
            (setq h2   (- (* dCenters dCenters) d2))

            (if (>= h2 -1e-8)
              (progn
                (setq h (sqrt (max 0.0 h2)))
                (setq ds
                  (if (< h 1e-9)
                    (list 0.0)
                    (list h (- h))
                  )
                )

                (foreach aTmp ds
                  (setq f (b3_v+ foot (b3_v* aTmp u)))
                  (setq vCF (b3_unit (b3_v- f cen)))

                  (if vCF
                    (progn
                      ;; Tangencia con el circulo interno.
                      (if (= (car mode) 0)
                        ;; Tangencia interna: si el FILLET es mayor, el punto
                        ;; queda en el lado opuesto al centro del FILLET.
                        (if (> filletR r)
                          (setq pCirc (b3_v- cen (b3_v* r vCF)))
                          (setq pCirc (b3_v+ cen (b3_v* r vCF)))
                        )
                        ;; Tangencia externa.
                        (setq pCirc (b3_v+ cen (b3_v* r vCF)))
                      )

                      ;; Tangencia con la recta de guiado.
                      (setq pGuide (b3_v- f (b3_v* (* sgn filletR) n)))

                      ;; La solucion debe tocar la entidad REAL, no su punta
                      ;; ni una prolongacion imaginaria.
                      (if (b3_point_really_on_curve guia pGuide maxGuideErr)
                        (progn
                          ;; Tangente de salida del circulo siguiendo el sentido
                          ;; real que BOTA conserva desde pTang.
                          (setq turnRad (b3_unit (b3_v- pCirc cen)))
                          (setq turnTan
                            (if (> dirKeep 0.0)
                              (b3_rot90ccw turnRad)
                              (b3_rot90cw turnRad)
                            )
                          )

                          ;; Elige CW/CCW del FILLET por CONTINUIDAD TANGENCIAL,
                          ;; no por proximidad de un click.
                          (setq filRad (b3_unit (b3_v- pCirc f)))
                          (setq tanCCW (b3_rot90ccw filRad))
                          (setq tanCW  (b3_rot90cw  filRad))
                          (setq matchCCW (b3_dot turnTan tanCCW))
                          (setq matchCW  (b3_dot turnTan tanCW))

                          (if (>= matchCCW matchCW)
                            (progn
                              (setq arcDir 1.0)
                              (setq sweep (b3_arc_delta_dir f pCirc pGuide 1.0))
                            )
                            (progn
                              (setq arcDir -1.0)
                              (setq sweep (b3_arc_delta_dir f pCirc pGuide -1.0))
                            )
                          )

                          ;; Solo acepta continuidad practicamente tangente y el
                          ;; arco corto tipico de FILLET (<= 180 grados).
                          (if (and
                                (> (max matchCCW matchCW) 0.98)
                                (> sweep 1e-6)
                                (<= sweep (+ pi 1e-6))
                              )
                            (progn
                              (setq travel
                                (b3_arc_delta_dir cen pTang pCirc dirKeep)
                              )

                              ;; Evita una salida degenerada casi en pTang.
                              (if (> travel 0.05)
                                (progn
                                  (setq guideErr
                                    (distance
                                      pGuide
                                      (b3_closest_point guia pGuide)
                                    )
                                  )

                                  ;; Externalidad REAL del arco.
                                  ;; Este es ahora el criterio PRINCIPAL.
                                  (setq externality
                                    (b3_fillet_externality
                                      cen r f filletR pCirc pGuide arcDir
                                    )
                                  )

                                  ;; Puntuacion SECUNDARIA. Ya no se fuerza el arco
                                  ;; mas corto, porque eso era precisamente lo que
                                  ;; tendia a generar la solucion amarilla de la prueba.
                                  ;; pVert sigue ayudando a resolver empates geometricos.
                                  (setq travelPenalty
                                    (if (< travel 0.50)
                                      (* 100.0 (- 0.50 travel))
                                      0.0
                                    )
                                  )

                                  (setq score
                                    (+ modePenalty
                                       (* 0.50 (distance pCirc pVert))
                                       (* 0.15 (distance pGuide pVert))
                                       (* 1.00 sweep)
                                       travelPenalty
                                       (* 1000.0 guideErr)
                                    )
                                  )

                                  ;; (score centroFillet pCirc pGuide arcDir sweep
                                  ;;  modo travel dirKeep externalidad)
                                  (setq candidates
                                    (cons
                                      (list score f pCirc pGuide arcDir sweep
                                            (car mode) travel dirKeep externality)
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
        )

        (if candidates
          (progn
            (setq best (car candidates))
            (setq bestScore (car best))
            (setq bestExternality (nth 9 best))

            (foreach cand candidates
              (setq candExternality (nth 9 cand))

              ;; Criterio 1: MAXIMA externalidad.
              ;; Se deja una tolerancia pequena para no cambiar de solucion
              ;; por ruido numerico insignificante.
              (if (> candExternality (+ bestExternality 0.001))
                (progn
                  (setq best cand)
                  (setq bestScore (car cand))
                  (setq bestExternality candExternality)
                )
                ;; Criterio 2: si la externalidad es practicamente igual,
                ;; utiliza la puntuacion geometrica secundaria.
                (if (and
                      (<= (abs (- candExternality bestExternality)) 0.001)
                      (< (car cand) bestScore)
                    )
                  (progn
                    (setq best cand)
                    (setq bestScore (car cand))
                    (setq bestExternality candExternality)
                  )
                )
              )
            )
            best
          )
          nil
        )
      )
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
  (if (not *BOTA_RGIRO*)       (setq *BOTA_RGIRO* 10.000))
  (if (not *BOTA_IMPL*)        (setq *BOTA_IMPL* 36.578))
  (if (not *BOTA_DISTSEG*)     (setq *BOTA_DISTSEG* 0.700))
  (if (not *BOTA_SEGURIDAD*)   (setq *BOTA_SEGURIDAD* 0.500))
  (if (not (boundp '*BOTA_CONECTAR_CAB*)) (setq *BOTA_CONECTAR_CAB* T))

  ;; Parametros independientes del FILLET
  (if (not *BOTA_FILLET_R*)     (setq *BOTA_FILLET_R* 30.000))
  (if (not *BOTA_FILLET_SEG*)   (setq *BOTA_FILLET_SEG* 1.500))

  (setq oldLuprec (getvar "LUPREC"))
  (setvar "LUPREC" 3)

  (prompt "\nBOTA3 - Manobra com FILLET geometrico MAX-EXTERNO para linha guia.")
  (prompt "\nSelecione a cabeceira perto da zona desejada: ")
  (setq sel (entsel))

  (if (not sel)
    (prompt "\nNenhuma cabeceira selecionada.")
    (progn

      (setq ent   (car sel))
      (setq pPick (b3_pt3 (cadr sel)))

      (setq pCab
        (vl-catch-all-apply
          'vlax-curve-getClosestPointTo
          (list ent pPick)
        )
      )

      (if (vl-catch-all-error-p pCab)
        (prompt "\nA entidade selecionada como cabeceira nao e uma curva valida.")
        (progn

          (setq pCab (b3_pt3 pCab))

          (prompt "\nSelecione a linha guia: ")
          (setq sel (entsel))

          (if (not sel)
            (prompt "\nNenhuma linha guia selecionada.")
            (progn

              (setq guia      (car sel))
              ;; El click solo selecciona la entidad. La posicion del FILLET
              ;; se resolvera geometricamente despues, sin depender del pick.
              (setq pGuiaPick (b3_pt3 (cadr sel)))

              (prompt "\nClique no lado onde deseja criar a manobra (lado oposto ao giro da maquina): ")
              (setq pSide (getpoint))

              (if (not pSide)
                (prompt "\nNenhum lado indicado.")
                (progn

                  (setq pSide (b3_pt3 pSide))

                  ;; -------------------------------------------------
                  ;; Configuracion de parametros
                  ;;
                  ;; Enter = usa todos los valores guardados
                  ;; C     = parametros generales de BOTA3
                  ;; B     = parametros exclusivos del FILLET
                  ;; -------------------------------------------------

                  (initget "C B")
                  (setq cfg
                    (getkword
                      (strcat
                        "\nParametros atuais:"
                        " Raio Interno=" (rtos *BOTA_RGIRO* 2 3)
                        " | Implemento=" (rtos *BOTA_IMPL* 2 3)
                        " | Seguranca=" (rtos *BOTA_SEGURIDAD* 2 3)
                        " | Seg.Circulo=" (rtos *BOTA_DISTSEG* 2 3)
                        " | Fillet R=" (rtos *BOTA_FILLET_R* 2 3)
                        " | Seg.Fillet=" (rtos *BOTA_FILLET_SEG* 2 3)
                        " | Con.Cabeceira=" (if *BOTA_CONECTAR_CAB* "Sim" "Nao")
                        "\nPressione Enter para continuar ou [C] parametros gerais / [B] parametros do fillet: "
                      )
                    )
                  )

                  (cond
                    ((= cfg "C")
                      (progn
                        (setq rGiro
                          (getdist
                            (strcat
                              "\nRaio de giro da maquina <"
                              (rtos *BOTA_RGIRO* 2 3)
                              ">: "
                            )
                          )
                        )
                        (if rGiro
                          (setq *BOTA_RGIRO* rGiro)
                        )

                        (setq tamImpl
                          (getdist
                            (strcat
                              "\nTamanho do implemento <"
                              (rtos *BOTA_IMPL* 2 3)
                              ">: "
                            )
                          )
                        )
                        (if tamImpl
                          (setq *BOTA_IMPL* tamImpl)
                        )

                        (setq seguridad
                          (getdist
                            (strcat
                              "\nSeguranca para linha guia <"
                              (rtos *BOTA_SEGURIDAD* 2 3)
                              ">: "
                            )
                          )
                        )
                        (if seguridad
                          (setq *BOTA_SEGURIDAD* seguridad)
                        )

                        (setq distSeg
                          (getdist
                            (strcat
                              "\nDistancia maxima entre vertices do circulo <"
                              (rtos *BOTA_DISTSEG* 2 3)
                              ">: "
                            )
                          )
                        )
                        (if distSeg
                          (setq *BOTA_DISTSEG* distSeg)
                        )
                      )
                    )

                    ((= cfg "B")
                      (progn
                        (setq filletR
                          (getdist
                            (strcat
                              "\nRaio do fillet <"
                              (rtos *BOTA_FILLET_R* 2 3)
                              ">: "
                            )
                          )
                        )
                        (if filletR
                          (setq *BOTA_FILLET_R* filletR)
                        )

                        (setq filletDistSeg
                          (getdist
                            (strcat
                              "\nDistancia maxima entre vertices do fillet <"
                              (rtos *BOTA_FILLET_SEG* 2 3)
                              ">: "
                            )
                          )
                        )
                        (if filletDistSeg
                          (setq *BOTA_FILLET_SEG* filletDistSeg)
                        )
                      )
                    )
                  )

                  ;; Carga los valores definitivos para esta ejecucion.
                  (setq rGiro        *BOTA_RGIRO*)
                  (setq tamImpl      *BOTA_IMPL*)
                  (setq seguridad    *BOTA_SEGURIDAD*)
                  (setq distSeg      *BOTA_DISTSEG*)
                  (setq filletR      *BOTA_FILLET_R*)
                  (setq filletDistSeg *BOTA_FILLET_SEG*)

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
                          (not filletR) (not filletDistSeg)
                          (<= rGiro 0.0)
                          (<= tamImpl 0.0)
                          (< seguridad 0.0)
                          (<= rBarra 0.0)
                          (<= distSeg 0.0)
                          (<= filletR 0.0)
                          (<= filletDistSeg 0.0))
                    (prompt "\nDados invalidos. Revise parametros gerais e parametros do fillet.")
                    (progn

                      ;; Guarda valores para reutilizar.
                      (setq *BOTA_RGIRO*      rGiro)
                      (setq *BOTA_IMPL*       tamImpl)
                      (setq *BOTA_SEGURIDAD*  seguridad)
                      (setq *BOTA_DISTSEG*    distSeg)
                      (setq *BOTA_FILLET_R*   filletR)
                      (setq *BOTA_FILLET_SEG* filletDistSeg)

                      ;; Crea tramo local temporal de la guia dentro del radio de trabajo
                      (setq guiaLocal
                        (b3_local_poly_from_curve guia pCab radioTrabajo stepGuia)
                      )

                      (if (not guiaLocal)
                        (prompt "\nNao foi possivel criar o trecho local da linha guia dentro do raio de trabalho.")
                        (progn

                          ;; Offsets temporales
                          (setq offCab
                            (b3_offset_select ent offCabDist pSide)
                          )

                          (setq offGuia
                            (b3_offset_select guiaLocal offGuiaDist pSide)
                          )

                          (if (or (not offCab) (not offGuia))
                            (progn
                              (if offCab (b3_delete_ent offCab))
                              (if offGuia (b3_delete_ent offGuia))
                              (if guiaLocal (b3_delete_ent guiaLocal))
                              (prompt "\nNao foi possivel criar os offsets.")
                            )
                            (progn

                              ;; Punto calculado por interseccion de offsets.
                              ;; Se toma la interseccion mas cercana al click sobre la cabecera.
                              (setq pVert
                                (b3_intersection_best offCab offGuia pCab)
                              )

                              ;; Borra auxiliares temporales
                              (b3_delete_ent offCab)
                              (b3_delete_ent offGuia)
                              (b3_delete_ent guiaLocal)

                              (if (not pVert)
                                (prompt "\nNao foi encontrada intersecao entre os offsets dentro da zona de trabalho.")
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
                                    (prompt "\nNao foi possivel ler a cabeceira.")
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

                                            (setq p1 (b3_pt3 p1))
                                            (setq p2 (b3_pt3 p2))

                                            (setq u (b3_unit (b3_v- p2 p1)))

                                            (if u
                                              (progn

                                                (setq segLen (distance p1 p2))

                                                (if (> segLen tol)
                                                  (progn

                                                    ;; Normal del tramo.
                                                    (setq n (list (- (cadr u)) (car u) 0.0))

                                                    ;; Centro del lado donde esta el punto calculado.
                                                    (setq side
                                                      (if (>= (b3_dot (b3_v- pVert p1) n) 0.0)
                                                        1.0
                                                        -1.0
                                                      )
                                                    )

                                                    ;; Linea de centros paralela al tramo.
                                                    (setq base
                                                      (b3_v+ p1 (b3_v* (* side rGiro) n))
                                                    )

                                                    ;; Proyeccion del punto calculado sobre la linea de centros.
                                                    (setq rel   (b3_v- pVert base))
                                                    (setq tProj (b3_dot rel u))
                                                    (setq pFoot (b3_v+ base (b3_v* tProj u)))
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
                                                                (b3_v+ p1 (b3_v* tc u))
                                                              )

                                                              ;; Centro comun.
                                                              (setq centro
                                                                (b3_v+ pTang (b3_v* (* side rGiro) n))
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

                                          ;; Segmentacion base del circulo interno
                                          (setq nSegGiro (b3_nseg_inscribed rGiro distSeg))

                                          ;; -------------------------------------------------
                                          ;; 1) SOLVER GEOMETRICO DEL FILLET
                                          ;; -------------------------------------------------
                                          ;; El click sobre la guia NO decide donde se hace el fillet.
                                          ;; BOTA3 busca todas las soluciones tangentes posibles entre:
                                          ;;   - circulo interno (centro, rGiro)
                                          ;;   - linea de guiado
                                          ;;   - radio filletR
                                          ;; y selecciona la solucion coherente con pSide/pVert.
                                          (setq filletSol
                                            (b3_fillet_solver
                                              centro rGiro pTang pSide pVert guia
                                              filletR nSegGiro
                                            )
                                          )

                                          (if (not filletSol)
                                            (prompt
                                              "\nNao foi encontrada uma solucao EXTERNA valida de FILLET sobre a linha guia real."
                                            )
                                            (progn
                                              (setq filletCenter (nth 1 filletSol))
                                              (setq pFilCirc     (nth 2 filletSol))
                                              (setq pFilGuide    (nth 3 filletSol))
                                              (setq filletArcDir (nth 4 filletSol))
                                              (setq filletSweep  (nth 5 filletSol))
                                              (setq filletMode   (nth 6 filletSol))
                                              (setq filletTravel (nth 7 filletSol))
                                              (setq dirKeep      (nth 8 filletSol))

                                              ;; -------------------------------------------------
                                              ;; 2) CONSTRUYE LA GEOMETRIA FINAL
                                              ;; -------------------------------------------------
                                              ;; Circulo: pTang -> punto exacto de tangencia FILLET.
                                              (setq ptsCircle
                                                (b3_circle_arc_points
                                                  centro rGiro pTang pFilCirc
                                                  dirKeep distSeg
                                                )
                                              )

                                              ;; Fillet: tangencia circulo -> tangencia guia.
                                              (setq ptsFillet
                                                (b3_arc_points_center
                                                  filletCenter filletR
                                                  pFilCirc pFilGuide
                                                  filletArcDir filletDistSeg
                                                )
                                              )

                                              ;; Una sola polilinea continua. Se elimina el punto
                                              ;; duplicado pFilCirc al concatenar los dos arcos.
                                              (setq ptsBota
                                                (if (and ptsCircle ptsFillet)
                                                  (append ptsCircle (cdr ptsFillet))
                                                  nil
                                                )
                                              )

                                              (setq ptsGiro ptsBota)
                                              (setq entGiro
                                                (if (and ptsBota (> (length ptsBota) 2))
                                                  (b3_lwpoly_open ptsBota nil)
                                                  nil
                                                )
                                              )

                                              (if entGiro
                                                (prompt
                                                  (strcat
                                                    "\nFILLET geometrico encontrado: "
                                                    (if (= filletMode 0)
                                                      "Tangencia interna"
                                                      "Tangencia externa"
                                                    )
                                                    " | Varredura="
                                                    (rtos (* 180.0 (/ filletSweep pi)) 2 1)
                                                    " graus"
                                                  )
                                                )
                                                (prompt
                                                  "\nNao foi possivel construir a polilinha final circulo + FILLET."
                                                )
                                              )
                                            )
                                          )

                                          ;; -------------------------------------------------
                                          ;; 3) BREAK EN LA LINEA DE GUIADO
                                          ;; -------------------------------------------------
                                          ;; pFilGuide es el punto geometrico exacto donde el
                                          ;; FILLET es tangente a la linea de guiado.
                                          ;; Se corta la guia justamente en ese punto.
                                          ;; No prolonga ni mueve la guia.
                                          (if (and entGiro pFilGuide)
                                            (progn
                                              (b3_breakatpoint guia pFilGuide)
                                              (prompt
                                                "\nLinha guia cortada no ponto de tangencia do FILLET."
                                              )
                                            )
                                          )

                                          ;; -------------------------------------------------
                                          ;; 4) CONECTA EL CIRCULO A LA CABECERA
                                          ;; -------------------------------------------------
                                          ;; Se mantiene exactamente la regla ya validada en BOTA2:
                                          ;; BREAKATPOINT en pTang y JOIN siempre con el tramo
                                          ;; contrario a pSide.
                                          (if entGiro
                                            (progn
                                              (setq lastBefore (entlast))
                                              (b3_breakatpoint ent pTang)
                                              (setq lastAfter (entlast))

                                              (setq entCab2
                                                (if (and lastAfter (/= lastAfter lastBefore))
                                                  lastAfter
                                                  nil
                                                )
                                              )

                                              (if *BOTA_CONECTAR_CAB*
                                                (progn
                                              (setq entCabJoin
                                                (b3_select_opposite_pside
                                                  ent entCab2 pTang ptsGiro
                                                )
                                              )

                                              (setq joinOk
                                                (if entCabJoin
                                                  (b3_join_two entGiro entCabJoin)
                                                  nil
                                                )
                                              )

                                              (if (not entCabJoin)
                                                (prompt
                                                  "\nAviso: nao foi possivel identificar o trecho da cabeceira contrario a pSide."
                                                )
                                                (if (not joinOk)
                                                  (prompt
                                                    "\nAviso: a cabeceira correta foi identificada, mas o AutoCAD nao conseguiu executar JOIN."
                                                  )
                                                )
                                              )
                                            )
                                                (prompt "\nConexao com cabeceira desativada para BOTA3.")
                                              )
                                            )
                                          )

                                          ;; Circulo externo normal, morado.
                                          (setq entBarra
                                            (b3_circle_entity centro rBarra 6)
                                          )

                                          (prompt
                                            (strcat
                                              "\nRaio Interno: " (rtos rGiro 2 3)
                                              " - Raio Externo: " (rtos rBarra 2 3)
                                              " - Fillet: " (rtos filletR 2 3)
                                              " - Seg.Fillet: " (rtos filletDistSeg 2 3)
                                            )
                                          )

                                        )
                                        (progn
                                          (prompt "\nNao ha solucao valida dentro do raio de trabalho.")
                                          (prompt "\nTente clicar mais perto da zona desejada ou aumentar o raio de trabalho fixo no codigo.")
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

  (b3_restore)
  (princ)
)

;; ============================================================
;; CARGA INICIAL - MUESTRA AYUDA AL CARGAR EL LISP
;; ============================================================

(princ "\n---------------------------------------------")
(princ "\nFerramentas BOTA v4.0 carregadas corretamente.")
(princ "\nComandos: BOTA | BOTA2 | BOTA3 | BOTAC | BOTAH")
(princ "\n---------------------------------------------")

;; Abre a janela de ajuda automaticamente ao carregar
(_bota_show_help)

(princ)
