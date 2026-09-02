;; ============================================================
;; BOTA TOOLS - SUITE DE FERRAMENTAS DE MANOBRAS (Civil3D / AutoCAD)
;; Criador: Maicon Marcarini
;; Versao: 5.0
;; Comandos incluidos: BOTA / BOTA2 / BOTA3 / BOTAF / BOTAC / BOTAH
;; ============================================================

(vl-load-com)

;; ------------------------------------------------------------
;; INICIALIZACAO DE VARIAVEIS GLOBAIS COMPARTILHADAS
;; ------------------------------------------------------------
(if (not *BOTA_RGIRO*)     (setq *BOTA_RGIRO* 10.000))
(if (not *BOTA_IMPL*)      (setq *BOTA_IMPL* 36.578))
(if (not *BOTA_DISTSEG*)   (setq *BOTA_DISTSEG* 0.900))
(if (not *BOTA_SEGURIDAD*) (setq *BOTA_SEGURIDAD* 0.200))
;; FILLET de BOTA3 (mantem os nomes antigos por compatibilidade).
(if (not *BOTA_FILLET_R*)   (setq *BOTA_FILLET_R* 30.000))
(if (not *BOTA_FILLET_SEG*) (setq *BOTA_FILLET_SEG* 1.500))
;; Concordancia geometrica de BOTAF (independente de BOTA3).
(if (not *BOTAF_FILLET_R*)   (setq *BOTAF_FILLET_R* 10.000))
(if (not *BOTAF_FILLET_SEG*) (setq *BOTAF_FILLET_SEG* 1.500))
(if (or (not (boundp '*BOTAF_AUTO_RANGES*))
        (/= (length *BOTAF_AUTO_RANGES*) 4)
        (not (and (car *BOTAF_AUTO_RANGES*)
                  (= (length (car *BOTAF_AUTO_RANGES*)) 4))))
  (setq *BOTAF_AUTO_RANGES*
    (list
      (list 87.000 90.000 10.000 0.700)
      (list 90.000 120.000 12.500 1.000)
      (list 120.000 135.000 15.000 1.200)
      (list 135.000 180.000 18.000 1.200)
    )
  )
)
(defun _bota_init_boolean_options ()
  ;; As marcas separadas preservam valores nil escolhidos no dialogo.
  (if (not (boundp '*BOTA_CONECTAR_CAB_CONFIGURADO*))
    (progn
      (if (not (boundp '*BOTA_CONECTAR_CAB*))
        (setq *BOTA_CONECTAR_CAB* T)
      )
      (setq *BOTA_CONECTAR_CAB_CONFIGURADO* T)
    )
  )
  (if (not (boundp '*BOTA_CORTAR_CIRCULO_CONFIGURADO*))
    (progn
      (if (not (boundp '*BOTA_CORTAR_CIRCULO*))
        (setq *BOTA_CORTAR_CIRCULO* T)
      )
      (setq *BOTA_CORTAR_CIRCULO_CONFIGURADO* T)
    )
  )
)

(_bota_init_boolean_options)

(defun _bota_botaf_ranges_from_dcl (/ i minAng maxAng rad distSeg ranges)
  (setq i 1)
  (setq ranges nil)
  (repeat 4
    (setq minAng (atof (get_tile (strcat "botafA" (itoa i) "Min"))))
    (setq maxAng (atof (get_tile (strcat "botafA" (itoa i) "Max"))))
    (setq rad    (atof (get_tile (strcat "botafA" (itoa i) "Rad"))))
    (setq distSeg (atof (get_tile (strcat "botafA" (itoa i) "Seg"))))
    (setq ranges (append ranges (list (list minAng maxAng rad distSeg))))
    (setq i (1+ i))
  )
  ranges
)

(defun _bota_botaf_ranges_valid_p (ranges / range rest other valid)
  (setq valid (= (length ranges) 4))
  (foreach range ranges
    (if (not (and (= (length range) 4)
                  (numberp (car range))
                  (numberp (cadr range))
                  (numberp (caddr range))
                  (numberp (nth 3 range))
                  (>= (car range) 0.0)
                  (<= (cadr range) 180.0)
                  (< (car range) (cadr range))
                  (> (caddr range) 0.0)
                  (> (nth 3 range) 0.0)))
      (setq valid nil)
    )
  )
  (setq rest ranges)
  (while (and valid rest)
    (foreach other (cdr rest)
      (if (and (< (car (car rest)) (cadr other))
               (< (car other) (cadr (car rest))))
        (setq valid nil)
      )
    )
    (setq rest (cdr rest))
  )
  valid
)

(defun _bota_side_from_picks (pCab pGuide / z)
  ;; O primeiro clique define X e o clique na guia define Y.
  (if (and (listp pCab)
           (listp pGuide)
           (numberp (car pCab))
           (numberp (cadr pCab))
           (numberp (car pGuide))
           (numberp (cadr pGuide)))
    (progn
      (setq z
        (if (numberp (caddr pCab))
          (float (caddr pCab))
          0.0
        )
      )
      (list (float (car pCab)) (float (cadr pGuide)) z)
    )
    nil
  )
)

;; ============================================================
;; DIAGNOSTICO VISUAL DE OFFSETS - BOTA2DEBUG
;; ============================================================

(if (not *BOTA2_DEBUG_LAYER*)
  (setq *BOTA2_DEBUG_LAYER* "BOTA2_DEBUG")
)

(defun _bota2d_pt3 (p)
  (if p
    (list
      (car p)
      (cadr p)
      (if (numberp (caddr p)) (caddr p) 0.0)
    )
    nil
  )
)

(defun _bota2d_ensure_layer (/ data)
  (if (not (tblsearch "LAYER" *BOTA2_DEBUG_LAYER*))
    (progn
      (setq data
        (list
          (cons 0 "LAYER")
          (cons 100 "AcDbSymbolTableRecord")
          (cons 100 "AcDbLayerTableRecord")
          (cons 2 *BOTA2_DEBUG_LAYER*)
          (cons 70 0)
          (cons 62 8)
          (cons 6 "Continuous")
        )
      )
      (entmakex data)
    )
  )
  *BOTA2_DEBUG_LAYER*
)

(defun _bota2d_clear (/ ss i)
  ;; A camada e reservada somente para esta inspecao visual.
  (setq ss (ssget "_X" (list (cons 8 *BOTA2_DEBUG_LAYER*))))
  (if ss
    (progn
      (setq i 0)
      (while (< i (sslength ss))
        (entdel (ssname ss i))
        (setq i (1+ i))
      )
    )
  )
)

(defun _bota2d_closest (e p / res)
  (if (and e p (entget e))
    (progn
      (setq res
        (vl-catch-all-apply
          'vlax-curve-getClosestPointTo
          (list e p)
        )
      )
      (if (vl-catch-all-error-p res)
        nil
        (_bota2d_pt3 res)
      )
    )
    nil
  )
)

(defun _bota2d_offset_all (e dist / obj res out item en)
  (if (and e dist (entget e))
    (progn
      (setq obj (vlax-ename->vla-object e))
      (setq res
        (vl-catch-all-apply
          'vlax-invoke
          (list obj 'Offset dist)
        )
      )
      (if (vl-catch-all-error-p res)
        nil
        (progn
          (if (= (type res) 'VARIANT)
            (setq res (vlax-variant-value res))
          )
          (if (= (type res) 'SAFEARRAY)
            (setq res (vlax-safearray->list res))
          )
          (if (/= (type res) 'LIST)
            (setq res (list res))
          )
          (setq out nil)
          (foreach item res
            (setq en
              (vl-catch-all-apply
                'vlax-vla-object->ename
                (list item)
              )
            )
            (if (not (vl-catch-all-error-p en))
              (setq out (cons en out))
            )
          )
          (reverse out)
        )
      )
    )
    nil
  )
)

(defun _bota2d_style_entity (e color / data)
  (if (and e (setq data (entget e)))
    (progn
      (setq data
        (subst (cons 8 *BOTA2_DEBUG_LAYER*) (assoc 8 data) data)
      )
      (if (assoc 62 data)
        (setq data (subst (cons 62 color) (assoc 62 data) data))
        (setq data (append data (list (cons 62 color))))
      )
      (entmod data)
      (entupd e)
    )
  )
  e
)

(defun _bota2d_mark (p label color height / labelPt)
  (if p
    (progn
      (entmakex
        (list
          (cons 0 "CIRCLE")
          (cons 100 "AcDbEntity")
          (cons 8 *BOTA2_DEBUG_LAYER*)
          (cons 62 color)
          (cons 100 "AcDbCircle")
          (cons 10 p)
          (cons 40 (* height 0.35))
        )
      )
      (if (and label (/= label ""))
        (progn
          (setq labelPt
            (list
              (+ (car p) (* height 0.50))
              (+ (cadr p) (* height 0.50))
              (caddr p)
            )
          )
          (entmakex
            (list
              (cons 0 "TEXT")
              (cons 100 "AcDbEntity")
              (cons 8 *BOTA2_DEBUG_LAYER*)
              (cons 62 color)
              (cons 100 "AcDbText")
              (cons 10 labelPt)
              (cons 40 height)
              (cons 1 label)
              (cons 7 (getvar "TEXTSTYLE"))
              (cons 72 0)
              (cons 73 0)
            )
          )
        )
      )
    )
  )
)

(defun _bota2d_text (p label color height)
  (if (and p label)
    (entmakex
      (list
        (cons 0 "TEXT")
        (cons 100 "AcDbEntity")
        (cons 8 *BOTA2_DEBUG_LAYER*)
        (cons 62 color)
        (cons 100 "AcDbText")
        (cons 10 p)
        (cons 40 height)
        (cons 1 label)
        (cons 7 (getvar "TEXTSTYLE"))
        (cons 72 0)
        (cons 73 0)
      )
    )
  )
)

(defun _bota2d_default_legend_point (p1 p2 p3 height / x y z)
  (setq x (max (car p1) (car p2) (car p3)))
  (setq y (max (cadr p1) (cadr p2) (cadr p3)))
  (setq z (caddr p1))
  (list (+ x (* height 5.0)) (+ y (* height 3.0)) z)
)

(defun _bota2d_draw_legend (origin rows height / i row p textPt)
  ;; Uma coluna legivel, fora da geometria. Cada marcador e texto usam a
  ;; mesma cor do objeto ou ponto correspondente no desenho.
  (if origin
    (progn
      (_bota2d_text
        (list (car origin) (+ (cadr origin) (* height 1.60)) (caddr origin))
        "BOTA2 DEBUG"
        7
        (* height 1.20)
      )
      (setq i 0)
      (foreach row rows
        (setq p
          (list
            (car origin)
            (- (cadr origin) (* i (* height 1.65)))
            (caddr origin)
          )
        )
        (_bota2d_mark p nil (cadr row) (* height 0.65))
        (setq textPt
          (list (+ (car p) (* height 1.10)) (cadr p) (caddr p))
        )
        (_bota2d_text textPt (car row) (cadr row) height)
        (setq i (1+ i))
      )
    )
  )
)

(defun _bota2d_entries (plus minus / out e)
  (setq out nil)
  (foreach e plus
    (setq out (append out (list (list e 1.0))))
  )
  (foreach e minus
    (setq out (append out (list (list e -1.0))))
  )
  out
)

(defun _bota2d_entry_by_distance (entries ref near / best bestD entry d p)
  ;; Reproduz apenas a selecao atual do BOTA2 para torna-la visivel.
  (setq best nil)
  (setq bestD nil)
  (foreach entry entries
    (if (and entry (car entry) (entget (car entry)))
      (progn
        (setq p (_bota2d_closest (car entry) ref))
        (if p
          (progn
            (setq d (distance ref p))
            (if (or (not best)
                    (if near (< d bestD) (> d bestD)))
              (progn
                (setq best entry)
                (setq bestD d)
              )
            )
          )
        )
      )
    )
  )
  best
)

(defun _bota2d_delete_entries_except (entries keep / entry e)
  (foreach entry entries
    (setq e (car entry))
    (if (and e (entget e) (/= e keep))
      (entdel e)
    )
  )
)

(defun _bota2d_triplets (values / out)
  (setq out nil)
  (while (and values (caddr values))
    (setq out (cons (list (car values) (cadr values) (caddr values)) out))
    (setq values (cdddr values))
  )
  (reverse out)
)

(defun _bota2d_intersection_best (e1 e2 ref / obj1 obj2 result points best bestD p d)
  ;; Somente a intersecao real dos dois offsets visiveis no diagnostico.
  (if (and e1 e2 ref (entget e1) (entget e2))
    (progn
      (setq obj1 (vlax-ename->vla-object e1))
      (setq obj2 (vlax-ename->vla-object e2))
      (setq result
        (vl-catch-all-apply
          'vlax-invoke
          (list obj1 'IntersectWith obj2 0)
        )
      )
      (if (or (vl-catch-all-error-p result) (not result))
        nil
        (progn
          (if (= (type result) 'VARIANT)
            (setq result (vlax-variant-value result))
          )
          (if (= (type result) 'SAFEARRAY)
            (setq result (vlax-safearray->list result))
          )
          (setq points (_bota2d_triplets result))
          (setq best nil)
          (setq bestD nil)
          (foreach p points
            (setq p (_bota2d_pt3 p))
            (setq d (distance p ref))
            (if (or (not best) (< d bestD))
              (progn
                (setq best p)
                (setq bestD d)
              )
            )
          )
          best
        )
      )
    )
    nil
  )
)

(defun c:BOTA2DEBUGCLEAR ()
  (vl-load-com)
  (_bota2d_ensure_layer)
  (_bota2d_clear)
  (prompt "\nBOTA2DEBUG: objetos de diagnostico eliminados.")
  (princ)
)

(defun c:BOTA2DEBUG (/ *error* selCab selGuide eCab eGuide pCabPick pGuidePick
                       pCab pGuide pOffsetPoint tamImpl seguridad offCabDist
                       offGuideDist cabPlus cabMinus guidePlus guideMinus
                       cabEntries guideEntries cabSelected guideSelected
                       height pLegend legendRows)
  ;; Mostra somente os cliques, os offsets escolhidos e sua intersecao real.
  (vl-load-com)

  (defun *error* (msg)
    (if (and msg (/= msg "Function cancelled") (/= msg "quit / exit abort"))
      (prompt (strcat "\nErro em BOTA2DEBUG: " msg))
    )
    (princ)
  )

  (if (not *BOTA_IMPL*)      (setq *BOTA_IMPL* 36.578))
  (if (not *BOTA_SEGURIDAD*) (setq *BOTA_SEGURIDAD* 0.200))
  (setq tamImpl *BOTA_IMPL*)
  (setq seguridad *BOTA_SEGURIDAD*)
  (setq offCabDist (/ tamImpl 2.0))
  (setq offGuideDist (+ offCabDist seguridad))
  (setq height (max 0.250 (min 2.500 (/ tamImpl 10.0))))

  (_bota2d_ensure_layer)
  (_bota2d_clear)
  (prompt "\nBOTA2DEBUG - clics, intersecao real e offsets selecionados.")
  (prompt "\nSelecione a cabeceira no mesmo ponto usado em BOTA2: ")
  (setq selCab (entsel))

  (if (not selCab)
    (prompt "\nNenhuma cabeceira selecionada.")
    (progn
      (setq eCab (car selCab))
      (setq pCabPick (_bota2d_pt3 (cadr selCab)))
      (setq pCab (_bota2d_closest eCab pCabPick))
      (if (not pCab)
        (prompt "\nA cabeceira selecionada nao e uma curva valida.")
        (progn
          (prompt "\nSelecione a linha guia no mesmo ponto usado em BOTA2: ")
          (setq selGuide (entsel))
          (if (not selGuide)
            (prompt "\nNenhuma linha guia selecionada.")
            (progn
              (setq eGuide (car selGuide))
              (setq pGuidePick (_bota2d_pt3 (cadr selGuide)))
              (setq pGuide (_bota2d_closest eGuide pGuidePick))
              (if (not pGuide)
                (prompt "\nA linha guia selecionada nao e uma curva valida.")
                (progn
                  ;; Os mesmos criterios da selecao principal de BOTA2:
                  ;; cabeceira em direcao ao clique da guia e guia afastando
                  ;; da cabeceira. Nenhuma coordenada X/Y e combinada.
                  (setq cabPlus (_bota2d_offset_all eCab offCabDist))
                  (setq cabMinus (_bota2d_offset_all eCab (- offCabDist)))
                  (setq guidePlus (_bota2d_offset_all eGuide offGuideDist))
                  (setq guideMinus (_bota2d_offset_all eGuide (- offGuideDist)))
                  (setq cabEntries (_bota2d_entries cabPlus cabMinus))
                  (setq guideEntries (_bota2d_entries guidePlus guideMinus))
                  (setq cabSelected
                    (_bota2d_entry_by_distance cabEntries pGuidePick T)
                  )
                  (setq guideSelected
                    (_bota2d_entry_by_distance guideEntries pCab nil)
                  )

                  (if (and cabSelected guideSelected)
                    (progn
                      (setq pOffsetPoint
                        (_bota2d_intersection_best
                          (car cabSelected) (car guideSelected) pGuidePick
                        )
                      )
                      ;; A camada de diagnostico deve conter somente o par final.
                      (_bota2d_delete_entries_except cabEntries (car cabSelected))
                      (_bota2d_delete_entries_except guideEntries (car guideSelected))
                      (_bota2d_style_entity (car cabSelected) 3)
                      (_bota2d_style_entity (car guideSelected) 4)

                      ;; Os marcadores preservam as coordenadas exatas dos clics.
                      (_bota2d_mark pCabPick nil 2 height)
                      (_bota2d_mark pGuidePick nil 30 height)
                      (if pOffsetPoint
                        (_bota2d_mark pOffsetPoint nil 5 height)
                      )
                      (setq pLegend
                        (_bota2d_default_legend_point
                          pCabPick pGuidePick
                          (if pOffsetPoint pOffsetPoint pCabPick)
                          height
                        )
                      )
                      (setq legendRows
                        (list
                          (list "CLIC CABECEIRA" 2)
                          (list "CLIC GUIA" 30)
                          (list "OFFSET CABECEIRA SELECIONADO" 3)
                          (list "OFFSET GUIA SELECIONADO" 4)
                        )
                      )
                      (if pOffsetPoint
                        (setq legendRows
                          (append
                            (list
                              (list "CLIC CABECEIRA" 2)
                              (list "CLIC GUIA" 30)
                              (list "INTERSECAO REAL DOS OFFSETS" 5)
                            )
                            (cddr legendRows)
                          )
                        )
                      )
                      (_bota2d_draw_legend pLegend legendRows height)
                      (prompt
                        (strcat
                          "\nDiagnostico criado na camada " *BOTA2_DEBUG_LAYER*
                          ". Mostrados somente os offsets selecionados."
                        )
                      )
                      (if (not pOffsetPoint)
                        (prompt "\nOs offsets selecionados nao possuem intersecao real neste tramo.")
                      )
                      (prompt "\nUse BOTA2DEBUGCLEAR para apagar somente este diagnostico.")
                    )
                    (progn
                      (_bota2d_delete_entries_except cabEntries nil)
                      (_bota2d_delete_entries_except guideEntries nil)
                      (prompt "\nNao foi possivel selecionar os offsets de cabecera e guia.")
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
  (princ)
)

;; ============================================================
;; COMANDO BOTAC - JANELA DCL DE CONFIGURACAO DE PARAMETROS
;; Criador: Maicon Marcarini
;; ============================================================

(defun _bota_show_dcl (/ dclFile fn dclId status _v_rGiro _v_tamImpl _v_distSeg _v_seguridad _v_filletR _v_filletSeg _v_botafR _v_botafSeg _v_botafRanges _v_joinCab _v_cutCircle i range)
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
      (write-line "      label = \"Fillet (BOTA3)\";" fn)
      (write-line "      : edit_box { label = \"Raio do Fillet (m):\"; key = \"filletR\"; edit_width = 12; }" fn)
      (write-line "      : edit_box { label = \"Distancia Max. Vertices Fillet (m):\"; key = \"filletSeg\"; edit_width = 12; }" fn)
      (write-line "    }" fn)
      (write-line "    : boxed_column {" fn)
      (write-line "      label = \"Concordancia Segmentada (BOTAF)\";" fn)
       (write-line "      : edit_box { label = \"Raio da Concordancia (m):\"; key = \"botafR\"; edit_width = 12; }" fn)
       (write-line "      : edit_box { label = \"Distancia Max. Vertices (m):\"; key = \"botafSeg\"; edit_width = 12; }" fn)
       (write-line "    }" fn)
       (write-line "    : boxed_column {" fn)
       (write-line "      label = \"Raio Automatico BOTAF por Angulo\";" fn)
       (write-line "      : text { label = \"Configure quatro faixas sem sobreposicao.\"; }" fn)
       (setq i 1)
       (repeat 4
         (write-line
           (strcat
             "      : row { : edit_box { label = \"Faixa " (itoa i) " de (graus):\"; key = \"botafA" (itoa i) "Min\"; edit_width = 8; }"
             " : edit_box { label = \"ate:\"; key = \"botafA" (itoa i) "Max\"; edit_width = 8; }"
              " : edit_box { label = \"Raio (m):\"; key = \"botafA" (itoa i) "Rad\"; edit_width = 8; }"
              " : edit_box { label = \"Dist. Vert. (m):\"; key = \"botafA" (itoa i) "Seg\"; edit_width = 8; } }"
           )
           fn
         )
         (setq i (1+ i))
       )
       (write-line "    }" fn)
      (write-line "    : boxed_column {" fn)
      (write-line "      label = \"Cabeceira\";" fn)
      (write-line "      : toggle { label = \"Conectar a cabeceira\"; key = \"joinCab\"; }" fn)
      (write-line "      : toggle { label = \"Cortar circulo interno (remover 2 segmentos)\"; key = \"cutCircle\"; }" fn)
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
           (set_tile "botafR"    (rtos *BOTAF_FILLET_R* 2 3))
           (set_tile "botafSeg"  (rtos *BOTAF_FILLET_SEG* 2 3))
           (setq i 1)
           (foreach range *BOTAF_AUTO_RANGES*
             (set_tile (strcat "botafA" (itoa i) "Min") (rtos (car range) 2 3))
             (set_tile (strcat "botafA" (itoa i) "Max") (rtos (cadr range) 2 3))
             (set_tile (strcat "botafA" (itoa i) "Rad") (rtos (caddr range) 2 3))
             (set_tile (strcat "botafA" (itoa i) "Seg") (rtos (nth 3 range) 2 3))
             (setq i (1+ i))
           )
           (set_tile "joinCab"    (if *BOTA_CONECTAR_CAB* "1" "0"))
           (set_tile "cutCircle"  (if *BOTA_CORTAR_CIRCULO* "1" "0"))

          (action_tile "accept"
            "(progn
               (setq _v_rGiro     (atof (get_tile \"rGiro\")))
               (setq _v_tamImpl   (atof (get_tile \"tamImpl\")))
               (setq _v_distSeg   (atof (get_tile \"distSeg\")))
               (setq _v_seguridad (atof (get_tile \"seguridad\")))
               (setq _v_filletR   (atof (get_tile \"filletR\")))
               (setq _v_filletSeg (atof (get_tile \"filletSeg\")))
                (setq _v_botafR    (atof (get_tile \"botafR\")))
                (setq _v_botafSeg  (atof (get_tile \"botafSeg\")))
                (setq _v_botafRanges (_bota_botaf_ranges_from_dcl))
                (setq _v_joinCab   (= (get_tile \"joinCab\") \"1\"))
                (setq _v_cutCircle (= (get_tile \"cutCircle\") \"1\"))
               (if (and (> _v_rGiro 0.0)
                        (> _v_tamImpl 0.0)
                        (> _v_distSeg 0.0)
                        (>= _v_seguridad 0.0)
                        (> _v_filletR 0.0)
                         (> _v_filletSeg 0.0)
                         (> _v_botafR 0.0)
                         (> _v_botafSeg 0.0)
                         (_bota_botaf_ranges_valid_p _v_botafRanges))
                 (progn
                   (setq *BOTA_RGIRO*     _v_rGiro)
                   (setq *BOTA_IMPL*      _v_tamImpl)
                   (setq *BOTA_DISTSEG*   _v_distSeg)
                   (setq *BOTA_SEGURIDAD* _v_seguridad)
                   (setq *BOTA_FILLET_R*   _v_filletR)
                   (setq *BOTA_FILLET_SEG* _v_filletSeg)
                    (setq *BOTAF_FILLET_R*   _v_botafR)
                    (setq *BOTAF_FILLET_SEG* _v_botafSeg)
                    (setq *BOTAF_AUTO_RANGES* _v_botafRanges)
                    (setq *BOTA_CONECTAR_CAB* _v_joinCab)
                    (setq *BOTA_CORTAR_CIRCULO* _v_cutCircle)
                    (setq *BOTA_CONECTAR_CAB_CONFIGURADO* T)
                    (setq *BOTA_CORTAR_CIRCULO_CONFIGURADO* T)
                   (done_dialog 1)
                 )
                  (alert \"Informe valores validos. As faixas devem estar entre 0 e 180 graus, sem sobreposicao, e ter raio e segmento maiores que zero.\")
               )
             )"
          )

          (action_tile "cancel" "(done_dialog 0)")

          (setq status (start_dialog))
          (unload_dialog dclId)
          (vl-file-delete dclFile)
          (if (= status 1)
            (prompt
              (strcat
                "\nParametros BOTA atualizados: Conectar cabeceira="
                (if *BOTA_CONECTAR_CAB* "Sim" "Nao")
                " | Cortar circulo="
                (if *BOTA_CORTAR_CIRCULO* "Sim" "Nao")
                "."
              )
            )
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

(defun _bota_show_help (/ dclFile fn dclId status)
  (vl-load-com)
  (setq dclFile (vl-filename-mktemp "bota_help" nil ".dcl"))
  (setq fn (open dclFile "w"))
  (if fn
    (progn
      (write-line "bota_help_dialog : dialog {" fn)
      (write-line "  label = \"Ferramentas BOTA v5.0 - Ajuda\";" fn)
      (write-line "  : column {" fn)
      (write-line "    : boxed_column {" fn)
      (write-line "      label = \"Informacoes Gerais\";" fn)
      (write-line "      : paragraph {" fn)
      (write-line "        : text_part { label = \"Criador: Maicon Marcarini\"; }" fn)
      (write-line "        : text_part { label = \"Versao: 5.0\"; }" fn)
      (write-line "        : text_part { label = \"Proibida a modificacao ou redistribuicao sem autorizacao.\"; }" fn)
      (write-line "      }" fn)
      (write-line "    }" fn)
      (write-line "    : boxed_column {" fn)
      (write-line "      label = \"Comandos Disponiveis\";" fn)
      (write-line "      : paragraph {" fn)
      (write-line "        : text_part { label = \"BOTA  - Manobra manual selecionando o vertice onde deve passar o externo do implemento.\"; }" fn)
      (write-line "        : text_part { label = \"BOTA2 - Manobra automatica com cabeceira e linha guia.\"; }" fn)
      (write-line "        : text_part { label = \"BOTAX - BOTA2 com ponto manual para definir o lado do giro.\"; }" fn)
      (write-line "        : text_part { label = \"BOTA3 - Manobra por linha guia com fillet automatico.\"; }" fn)
      (write-line "        : text_part { label = \"BOTAF - Fillet automatico entre cabeceira e linha, convertido em segmentos.\"; }" fn)
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
      (write-line "        : text_part { label = \"Cortar circulo: remove dois segmentos; sem corte mantem o BREAK na tangencia.\"; }" fn)
      (write-line "      }" fn)
      (write-line "    }" fn)
      (write-line "    : boxed_column {" fn)
      (write-line "      label = \"Seguranca (BOTA2 / BOTA3)\";" fn)
      (write-line "      : paragraph {" fn)
      (write-line "        : text_part { label = \"Seguranca: distancia extra para garantir cobertura\"; }" fn)
      (write-line "        : text_part { label = \"entre a manobra e a linha guia.\"; }" fn)
      (write-line "      }" fn)
      (write-line "    }" fn)
      (write-line "    : boxed_column {" fn)
      (write-line "      label = \"Parametros de Fillet (BOTA3)\";" fn)
      (write-line "      : paragraph {" fn)
      (write-line "        : text_part { label = \"Raio Fillet: raio da concordancia (arco de conexao).\"; }" fn)
      (write-line "        : text_part { label = \"Fillet Seg.: distancia max. entre vertices da concordancia.\"; }" fn)
      (write-line "      }" fn)
      (write-line "    }" fn)
      (write-line "    : boxed_column {" fn)
      (write-line "      label = \"Parametros de Concordancia (BOTAF)\";" fn)
      (write-line "      : paragraph {" fn)
      (write-line "        : text_part { label = \"Enter usa o raio configurado; R altera somente esse raio.\"; }" fn)
      (write-line "        : text_part { label = \"A usa a faixa de angulo com raio e dist. entre vertices proprios.\"; }" fn)
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

  (defun _circleSegFullDirectional (cen r pAnchor pSide nSeg color
                                         / a step pPlus pMinus vSide
                                           scorePlus scoreMinus dir dirKeep
                                           pts i e)
    ;; Mantem o BREAK no ponto de tangencia, sem remover segmentos do circulo.
    ;; A polilinha fica aberta e seus dois extremos coincidem em pAnchor.
    (setq a    (angle cen pAnchor))
    (setq step (/ (* 2.0 pi) nSeg))
    (setq pPlus  (_polarpt cen (+ a step) r))
    (setq pMinus (_polarpt cen (- a step) r))
    (setq vSide (_v- pSide pAnchor))
    (setq scorePlus  (_dot (_v- pPlus  pAnchor) vSide))
    (setq scoreMinus (_dot (_v- pMinus pAnchor) vSide))

    ;; Mantem o mesmo sentido do arco existente para preservar a regra de JOIN.
    (if (<= scorePlus scoreMinus)
      (setq dir 1.0)
      (setq dir -1.0)
    )
    (setq dirKeep (- dir))

    (setq pts (list pAnchor))
    (setq i 1)
    (repeat (1- nSeg)
      (setq pts
        (append pts
          (list (_polarpt cen (+ a (* dirKeep i step)) r))
        )
      )
      (setq i (1+ i))
    )
    (setq pts (append pts (list pAnchor)))

    (setq e (_lwpoly-open pts color))
    (list e pAnchor pAnchor dir pts)
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

  (defun _breakatpoint (e pt / oldCmd pObj res)
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

        (setq oldCmd (getvar "CMDECHO"))

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

  (defun _join-two (eBase eAdd / oldCmd res)
    ;; JOIN real entre dos entidades que ya comparten pTang.
    ;; No prolonga entidades y no agrega ningun segmento.
    ;; eBase = circulo interno recortado.
    ;; eAdd  = tramo correcto de la cabecera.

    (if (and eBase eAdd (entget eBase) (entget eAdd))
      (progn
        (setq oldCmd (getvar "CMDECHO"))

        (setvar "CMDECHO" 0)

        (setq res
          (vl-catch-all-apply
            'vl-cmdf
            (list "_.JOIN" eBase eAdd "")
          )
        )

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
  (if (not *BOTA_DISTSEG*) (setq *BOTA_DISTSEG* 0.900))
  (_bota_init_boolean_options)

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
              ;; C     = configurar todos os parametros
              ;; R     = ajustar somente o raio de giro
              ;; -------------------------------------------------

              (initget "C R")
              (setq cfg
                (getkword
                  (strcat
                    "\nParametros atuais:"
                    " Raio Interno=" (rtos *BOTA_RGIRO* 2 3)
                    " | Implemento=" (rtos *BOTA_IMPL* 2 3)
                    " | Segmentos=" (rtos *BOTA_DISTSEG* 2 3)
                    " | Con.Cabeceira=" (if *BOTA_CONECTAR_CAB* "Sim" "Nao")
                    " | Corte.Circulo=" (if *BOTA_CORTAR_CIRCULO* "Sim" "Nao")
                    "\nPressione Enter para usar estes parametros ou [R] raio / [C] configurar: "
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

              (if (= cfg "R")
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
                  (setq rGiro *BOTA_RGIRO*)
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
                          ;; 1) Cria o circulo interno com ou sem o corte direcional.
                          ;;
                          ;;    En el comando BOTA, pVert tambien funciona como
                          ;;    referencia del lado donde se genera la bota.
                          ;;    No se pide linea de guiado ni punto adicional.
                          ;; -------------------------------------------------
                          (setq giroData
                            (if *BOTA_CORTAR_CIRCULO*
                              (_circleSegGapDirectional
                                centro rGiro pTang pVert nSegGiro nil
                              )
                              (_circleSegFullDirectional
                                centro rGiro pTang pVert nSegGiro nil
                              )
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

  (defun c:BOTA2 (/ *error* oldLuprec cfg sel ent guia pPick pCab pGuiaPick pSide pJoint manualSideMode
                  offsetData usedVirtual
                  rGiro tamImpl seguridad rBarra distSeg offCabDist offGuiaDist
                  offCab offGuia offCentro tmpExtCircle pVert pCutRef
                  pTang centro nSegGiro giroData entGiro entBarra ptsGiro
                  pGapIni pGapFin lastBefore lastAfter entCab2 entCabJoin joinOk)

  (vl-load-com)

  (setq manualSideMode
    (and (boundp '*BOTA2_MANUAL_SIDE_MODE*) *BOTA2_MANUAL_SIDE_MODE*)
  )
  ;; BOTAX consome esta marca uma unica vez, inclusive quando BOTA2 termina
  ;; por cancelamento ou erro.
  (setq *BOTA2_MANUAL_SIDE_MODE* nil)

  ;; -------------------------
  ;; Restaurar variables
  ;; -------------------------

  (defun b2_restore ()
    (if oldLuprec
      (setvar "LUPREC" oldLuprec)
    )
  )

  (defun *error* (msg)
    (b2_clear_temporaries)
    (b2_restore)
    (setq *BOTA2_MANUAL_SIDE_MODE* nil)
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

  (defun b2_opposite_point (anchor point)
    ;; Punto sobre la direccion opuesta a point, tomando anchor como origen.
    (if (and anchor point)
      (b2_v+ anchor (b2_v- anchor point))
      nil
    )
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
    (if (>= x 1.0)
      (/ pi 2.0)
      (if (<= x -1.0)
        (- (/ pi 2.0))
        (atan (/ x (sqrt (- 1.0 (* x x)))))
      )
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

  (defun b2_circle_gap_directional (cen r pAnchor pCutRef nSeg color
                                   / a step pPlus pMinus vSide scorePlus scoreMinus
                                     dir dirKeep gapCount pts i pGap e)
    ;; Circulo interno como polilinea ABIERTA con un hueco DIRECCIONAL.
    ;;
    ;; pAnchor = punto de tangencia con la cabecera.
    ;; pCutRef = referencia del lado donde se debe cortar/conectar.
    ;;
    ;; Se eliminan DOS segmentos consecutivos DESDE pAnchor, pero solamente
    ;; hacia el lado de pCutRef.
    ;;
    ;; Ejemplo:
    ;;   si pCutRef queda hacia la derecha de pAnchor,
    ;;   se eliminan los dos segmentos que salen hacia la derecha.
    ;;
    ;; pAnchor se conserva como extremo del arco porque ya pertenece a la
    ;; cabecera. Luego solo sera necesario conectar el otro extremo del hueco.

    (setq a        (angle cen pAnchor))
    (setq step     (/ (* 2.0 pi) nSeg))
    (setq gapCount 2)

    ;; Vertices vecinos a pAnchor en ambos sentidos del circulo.
    (setq pPlus  (b2_polarpt cen (+ a step) r))
    (setq pMinus (b2_polarpt cen (- a step) r))

    ;; Vector desde la tangencia hacia la referencia de corte/conexion.
    (setq vSide (b2_v- pCutRef pAnchor))

    ;; Cuanto apunta cada sentido hacia pCutRef.
    ;; El mayor producto escalar corresponde al sentido mas cercano a pCutRef.
    (setq scorePlus  (b2_dot (b2_v- pPlus  pAnchor) vSide))
    (setq scoreMinus (b2_dot (b2_v- pMinus pAnchor) vSide))

    (if (>= scorePlus scoreMinus)
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

  (defun b2_circle_full_directional (cen r pAnchor pCutRef nSeg color
                                         / a step pPlus pMinus vSide
                                           scorePlus scoreMinus dir dirKeep
                                           pts i e)
    ;; Mantem o BREAK no ponto de tangencia, sem remover segmentos do circulo.
    ;; A polilinha fica aberta e seus dois extremos coincidem em pAnchor.
    (setq a    (angle cen pAnchor))
    (setq step (/ (* 2.0 pi) nSeg))
    (setq pPlus  (b2_polarpt cen (+ a step) r))
    (setq pMinus (b2_polarpt cen (- a step) r))
    (setq vSide (b2_v- pCutRef pAnchor))
    (setq scorePlus  (b2_dot (b2_v- pPlus  pAnchor) vSide))
    (setq scoreMinus (b2_dot (b2_v- pMinus pAnchor) vSide))

    ;; Mantem o mesmo sentido do arco existente para preservar a regra de JOIN.
    (if (>= scorePlus scoreMinus)
      (setq dir 1.0)
      (setq dir -1.0)
    )
    (setq dirKeep (- dir))

    (setq pts (list pAnchor))
    (setq i 1)
    (repeat (1- nSeg)
      (setq pts
        (append pts
          (list (b2_polarpt cen (+ a (* dirKeep i step)) r))
        )
      )
      (setq i (1+ i))
    )
    (setq pts (append pts (list pAnchor)))

    (setq e (b2_lwpoly_open pts color))
    (list e pAnchor pAnchor dir pts)
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

  (defun b2_clear_temporaries ()
    (if (and offCab (entget offCab))
      (b2_delete_ent offCab)
    )
    (if (and offGuia (entget offGuia))
      (b2_delete_ent offGuia)
    )
    (if (and offCentro (entget offCentro))
      (b2_delete_ent offCentro)
    )
    (if (and tmpExtCircle (entget tmpExtCircle))
      (b2_delete_ent tmpExtCircle)
    )
    (setq offCab nil)
    (setq offGuia nil)
    (setq offCentro nil)
    (setq tmpExtCircle nil)
  )

  (defun b2_offset_all (e dist / obj res out en)
    (if (and e dist)
      (progn
        (setq obj (vlax-ename->vla-object e))
        (setq res
          (vl-catch-all-apply
            'vlax-invoke
            (list obj 'Offset dist)
          )
        )
        (if (vl-catch-all-error-p res)
          nil
          (progn
            (if (= (type res) 'VARIANT)
              (setq res (vlax-variant-value res))
            )
            (if (= (type res) 'SAFEARRAY)
              (setq res (vlax-safearray->list res))
            )
            (if (/= (type res) 'LIST)
              (setq res (list res))
            )

            (setq out nil)
            (foreach obj res
              (setq en
                (vl-catch-all-apply
                  'vlax-vla-object->ename
                  (list obj)
                )
              )
              (if (not (vl-catch-all-error-p en))
                (setq out (cons en out))
              )
            )
            (reverse out)
          )
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

  (defun b2_delete_ents_except (ents keep / en)
    (foreach en ents
      (if (and en (/= en keep))
        (b2_delete_ent en)
      )
    )
  )

  (defun b2_offset_pick_by_side (e ents pSide sameSide / best bestScore bestDist score dist)
    ;; sameSide=T selecciona el offset del mismo lado que pSide.
    ;; sameSide=nil selecciona el offset del lado contrario.
    (if (not ents)
      nil
      (if (= (length ents) 1)
        (progn
          (setq score (b2_offset_side_score e (car ents) pSide))
          (if (if sameSide (> score 1e-9) (< score -1e-9))
            (car ents)
            nil
          )
        )
        (progn
          (setq best nil)
          (setq bestScore nil)
          (setq bestDist nil)

          (foreach en ents
            (setq score (b2_offset_side_score e en pSide))
            (setq dist  (b2_dist_to_ent en pSide))
            (if
              (or
                (not best)
                (if sameSide
                  (or (> score bestScore)
                      (and (equal score bestScore 1e-9) (< dist bestDist)))
                  (or (< score bestScore)
                      (and (equal score bestScore 1e-9) (> dist bestDist)))
                )
              )
              (progn
                (setq best en)
                (setq bestScore score)
                (setq bestDist dist)
              )
            )
          )

          (if (and best (if sameSide (> bestScore 1e-9) (< bestScore -1e-9)))
            best
            nil
          )
        )
      )
    )
  )

  (defun b2_offset_side_score (eBase eOff pSide / pBase pOff vClick vOff)
    ;; Score de lado del offset respecto a la entidad base y al punto indicado.
    ;; Mayor score = offset del mismo lado del punto indicado.
    ;; Menor score = offset del lado contrario. No depende del sentido de dibujo.
    (setq pBase
      (vl-catch-all-apply
        'vlax-curve-getClosestPointTo
        (list eBase pSide)
      )
    )

    (if (vl-catch-all-error-p pBase)
      0.0
      (progn
        (setq pBase (b2_pt3 pBase))
        (setq pOff
          (vl-catch-all-apply
            'vlax-curve-getClosestPointTo
            (list eOff pBase)
          )
        )

        (if (vl-catch-all-error-p pOff)
          0.0
          (progn
            (setq pOff (b2_pt3 pOff))
            (setq vClick (b2_v- pSide pBase))
            (setq vOff   (b2_v- pOff pBase))
            (b2_dot vClick vOff)
          )
        )
      )
    )
  )

  (defun b2_offset_select (e dist pSide / ents keep)
    ;; Crea offset positivo y negativo.
    ;; En v5, pSide es la zona indicada por el usuario para la salida/corte.
    ;; Mantiene el offset del mismo lado de esa zona.

    (setq ents
      (append
        (b2_offset_all e dist)
        (b2_offset_all e (- dist))
      )
    )
    (setq keep (b2_offset_pick_by_side e ents pSide T))
    (b2_delete_ents_except ents keep)
    keep
  )

  (defun b2_offset_select_opposite (e dist pSide / ents keep)
    ;; Crea offset positivo y negativo.
    ;; Mantiene el offset del lado contrario a la zona indicada.

    (setq ents
      (append
        (b2_offset_all e dist)
        (b2_offset_all e (- dist))
      )
    )
    (setq keep (b2_offset_pick_by_side e ents pSide nil))
    (b2_delete_ents_except ents keep)
    keep
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

  (defun b2_cross2 (a b)
    (- (* (car a) (cadr b)) (* (cadr a) (car b)))
  )

  (defun b2_segment_intersection (a b c d / r s den q tParam uParam)
    ;; Intersecao de segmentos finitos, sem prolongar as entidades.
    (setq r   (b2_v- b a))
    (setq s   (b2_v- d c))
    (setq den (b2_cross2 r s))
    (if (< (abs den) 1e-10)
      nil
      (progn
        (setq q      (b2_v- c a))
        (setq tParam (/ (b2_cross2 q s) den))
        (setq uParam (/ (b2_cross2 q r) den))
        (if (and (>= tParam -1e-8) (<= tParam (+ 1.0 1e-8))
                 (>= uParam -1e-8) (<= uParam (+ 1.0 1e-8)))
          (b2_v+ a (b2_v* tParam r))
          nil
        )
      )
    )
  )

  (defun b2_curve_segments (e / endParam i p1 p2 out)
    ;; Offsets locais sao polilinhas; percorre seus segmentos reais.
    (setq endParam
      (vl-catch-all-apply 'vlax-curve-getEndParam (list e))
    )
    (setq out nil)
    (if (not (vl-catch-all-error-p endParam))
      (progn
        (setq i 0)
        (while (< i endParam)
          (setq p1
            (vl-catch-all-apply 'vlax-curve-getPointAtParam (list e i))
          )
          (setq p2
            (vl-catch-all-apply 'vlax-curve-getPointAtParam (list e (1+ i)))
          )
          (if (and (not (vl-catch-all-error-p p1))
                   (not (vl-catch-all-error-p p2)))
            (setq out (cons (list (b2_pt3 p1) (b2_pt3 p2)) out))
          )
          (setq i (1+ i))
        )
      )
    )
    (reverse out)
  )

  (defun b2_intersections_fallback (e1 e2 / pts s1 s2 p)
    (setq pts nil)
    (foreach s1 (b2_curve_segments e1)
      (foreach s2 (b2_curve_segments e2)
        (setq p (b2_segment_intersection (car s1) (cadr s1) (car s2) (cadr s2)))
        (if p (setq pts (cons p pts)))
      )
    )
    pts
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
          (progn
            (if (= (type res) 'VARIANT)
              (setq res (vlax-variant-value res))
            )
            (if (= (type res) 'SAFEARRAY)
              (setq res (vlax-safearray->list res))
            )
            (b2_triplets res)
          )
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
    (if (not pts)
      (setq pts (b2_intersections_fallback e1 e2))
    )

    (if pts
      (b2_best_point pts pref)
      nil
    )
  )

  (defun b2_intersection_extended_best (e1 e2 pref / pts)
    ;; Reserva geometrica para os offsets. IntersectWith com modo 3 calcula
    ;; somente o cruzamento das extensoes; nao altera nem prolonga entidades.
    (setq pts (b2_intersections e1 e2 3))
    (if pts
      (b2_best_point pts pref)
      nil
    )
  )

  (defun b2_virtual_intersection_within (e1 e2 p maxExt)
    ;; Aceita a extensao apenas quando o ponto esta a no maximo maxExt de cada
    ;; offset real. Assim uma extensao virtual nunca vira uma solucao distante.
    (and p
         (<= (b2_dist_to_ent e1 p) maxExt)
         (<= (b2_dist_to_ent e2 p) maxExt)
    )
  )

  (defun b2_offset_candidates_signed (e dist / out en)
    ;; Mantem o sinal do Offset para reproduzir na guia real o lado que foi
    ;; identificado na copia temporaria.
    (setq out nil)
    (foreach en (b2_offset_all e dist)
      (setq out (append out (list (list en 1.0))))
    )
    (foreach en (b2_offset_all e (- dist))
      (setq out (append out (list (list en -1.0))))
    )
    out
  )

  (defun b2_signed_entries_for_sign (entries sign / out entry)
    (setq out nil)
    (foreach entry entries
      (if (and entry (= (cadr entry) sign))
        (setq out (cons entry out))
      )
    )
    (reverse out)
  )

  (defun b2_signed_entry_by_distance (entries ref near / best bestD entry d)
    ;; near=T escolhe o offset na direcao da referencia; near=nil escolhe
    ;; o offset que se afasta dela.
    (setq best nil)
    (setq bestD nil)
    (foreach entry entries
      (if (and entry (car entry) (entget (car entry)))
        (progn
          (setq d (b2_dist_to_ent (car entry) ref))
          (if (or (not best)
                  (if near (< d bestD) (> d bestD)))
            (progn
              (setq best entry)
              (setq bestD d)
            )
          )
        )
      )
    )
    best
  )

  (defun b2_delete_signed_entries_except (entries keep / entry)
    (foreach entry entries
      (if (and entry (/= (car entry) keep))
        (b2_delete_ent (car entry))
      )
    )
  )

  (defun b2_copy_entity (e / obj copy en)
    (if (and e (entget e))
      (progn
        (setq obj (vlax-ename->vla-object e))
        (setq copy (vl-catch-all-apply 'vla-copy (list obj)))
        (if (vl-catch-all-error-p copy)
          nil
          (progn
            (setq en
              (vl-catch-all-apply 'vlax-vla-object->ename (list copy))
            )
            (if (vl-catch-all-error-p en) nil en)
          )
        )
      )
      nil
    )
  )

  (defun b2_extend_copy_to_boundary (e boundary pTarget / pStart pEnd pPick oldCmd res)
    ;; EXTEND atua somente na copia da guia. A distancia nao e limitada porque
    ;; essa geometria serve apenas para identificar o sinal do offset.
    (setq pStart
      (vl-catch-all-apply 'vlax-curve-getStartPoint (list e))
    )
    (setq pEnd
      (vl-catch-all-apply 'vlax-curve-getEndPoint (list e))
    )
    (if (or (vl-catch-all-error-p pStart)
            (vl-catch-all-error-p pEnd)
            (not boundary)
            (not pTarget))
      nil
      (progn
        (setq pStart (b2_pt3 pStart))
        (setq pEnd   (b2_pt3 pEnd))
        (setq pPick
          (if (<= (distance pTarget pStart) (distance pTarget pEnd))
            pStart
            pEnd
          )
        )
        (setq oldCmd (getvar "CMDECHO"))
        (setvar "CMDECHO" 0)
        (setq res
          (vl-catch-all-apply
            'vl-cmdf
            (list "_.EXTEND" boundary "" (list e pPick) "")
          )
        )
        (setvar "CMDECHO" oldCmd)
        (and (not (vl-catch-all-error-p res)) (entget e))
      )
    )
  )

  (defun b2_find_offset_intersection (offCab guideEntries pJoint allowVirtual
                                      / entry p d bestEntry bestPoint bestD maxExt)
    ;; Procura primeiro apenas cruzamentos reais. A extensao de 1 m e usada
    ;; exclusivamente na ultima tentativa sobre a guia real.
    (setq bestEntry nil)
    (setq bestPoint nil)
    (setq bestD nil)
    (foreach entry guideEntries
      (setq p (b2_intersection_best offCab (car entry) pJoint))
      (if p
        (progn
          (setq d (distance p pJoint))
          (if (or (not bestEntry) (< d bestD))
            (progn
              (setq bestEntry entry)
              (setq bestPoint p)
              (setq bestD d)
            )
          )
        )
      )
    )
    (if bestEntry
      (list bestEntry bestPoint nil)
      (if allowVirtual
        (progn
          (setq maxExt 1.000)
          (foreach entry guideEntries
            (setq p (b2_intersection_extended_best offCab (car entry) pJoint))
            (if (and p
                     (b2_virtual_intersection_within offCab (car entry) p maxExt))
              (progn
                (setq d (distance p pJoint))
                (if (or (not bestEntry) (< d bestD))
                  (progn
                    (setq bestEntry entry)
                    (setq bestPoint p)
                    (setq bestD d)
                  )
                )
              )
            )
          )
          (if bestEntry (list bestEntry bestPoint T) nil)
        )
        nil
      )
    )
  )

  (defun b2_offset_select_toward (e dist ref / entries keep)
    ;; Selecao direta para o centro: mantem o offset mais proximo da referencia.
    (setq entries (b2_offset_candidates_signed e dist))
    (setq keep (b2_signed_entry_by_distance entries ref T))
    (b2_delete_signed_entries_except entries (if keep (car keep) nil))
    (if keep (car keep) nil)
  )

  (defun b2_offset_pair_for_maneuver
    (eCab eGuia distCab distGuia pCabRef pGuideRef pJoint
     / cabEntries guideEntries cabEntry cabOppEntries cabOppEntry guideEntry
       primary tempGuide pExtend tempEntries tempMatch finalSign finalEntries
       finalMatch finalEntry)
    ;; Fluxo normal: cabeceira para a guia e guia afastando-se da cabeceira.
    ;; Reserva: a copia da guia e estendida ate o offset oposto da cabeceira
    ;; para descobrir o sinal de Offset que deve ser aplicado na guia real.
    (setq cabEntries (b2_offset_candidates_signed eCab distCab))
    (setq guideEntries (b2_offset_candidates_signed eGuia distGuia))
    (setq cabEntry (b2_signed_entry_by_distance cabEntries pGuideRef T))
    (setq guideEntry (b2_signed_entry_by_distance guideEntries pCabRef nil))

    (setq primary
      (if (and cabEntry guideEntry)
        (b2_find_offset_intersection
          (car cabEntry) (list guideEntry) pJoint nil
        )
        nil
      )
    )

    (if primary
      (progn
        (setq finalEntry (car primary))
        (b2_delete_signed_entries_except cabEntries (car cabEntry))
        (b2_delete_signed_entries_except guideEntries (car finalEntry))
        (list (car cabEntry) (car finalEntry) (cadr primary) nil)
      )
      (progn
        ;; Os candidatos normais da guia nao serviram. A copia temporaria
        ;; identifica o sinal correto sem tocar na guia do desenho.
        (b2_delete_signed_entries_except guideEntries nil)
        (setq guideEntries nil)
        (setq finalMatch nil)
        (if cabEntry
          (progn
            (setq cabOppEntries
              (b2_signed_entries_for_sign cabEntries (- (cadr cabEntry)))
            )
            (setq cabOppEntry
              (b2_signed_entry_by_distance cabOppEntries pGuideRef T)
            )
            (if cabOppEntry
              (progn
                (setq tempGuide (b2_copy_entity eGuia))
                (if tempGuide
                  (progn
                    (setq pExtend
                      (b2_intersection_extended_best
                        tempGuide (car cabOppEntry) pJoint
                      )
                    )
                    (if (and pExtend
                             (b2_extend_copy_to_boundary
                               tempGuide (car cabOppEntry) pExtend
                             )
                             (b2_intersection_best
                               tempGuide (car cabOppEntry) pJoint
                             ))
                      (progn
                        (setq tempEntries
                          (b2_offset_candidates_signed tempGuide distGuia)
                        )
                        (setq tempMatch
                          (b2_find_offset_intersection
                            (car cabEntry) tempEntries pJoint nil
                          )
                        )
                        (if tempMatch
                          (progn
                            (setq finalSign (cadr (car tempMatch)))
                            (setq finalEntries
                              (b2_signed_entries_for_sign
                                (b2_offset_candidates_signed eGuia distGuia)
                                finalSign
                              )
                            )
                            (setq finalMatch
                              (b2_find_offset_intersection
                                (car cabEntry) finalEntries pJoint T
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

        (b2_delete_signed_entries_except tempEntries nil)
        (if tempGuide (b2_delete_ent tempGuide))

        (if finalMatch
          (progn
            (setq finalEntry (car finalMatch))
            (b2_delete_signed_entries_except cabEntries (car cabEntry))
            (b2_delete_signed_entries_except finalEntries (car finalEntry))
            (list
              (car cabEntry)
              (car finalEntry)
              (cadr finalMatch)
              (caddr finalMatch)
            )
          )
          (progn
            (b2_delete_signed_entries_except cabEntries nil)
            (b2_delete_signed_entries_except finalEntries nil)
            nil
          )
        )
      )
    )
  )

  (defun b2_reference_intersection (e1 e2 pref / p p1 a b q pts)
    ;; Intersecao real entre referencias. Se o ActiveX nao informar um toque
    ;; de extremo, reconhece a ponta que ja esta sobre a outra curva.
    (setq p1 (b2_intersection_best e1 e2 pref))
    (if p1
      p1
      (progn
        (setq pts nil)
        (setq a (vl-catch-all-apply 'vlax-curve-getStartPoint (list e1)))
        (setq b (vl-catch-all-apply 'vlax-curve-getEndPoint (list e1)))
        (foreach p (list a b)
          (if (and p (not (vl-catch-all-error-p p)))
            (progn
              (setq p (b2_pt3 p))
              (setq q (b2_closest_point e2 p))
              (if (and q (<= (distance p q) 1e-4))
                (setq pts (cons q pts))
              )
            )
          )
        )
        (setq a (vl-catch-all-apply 'vlax-curve-getStartPoint (list e2)))
        (setq b (vl-catch-all-apply 'vlax-curve-getEndPoint (list e2)))
        (foreach p (list a b)
          (if (and p (not (vl-catch-all-error-p p)))
            (progn
              (setq p (b2_pt3 p))
              (setq q (b2_closest_point e1 p))
              (if (and q (<= (distance p q) 1e-4))
                (setq pts (cons q pts))
              )
            )
          )
        )
        (if pts (b2_best_point pts pref) nil)
      )
    )
  )


  (defun b2_breakatpoint (e pt / oldCmd pObj res)
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

        (setq oldCmd (getvar "CMDECHO"))

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
    ;; Selecciona SIEMPRE el tramo de cabecera del lado del giro.
    ;;
    ;; La funcion b2_circle_gap_directional ya decidio, usando pCutRef,
    ;; cual de los dos sentidos del circulo se conserva y cual se elimina.
    ;; Por eso aqui usamos el PRIMER segmento conservado del circulo como
    ;; referencia inequívoca:
    ;;
    ;;   - vKeep = sentido del circulo que queda, opuesto al lado del giro.
    ;;   - se elige el tramo de cabecera cuyo sentido desde pTang sea
    ;;     MAS OPUESTO a vKeep.
    ;;
    ;; De esta forma no depende de que pCutRef este exactamente alineado con
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

    (if (not vKeep)
      nil
      (if (and e1 (entget e1) e2 (entget e2))
        (progn
          (setq v1 (b2_dir_from_joint e1 pJoint))
          (setq v2 (b2_dir_from_joint e2 pJoint))
          (if (and v1 v2)
            (progn
              ;; Menor producto escalar = tramo mas opuesto al
              ;; primer segmento conservado del circulo.
              (setq s1 (b2_dot v1 vKeep))
              (setq s2 (b2_dot v2 vKeep))
              (if (<= s1 s2) e1 e2)
            )
            (if v1 e1 (if v2 e2 nil))
          )
        )
        (if (and e1 (entget e1))
          e1
          (if (and e2 (entget e2)) e2 nil)
        )
      )
    )
  )

  (defun b2_join_two (eBase eAdd / oldCmd res)
    ;; Une dos entidades que ya comparten un extremo.
    ;; No prolonga, no crea segmentos y no modifica la geometria antes del JOIN.
    ;; Devuelve T si la segunda entidad fue absorbida por la primera.

    (if (and eBase eAdd (entget eBase) (entget eAdd))
      (progn
        (setq oldCmd (getvar "CMDECHO"))

        (setvar "CMDECHO" 0)

        (setq res
          (vl-catch-all-apply
            'vl-cmdf
            (list "_.JOIN" eBase eAdd "")
          )
        )

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

  (defun b2_select_side_segment (e1 e2 pJoint pRef / vRef v1 v2 s1 s2)
    ;; Escolhe o tramo que sai da quebra na direcao da referencia indicada.
    (setq vRef
      (if (and pJoint pRef)
        (b2_unit (b2_v- pRef pJoint))
        nil
      )
    )
    (if (and e1 (entget e1) e2 (entget e2))
      (if vRef
        (progn
          (setq v1 (b2_dir_from_joint e1 pJoint))
          (setq v2 (b2_dir_from_joint e2 pJoint))
          (if (and v1 v2)
            (progn
              (setq s1 (b2_dot v1 vRef))
              (setq s2 (b2_dot v2 vRef))
              (if (>= s1 s2) e1 e2)
            )
            (if v1 e1 (if v2 e2 e1))
          )
        )
        e1
      )
      (if (and e1 (entget e1))
        e1
        (if (and e2 (entget e2)) e2 nil)
      )
    )
  )

  (defun b2_run_simple ()
    ;; Fluxo direto: intersecao real -> offsets com a guia inteira -> BREAK
    ;; da cabeceira na tangencia. BOTA2 nao conecta o circulo a guia.
    (setq rBarra      (+ rGiro (/ tamImpl 2.0)))
    (setq offCabDist  (/ tamImpl 2.0))
    (setq offGuiaDist (+ (/ tamImpl 2.0) seguridad))
    (b2_clear_temporaries)

    ;; A intersecao original e somente uma referencia. A guia deve permanecer
    ;; completa para que os offsets conservem toda a extensao geometrica.
    (setq pJoint (b2_reference_intersection ent guia pCab))
    (if (not pJoint)
      (prompt "\nNao foi encontrada intersecao real entre a cabeceira e a linha guia.")
      (progn
        ;; Cabeceira no lado definido; guia no lado oposto. Os offsets sao
        ;; calculados antes de qualquer BREAK na geometria original.
        (setq offsetData
          (b2_offset_pair_for_maneuver
            ent guia offCabDist offGuiaDist pCab pGuiaPick pJoint
          )
        )

        (if (not offsetData)
          (progn
            (b2_clear_temporaries)
            (prompt "\nNao foi encontrado um par de offsets nos lados selecionados.")
          )
          (progn
            (setq offCab      (car offsetData))
            (setq offGuia     (cadr offsetData))
            (setq pVert       (caddr offsetData))
            (setq usedVirtual (cadddr offsetData))
            (if usedVirtual
              (prompt "\nIntersecao dos offsets obtida por extensao virtual de ate 1.000 m.")
            )
            (if (not pVert)
              (progn
                (b2_clear_temporaries)
                (prompt "\nNao foi encontrada intersecao valida entre os offsets selecionados.")
              )
              (progn
                ;; O centro pertence ao offset interno da cabecera a R.
                ;; A intersecao com o circulo externo fornece a solucao exata,
                ;; inclusive para segmentos em arco da polilinha.
                (if (and offCab (entget offCab)) (b2_delete_ent offCab))
                (if (and offGuia (entget offGuia)) (b2_delete_ent offGuia))
                (setq offCab nil)
                (setq offGuia nil)
                (setq offCentro (b2_offset_select_toward ent rGiro pVert))
                (setq tmpExtCircle (b2_circle_entity pVert rBarra nil))
                (setq centro
                  (if (and offCentro tmpExtCircle)
                    (b2_intersection_best offCentro tmpExtCircle pJoint)
                    nil
                  )
                )
                (b2_clear_temporaries)

                (setq pTang
                  (if centro (b2_closest_point ent centro) nil)
                )
                (if (or (not centro)
                        (not pTang)
                        (> (abs (- (distance centro pTang) rGiro)) 1e-4))
                  (prompt "\nNao ha tangencia valida entre a cabeceira e a manobra.")
                  (progn
                    ;; A intersecao dos offsets define o lado ocupado pela
                    ;; manobra. O giro e a conexao seguem o lado OPOSTO.
                    ;; Em BOTAX, o ponto manual substitui essa regra.
                    (if manualSideMode
                      (setq pCutRef pSide)
                      (setq pCutRef (b2_opposite_point pTang pVert))
                    )
                    (setq nSegGiro (b2_nseg_inscribed rGiro distSeg))
                    (setq giroData
                      (if *BOTA_CORTAR_CIRCULO*
                        (b2_circle_gap_directional
                          centro rGiro pTang pCutRef nSegGiro nil
                        )
                        (b2_circle_full_directional
                          centro rGiro pTang pCutRef nSegGiro nil
                        )
                      )
                    )
                    (setq entGiro  (car giroData))
                    (setq pGapIni  (cadr giroData))
                    (setq pGapFin  (caddr giroData))
                    (setq ptsGiro  (nth 4 giroData))

                    ;; BOTA2 corta somente a cabeceira, na tangencia real do
                    ;; circulo. A guia permanece intacta neste comando.
                    (setq lastBefore (entlast))
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
                        (setq entCabJoin
                          (b2_select_side_segment ent entCab2 pTang pCutRef)
                        )
                        (setq joinOk
                          (if entCabJoin
                            (b2_join_two entGiro entCabJoin)
                            nil
                          )
                        )
                        (if (not entCabJoin)
                          (prompt "\nAviso: nao foi possivel identificar o trecho correto da cabeceira.")
                          (if (not joinOk)
                            (prompt "\nAviso: o AutoCAD nao conseguiu unir a manobra a cabeceira.")
                          )
                        )
                      )
                      (prompt "\nConexao com cabeceira desativada para BOTA2.")
                    )

                    ;; Referencia visual do raio externo do implemento.
                    (setq entBarra (b2_circle_entity centro rBarra 6))
                    (prompt
                      (strcat
                        "\nRaio Interno: " (rtos rGiro 2 3)
                        " - Raio Externo: " (rtos rBarra 2 3)
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

  ;; -------------------------
  ;; Inicio del comando
  ;; -------------------------

  (setq tol 1e-8)

  ;; Parametros preconfigurados
  (if (not *BOTA_RGIRO*)     (setq *BOTA_RGIRO* 10.000))
  (if (not *BOTA_IMPL*)      (setq *BOTA_IMPL* 36.578))
  (if (not *BOTA_DISTSEG*)   (setq *BOTA_DISTSEG* 0.900))
  (if (not *BOTA_SEGURIDAD*) (setq *BOTA_SEGURIDAD* 0.200))
  (_bota_init_boolean_options)

  (setq oldLuprec (getvar "LUPREC"))
  (setvar "LUPREC" 3)

  (if manualSideMode
    (prompt "\nBOTAX - Manobra por linha guia com lado manual.")
    (prompt "\nBOTA2 - Manobra por linha guia.")
  )
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

              (setq guia       (car sel))
              (setq pGuiaPick (b2_pt3 (cadr sel)))

              (if manualSideMode
                (progn
                  (prompt "\nIndique com o mouse o lado onde sera gerado o giro: ")
                  (setq pSide (getpoint))
                  (if pSide
                    (setq pSide (b2_pt3 pSide))
                  )
                )
                (setq pSide pGuiaPick)
              )

              (if (not pSide)
                (if manualSideMode
                  (prompt "\nNenhum lado manual foi indicado.")
                  (prompt "\nNao foi possivel definir o lado a partir do clique na guia.")
                )
                (progn
                  (if manualSideMode
                    (prompt "\nLado de giro definido pelo ponto manual.")
                    (prompt "\nReferencia de offsets definida pelo clique na guia. O giro sera oposto a intersecao dos offsets.")
                  )

                  ;; -------------------------------------------------
                  ;; Configuracion de parametros
                  ;; Enter = usa valores guardados/preconfigurados
                  ;; C     = configurar todos os parametros
                  ;; R     = ajustar somente o raio de giro
                  ;; -------------------------------------------------

                  (initget "C R")
                  (setq cfg
                    (getkword
                      (strcat
                        "\nParametros atuais:"
                        " Raio Interno=" (rtos *BOTA_RGIRO* 2 3)
                        " | Implemento=" (rtos *BOTA_IMPL* 2 3)
                        " | Seguranca=" (rtos *BOTA_SEGURIDAD* 2 3)
                        " | Segmentos=" (rtos *BOTA_DISTSEG* 2 3)
                        " | Con.Cabeceira=" (if *BOTA_CONECTAR_CAB* "Sim" "Nao")
                        " | Corte.Circulo=" (if *BOTA_CORTAR_CIRCULO* "Sim" "Nao")
                        "\nPressione Enter para usar estes parametros ou [R] raio / [C] configurar: "
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

                  (if (= cfg "R")
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
                      (setq rGiro *BOTA_RGIRO*)
                    )
                  )

                  ;; Calculos principales
                  (if (and rGiro tamImpl seguridad distSeg)
                    (progn
                      (setq rBarra      (+ rGiro (/ tamImpl 2.0)))
                      (setq offCabDist  (/ tamImpl 2.0))
                      (setq offGuiaDist (+ (/ tamImpl 2.0) seguridad))
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

                      (b2_run_simple)

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
;; COMANDO BOTAX - BOTA2 COM PONTO MANUAL DE LADO
;; ============================================================

(defun c:BOTAX ()
  ;; Reutiliza todo o calculo de BOTA2. O terceiro clique define
  ;; explicitamente o lado do giro, do corte e da conexao na cabeceira.
  (setq *BOTA2_MANUAL_SIDE_MODE* T)
  (c:BOTA2)
  (princ)
)

;; ============================================================
;; COMANDO BOTA3 (Version 2.4 - base BOTA2 + FILLET AutoCAD)
;; Maniobra con la base de BOTA2 y FILLET real de AutoCAD hacia linea de guiado
;; ============================================================

(defun c:BOTA3 (/ *error* oldLuprec cfg sel ent guia guiaLocal cabLocal pPick pCab pSide pVert pCutRef
                  rGiro tamImpl seguridad rBarra distSeg filletR filletDistSeg
                  offCabDist offGuiaDist offCab offGuia tol radioTrabajo stepGuia stepCab
                  endParam i p1 p2 u n segLen side base rel tProj pFoot dPerp
                  maxDelta t1 t2 tc candidates candidate bestScore pTang centro
                  nSegGiro score c entGiro entBarra ptsGiro lastBefore lastAfter
                  entCab2 entCabJoin joinOk tmpCircle tmpGuide tmpFillet
                  giroData pGapIni pGapFin pGuiaPick
                  pGuideBase vCutSide vCenter
                  entFillet joinFilletOk)

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
    (if (and offCab (entget offCab))
      (b3_delete_ent offCab)
    )
    (if (and offGuia (entget offGuia))
      (b3_delete_ent offGuia)
    )
    (if (and guiaLocal (entget guiaLocal))
      (b3_delete_ent guiaLocal)
    )
    (if (and cabLocal (entget cabLocal))
      (b3_delete_ent cabLocal)
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

  (defun b3_circle_gap_directional (cen r pAnchor pCutRef nSeg color
                                   / a step pPlus pMinus vSide scorePlus scoreMinus
                                     dir dirKeep gapCount pts i pGap e)
    ;; Circulo interno como polilinea ABIERTA con un hueco DIRECCIONAL.
    ;;
    ;; pAnchor = punto de tangencia con la cabecera.
    ;; pCutRef = referencia del lado donde se debe cortar/conectar.
    ;;
    ;; Se eliminan DOS segmentos consecutivos DESDE pAnchor, pero solamente
    ;; hacia el lado de pCutRef.
    ;;
    ;; Ejemplo:
    ;;   si pCutRef queda hacia la derecha de pAnchor,
    ;;   se eliminan los dos segmentos que salen hacia la derecha.
    ;;
    ;; pAnchor se conserva como extremo del arco porque ya pertenece a la
    ;; cabecera. Luego solo sera necesario conectar el otro extremo del hueco.

    (setq a        (angle cen pAnchor))
    (setq step     (/ (* 2.0 pi) nSeg))
    (setq gapCount 2)

    ;; Vertices vecinos a pAnchor en ambos sentidos del circulo.
    (setq pPlus  (b3_polarpt cen (+ a step) r))
    (setq pMinus (b3_polarpt cen (- a step) r))

    ;; Vector desde la tangencia hacia la referencia de corte/conexion.
    (setq vSide (b3_v- pCutRef pAnchor))

    ;; Cuanto apunta cada sentido hacia pCutRef.
    ;; El mayor producto escalar corresponde al sentido mas cercano a pCutRef.
    (setq scorePlus  (b3_dot (b3_v- pPlus  pAnchor) vSide))
    (setq scoreMinus (b3_dot (b3_v- pMinus pAnchor) vSide))

    (if (>= scorePlus scoreMinus)
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

  (defun b3_offset_all (e dist / obj res out en)
    (if (and e dist)
      (progn
        (setq obj (vlax-ename->vla-object e))
        (setq res
          (vl-catch-all-apply
            'vlax-invoke
            (list obj 'Offset dist)
          )
        )
        (if (vl-catch-all-error-p res)
          nil
          (progn
            (if (= (type res) 'VARIANT)
              (setq res (vlax-variant-value res))
            )
            (if (= (type res) 'SAFEARRAY)
              (setq res (vlax-safearray->list res))
            )
            (if (/= (type res) 'LIST)
              (setq res (list res))
            )

            (setq out nil)
            (foreach obj res
              (setq en
                (vl-catch-all-apply
                  'vlax-vla-object->ename
                  (list obj)
                )
              )
              (if (not (vl-catch-all-error-p en))
                (setq out (cons en out))
              )
            )
            (reverse out)
          )
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

  (defun b3_delete_ents_except (ents keep / en)
    (foreach en ents
      (if (and en (/= en keep))
        (b3_delete_ent en)
      )
    )
  )

  (defun b3_offset_pick_by_side (e ents pSide sameSide / best bestScore bestDist score dist)
    ;; sameSide=T selecciona el offset del mismo lado que pSide.
    ;; sameSide=nil selecciona el offset del lado contrario.
    (cond
      ((not ents) nil)

      ((= (length ents) 1)
        (setq score (b3_offset_side_score e (car ents) pSide))
        (if (if sameSide (> score 1e-9) (< score -1e-9))
          (car ents)
          nil
        )
      )

      (T
        (setq best nil)
        (setq bestScore nil)
        (setq bestDist nil)

        (foreach en ents
          (setq score (b3_offset_side_score e en pSide))
          (setq dist  (b3_dist_to_ent en pSide))
          (if
            (or
              (not best)
              (if sameSide
                (or (> score bestScore)
                    (and (equal score bestScore 1e-9) (< dist bestDist)))
                (or (< score bestScore)
                    (and (equal score bestScore 1e-9) (> dist bestDist)))
              )
            )
            (progn
              (setq best en)
              (setq bestScore score)
              (setq bestDist dist)
            )
          )
        )

        (if (and best (if sameSide (> bestScore 1e-9) (< bestScore -1e-9)))
          best
          nil
        )
      )
    )
  )

  (defun b3_offset_side_score (eBase eOff pSide / pBase pOff vClick vOff)
    ;; Score de lado del offset respecto a la entidad base y al punto indicado.
    ;; Mayor score = offset del mismo lado del punto indicado.
    ;; Menor score = offset del lado contrario. No depende del sentido de dibujo.
    (setq pBase
      (vl-catch-all-apply
        'vlax-curve-getClosestPointTo
        (list eBase pSide)
      )
    )

    (if (vl-catch-all-error-p pBase)
      0.0
      (progn
        (setq pBase (b3_pt3 pBase))
        (setq pOff
          (vl-catch-all-apply
            'vlax-curve-getClosestPointTo
            (list eOff pBase)
          )
        )

        (if (vl-catch-all-error-p pOff)
          0.0
          (progn
            (setq pOff (b3_pt3 pOff))
            (setq vClick (b3_v- pSide pBase))
            (setq vOff   (b3_v- pOff pBase))
            (b3_dot vClick vOff)
          )
        )
      )
    )
  )

  (defun b3_offset_select (e dist pSide / ents keep)
    ;; Crea offset positivo y negativo.
    ;; En v5, pSide es la zona indicada por el usuario para la salida/corte.
    ;; Mantiene el offset del mismo lado de esa zona.

    (setq ents
      (append
        (b3_offset_all e dist)
        (b3_offset_all e (- dist))
      )
    )
    (setq keep (b3_offset_pick_by_side e ents pSide T))
    (b3_delete_ents_except ents keep)
    keep
  )

  (defun b3_offset_select_opposite (e dist pSide / ents keep)
    ;; Crea offset positivo y negativo.
    ;; Mantiene el offset del lado contrario a la zona indicada.

    (setq ents
      (append
        (b3_offset_all e dist)
        (b3_offset_all e (- dist))
      )
    )
    (setq keep (b3_offset_pick_by_side e ents pSide nil))
    (b3_delete_ents_except ents keep)
    keep
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

  (defun b3_cross2 (a b)
    (- (* (car a) (cadr b)) (* (cadr a) (car b)))
  )

  (defun b3_segment_intersection (a b c d / r s den q tParam uParam)
    ;; Intersecao de segmentos finitos, sem prolongar as entidades.
    (setq r   (b3_v- b a))
    (setq s   (b3_v- d c))
    (setq den (b3_cross2 r s))
    (if (< (abs den) 1e-10)
      nil
      (progn
        (setq q      (b3_v- c a))
        (setq tParam (/ (b3_cross2 q s) den))
        (setq uParam (/ (b3_cross2 q r) den))
        (if (and (>= tParam -1e-8) (<= tParam (+ 1.0 1e-8))
                 (>= uParam -1e-8) (<= uParam (+ 1.0 1e-8)))
          (b3_v+ a (b3_v* tParam r))
          nil
        )
      )
    )
  )

  (defun b3_curve_segments (e / endParam i p1 p2 out)
    ;; Offsets locais sao polilinhas; percorre seus segmentos reais.
    (setq endParam
      (vl-catch-all-apply 'vlax-curve-getEndParam (list e))
    )
    (setq out nil)
    (if (not (vl-catch-all-error-p endParam))
      (progn
        (setq i 0)
        (while (< i endParam)
          (setq p1
            (vl-catch-all-apply 'vlax-curve-getPointAtParam (list e i))
          )
          (setq p2
            (vl-catch-all-apply 'vlax-curve-getPointAtParam (list e (1+ i)))
          )
          (if (and (not (vl-catch-all-error-p p1))
                   (not (vl-catch-all-error-p p2)))
            (setq out (cons (list (b3_pt3 p1) (b3_pt3 p2)) out))
          )
          (setq i (1+ i))
        )
      )
    )
    (reverse out)
  )

  (defun b3_intersections_fallback (e1 e2 / pts s1 s2 p)
    (setq pts nil)
    (foreach s1 (b3_curve_segments e1)
      (foreach s2 (b3_curve_segments e2)
        (setq p (b3_segment_intersection (car s1) (cadr s1) (car s2) (cadr s2)))
        (if p (setq pts (cons p pts)))
      )
    )
    pts
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
          (progn
            (if (= (type res) 'VARIANT)
              (setq res (vlax-variant-value res))
            )
            (if (= (type res) 'SAFEARRAY)
              (setq res (vlax-safearray->list res))
            )
            (b3_triplets res)
          )
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
    (if (not pts)
      (setq pts (b3_intersections_fallback e1 e2))
    )

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

  (defun b3_breakatpoint (e pt / oldCmd pObj res)
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

        (setq oldCmd (getvar "CMDECHO"))

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
    ;; Selecciona SIEMPRE el tramo de cabecera del lado del giro.
    ;;
    ;; La funcion b3_circle_gap_directional ya decidio, usando pCutRef,
    ;; cual de los dos sentidos del circulo se conserva y cual se elimina.
    ;; Por eso aqui usamos el PRIMER segmento conservado del circulo como
    ;; referencia inequívoca:
    ;;
    ;;   - vKeep = sentido del circulo que queda, opuesto al lado del giro.
    ;;   - se elige el tramo de cabecera cuyo sentido desde pTang sea
    ;;     MAS OPUESTO a vKeep.
    ;;
    ;; De esta forma no depende de que pCutRef este exactamente alineado con
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

  (defun b3_join_two (eBase eAdd / oldCmd oldPedit res ok fuzz)
    ;; Une dos entidades que ya comparten un extremo.
    ;; No prolonga ni crea segmentos. Si JOIN simple no absorbe la entidad,
    ;; prueba PEDIT JOIN con una tolerancia pequena para casos en que FILLET
    ;; devuelve LWPOLYLINE/POLYLINE y AutoCAD deja microdiferencias.
    ;; Devuelve T si la segunda entidad fue absorbida por la primera.

    (if (and eBase eAdd (entget eBase) (entget eAdd))
      (progn
        (setq oldCmd (getvar "CMDECHO"))
        (setq oldPedit
          (vl-catch-all-apply
            'getvar
            (list "PEDITACCEPT")
          )
        )
        (setq fuzz 0.001)

        (setvar "CMDECHO" 0)
        (if (not (vl-catch-all-error-p oldPedit))
          (setvar "PEDITACCEPT" 1)
        )

        (setq res
          (vl-catch-all-apply
            'vl-cmdf
            (list "_.JOIN" eBase eAdd "")
          )
        )

        (setq ok
          (and
            (not (vl-catch-all-error-p res))
            (entget eBase)
            (not (entget eAdd))
          )
        )

        (if (not ok)
          (progn
            (setq res
              (vl-catch-all-apply
                'vl-cmdf
                (list "_.PEDIT" eBase "_J" eAdd "" fuzz "")
              )
            )

            (setq ok
              (and
                (not (vl-catch-all-error-p res))
                (entget eBase)
                (not (entget eAdd))
              )
            )
          )
        )

        (setvar "CMDECHO" oldCmd)
        (if (not (vl-catch-all-error-p oldPedit))
          (setvar "PEDITACCEPT" oldPedit)
        )

        ok
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

  (defun b3_keep_direction (cen r pAnchor pCutRef nSeg / a step pPlus pMinus vSide scorePlus scoreMinus dir)
    ;; Devuelve el sentido (+1 / -1) del circulo que se conserva.
    ;; En v5, pCutRef es la zona donde debe ocurrir la salida/conexion.
    ;; Se conserva el sentido que apunta hacia esa zona.
    (setq a    (angle cen pAnchor))
    (setq step (/ (* 2.0 pi) nSeg))

    (setq pPlus  (b3_polarpt cen (+ a step) r))
    (setq pMinus (b3_polarpt cen (- a step) r))
    (setq vSide  (b3_v- pCutRef pAnchor))

    (setq scorePlus  (b3_dot (b3_v- pPlus  pAnchor) vSide))
    (setq scoreMinus (b3_dot (b3_v- pMinus pAnchor) vSide))

    (if (>= scorePlus scoreMinus)
      (setq dir 1.0)
      (setq dir -1.0)
    )

    dir
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
                         / oldRad oldTrim oldCmd before after res)
    ;; Crea un FILLET real de AutoCAD SIN recortar las entidades de referencia.
    ;; Devuelve el ARC creado o nil.

    (setq oldRad  (getvar "FILLETRAD"))
    (setq oldTrim (getvar "TRIMMODE"))
    (setq oldCmd  (getvar "CMDECHO"))

    (setvar "FILLETRAD" rad)
    (setvar "CMDECHO" 0)

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
                           / oldRad oldTrim oldCmd before after res afterData afterType)
    ;; Ejecuta FILLET de la MISMA FORMA que el usuario lo hace manualmente:
    ;;   1) selecciona la linea de guiado en un PUNTO concreto;
    ;;   2) selecciona el circulo/polilinea en un PUNTO concreto.
    ;;
    ;; Los puntos de seleccion son fundamentales: AutoCAD los usa para
    ;; decidir que lado de cada objeto debe recortar y que solucion de fillet
    ;; debe generar. No se utilizan endpoints ni lineas temporales.

    (setq *BOTA3_FILLET_FAIL* nil)

    (if (not (and eGuide pGuide eTurn pTurn rad))
      (progn
        (setq *BOTA3_FILLET_FAIL*
          "faltam entidade ou ponto de selecao para executar o FILLET."
        )
        nil
      )
      (progn
        (setq oldRad  (getvar "FILLETRAD"))
        (setq oldTrim (getvar "TRIMMODE"))
        (setq oldCmd  (getvar "CMDECHO"))

        (setvar "FILLETRAD" rad)
        (setvar "TRIMMODE" 1)
        (setvar "CMDECHO" 0)

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

        ;; Segun el tipo de objetos seleccionados, AutoCAD puede crear un ARC
        ;; independiente o una polilinha con el redondeo incorporado.
        (cond
          ((vl-catch-all-error-p res)
            (setq *BOTA3_FILLET_FAIL*
              (strcat
                "AutoCAD devolveu erro no comando FILLET: "
                (vl-catch-all-error-message res)
              )
            )
            nil
          )
          ((not after)
            (setq *BOTA3_FILLET_FAIL*
              "AutoCAD nao retornou nenhuma entidade depois do FILLET."
            )
            nil
          )
          ((= after before)
            (setq *BOTA3_FILLET_FAIL*
              "AutoCAD nao criou uma entidade nova para o FILLET. Verifique se o raio cabe entre a guia e a bota, ou se os pontos de selecao estao no lado correto."
            )
            nil
          )
          ((not (setq afterData (entget after)))
            (setq *BOTA3_FILLET_FAIL*
              "AutoCAD criou uma entidade no FILLET, mas ela nao esta mais valida."
            )
            nil
          )
          ((not
             (member
               (setq afterType (cdr (assoc 0 afterData)))
               (list "ARC" "LWPOLYLINE" "POLYLINE")
             )
           )
            (setq *BOTA3_FILLET_FAIL*
              (strcat
                "AutoCAD criou uma entidade do tipo "
                (if afterType afterType "desconhecido")
                ", mas o BOTA3 esperava ARC, LWPOLYLINE ou POLYLINE."
              )
            )
            nil
          )
          (T
            after
          )
        )
      )
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

  (defun b3_fillet_solver (cen r pTang pCutRef pVert guia filletR nSegGiro
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
    ;; solucion externa valida sobre la guia local, el solver devuelve nil.

    (setq model (b3_guide_model_near_circle guia cen))
    (if (not model)
      nil
      (progn
        (setq p0 (car model))
        (setq u  (cadr model))
        (setq n  (caddr model))
        (setq dirKeep (b3_keep_direction cen r pTang pCutRef nSegGiro))
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
  (if (not *BOTA_DISTSEG*)     (setq *BOTA_DISTSEG* 0.900))
  (if (not *BOTA_SEGURIDAD*)   (setq *BOTA_SEGURIDAD* 0.200))
  (_bota_init_boolean_options)

  ;; Parametros independientes del FILLET
  (if (not *BOTA_FILLET_R*)     (setq *BOTA_FILLET_R* 30.000))
  (if (not *BOTA_FILLET_SEG*)   (setq *BOTA_FILLET_SEG* 1.500))

  (setq oldLuprec (getvar "LUPREC"))
  (setvar "LUPREC" 3)

  (prompt "\nBOTA3 - Manobra com base BOTA2 + FILLET automatico para linha guia.")
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
              (setq pGuiaPick (b3_pt3 (cadr sel)))
              (setq pSide     (_bota_side_from_picks pPick pGuiaPick))

              (if (not pSide)
                (prompt "\nNao foi possivel definir o lado a partir dos cliques na cabeceira e na guia.")
                (progn
                  (prompt "\nLado de giro definido pelos cliques na cabeceira e na guia.")

                  ;; -------------------------------------------------
                  ;; Configuracion de parametros
                  ;;
                  ;; Enter = usa todos los valores guardados
                  ;; C     = parametros generales de BOTA3
                  ;; B     = parametros exclusivos del FILLET
                  ;; R     = ajustar los dos radios
                  ;; -------------------------------------------------

                  (initget "C B R")
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
                        "\nPressione Enter para continuar ou [R] raios / [C] gerais / [B] fillet: "
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

                    ((= cfg "R")
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
                      ;; A aproximacao curta preserva curvas da cabecera e guia.
                      (setq radioTrabajo (max 50.000 (* 2.0 rBarra)))
                      (setq stepGuia    (max 0.100 (min 0.250 distSeg)))
                      (setq stepCab     stepGuia)
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

                      ;; As duas curvas sao limitadas a zona da manobra.
                      (setq guiaLocal
                        (b3_local_poly_from_curve guia pCab radioTrabajo stepGuia)
                      )

                      (setq cabLocal
                        (b3_local_poly_from_curve ent pCab radioTrabajo stepCab)
                      )

                      (if (or (not guiaLocal) (not cabLocal))
                        (progn
                          (if guiaLocal (b3_delete_ent guiaLocal))
                          (if cabLocal (b3_delete_ent cabLocal))
                          (prompt "\nNao foi possivel criar os trechos locais da cabecera e da linha guia.")
                        )
                        (progn

                          ;; Offsets temporales:
                          ;; cabecera hacia el lado indicado, guia hacia el lado contrario.
                          (setq offCab
                            (b3_offset_select cabLocal offCabDist pSide)
                          )

                          (setq offGuia
                            (b3_offset_select_opposite guiaLocal offGuiaDist pSide)
                          )

                          (if (or (not offCab) (not offGuia))
                            (progn
                              (if offCab (b3_delete_ent offCab))
                              (if offGuia (b3_delete_ent offGuia))
                              (if guiaLocal (b3_delete_ent guiaLocal))
                              (if cabLocal (b3_delete_ent cabLocal))
                              (prompt "\nNao foi possivel criar os offsets.")
                            )
                            (progn

                              ;; Punto calculado por interseccion de offsets.
                              ;; Se toma la interseccion mas cercana al click sobre la cabecera.
                              (setq pVert
                                (b3_intersection_best offCab offGuia pCab)
                              )

                              ;; Direccion de corte/conexion:
                              ;; opuesta al offset real de la guia.
                              ;; pVert esta sobre offGuia; pGuideBase esta sobre guiaLocal.
                              (setq pGuideBase
                                (if pVert
                                  (b3_closest_point guiaLocal pVert)
                                  nil
                                )
                              )
                              (setq vCutSide
                                (if pGuideBase
                                  (b3_unit (b3_v- pGuideBase pVert))
                                  nil
                                )
                              )

                              ;; Borra auxiliares temporales que ya no usa el solver.
                              (b3_delete_ent offCab)
                              (b3_delete_ent offGuia)
                              (b3_delete_ent guiaLocal)

                              (if (or (not pVert) (not vCutSide))
                                (progn
                                  (if cabLocal (b3_delete_ent cabLocal))
                                  (prompt "\nNao foi encontrada intersecao valida entre os offsets locais.")
                                )
                                (progn

                                  ;; Busca apenas os segmentos da cabecera local. Para arcos,
                                  ;; cabLocal ja contem cordas curtas em vez de uma unica corda.
                                  (setq candidates nil)

                                  (setq endParam
                                    (vl-catch-all-apply
                                      'vlax-curve-getEndParam
                                      (list cabLocal)
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
                                            (list cabLocal i)
                                          )
                                        )

                                        (setq p2
                                          (vl-catch-all-apply
                                            'vlax-curve-getPointAtParam
                                            (list cabLocal (1+ i))
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
                                                                    (list
                                                                      score
                                                                      pTang
                                                                      centro
                                                                      (b3_v+ pTang vCutSide)
                                                                    )
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

                                          ;; Reprojeta a tangencia na cabecera original antes
                                          ;; do BREAK, mantendo o circulo no raio configurado.
                                          (setq pTang (cadr candidate))
                                          (setq centro (caddr candidate))
                                          (setq vCenter (b3_unit (b3_v- centro pTang)))
                                          (setq pTang (b3_closest_point ent pTang))
                                          (if (and pTang vCenter)
                                            (setq centro (b3_v+ pTang (b3_v* rGiro vCenter)))
                                          )
                                          (setq pCutRef (b3_v+ pTang vCutSide))
                                          (if cabLocal (b3_delete_ent cabLocal))

                                          ;; Segmentacion base del circulo interno
                                          (setq nSegGiro (b3_nseg_inscribed rGiro distSeg))

                                          ;; -------------------------------------------------
                                          ;; 1) GENERA LA BASE IGUAL QUE BOTA2
                                          ;; -------------------------------------------------
                                          ;; Primero crea el arco interno con el hueco hacia
                                          ;; el lado contrario al offset real de la guia.
                                          (setq giroData
                                            (b3_circle_gap_directional
                                              centro rGiro pTang pCutRef nSegGiro nil
                                            )
                                          )

                                          (setq entGiro (car giroData))
                                          (setq pGapIni (cadr giroData)) ;; = pTang
                                          (setq pGapFin (caddr giroData))
                                          (setq ptsGiro (nth 4 giroData))

                                          ;; -------------------------------------------------
                                          ;; 2) FILLET REAL DO AUTOCAD, COMO NO PROCESSO MANUAL
                                          ;; -------------------------------------------------
                                          ;; Usa a guia original para que o FILLET faca o TRIM
                                          ;; da linha de guiado visivel. Os pontos de selecao
                                          ;; simulam o clique manual mostrado no video.
                                          (setq pGuiaPick
                                            (if pGuideBase
                                              (b3_closest_point guia pGuideBase)
                                              nil
                                            )
                                          )

                                          (setq *BOTA3_FILLET_FAIL*
                                            (cond
                                              ((not entGiro)
                                                "a bota interna nao foi criada antes do FILLET."
                                              )
                                              ((not pGuiaPick)
                                                "nao foi possivel calcular o ponto de selecao na linha guia original."
                                              )
                                              ((not pGapFin)
                                                "nao foi possivel calcular o ponto de selecao na bota interna."
                                              )
                                              (T nil)
                                            )
                                          )

                                          (setq entFillet
                                            (if (and entGiro pGuiaPick pGapFin)
                                              (b3_fillet_direct
                                                guia pGuiaPick entGiro pGapFin filletR
                                              )
                                              nil
                                            )
                                          )

                                          (if (and entFillet entGiro (entget entGiro))
                                            (progn
                                              (setq joinFilletOk
                                                (b3_join_two entGiro entFillet)
                                              )
                                              (if (not joinFilletOk)
                                                (prompt
                                                  "\nAviso: FILLET criado, mas nao foi possivel unir a entidade do FILLET a bota."
                                                )
                                              )
                                            )
                                            (progn
                                              (if (and entFillet entGiro (not (entget entGiro)))
                                                (setq *BOTA3_FILLET_FAIL*
                                                  "AutoCAD criou a entidade do FILLET, mas a entidade da bota interna deixou de estar valida depois do recorte."
                                                )
                                              )
                                              (if entGiro (b3_delete_ent entGiro))
                                              (if entFillet (b3_delete_ent entFillet))
                                              (setq entGiro nil)
                                              (prompt
                                                (strcat
                                                  "\nNao foi possivel executar FILLET automatico entre a bota e a linha guia."
                                                  (if *BOTA3_FILLET_FAIL*
                                                    (strcat "\nMotivo: " *BOTA3_FILLET_FAIL*)
                                                    "\nMotivo: AutoCAD nao informou uma causa especifica."
                                                  )
                                                )
                                              )
                                            )
                                          )

                                          ;; -------------------------------------------------
                                          ;; 3) CONECTA EL CIRCULO A LA CABECERA
                                          ;; -------------------------------------------------
                                          ;; Se mantiene exactamente la regla ya validada en BOTA2:
                                          ;; BREAKATPOINT en pTang y JOIN siempre con el tramo
                                          ;; coerente com o lado do giro indicado pelo usuario.
                                          (if (and entGiro (entget entGiro))
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
                                                      "\nAviso: nao foi possivel identificar o trecho correto da cabeceira."
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

                                          (if (and entGiro (entget entGiro))
                                            (progn
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
                                          )

                                        )
                                        (progn
                                          (if cabLocal (b3_delete_ent cabLocal))
                                          (prompt "\nNao ha tangencia valida entre a cabecera local e a manobra.")
                                          (prompt "\nRevise o lado selecionado, o raio de giro e a linha guia.")
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

  (if guiaLocal
    (b3_delete_ent guiaLocal)
  )
  (b3_restore)
  (princ)
)

;; ============================================================
;; COMANDO BOTAF
;; Fillet automatico entre cabeceira e linha, convertido em segmentos
;; ============================================================

(defun c:BOTAF (/ *error* oldLuprec selCab selLinha entCab entLinha pPickCab pPickLinha
                  pSide pCabSel pLinhaSel cfg filletR filletDistSeg entFillet
                  entSegmentado lastBefore lastAfter entCab2 entCabFillet pCabFillet breakOk
                  pBreak cabParts guideParts entCabOther entGuideFillet entGuideOther
                  geom pTanGuide pTanCab pRealTanGuide pRealTanCab pCenter pts trimGuide trimCab
                  joinOk joinGuideOk joinCabOk joinGuideEnt joinCabEnt arcZ
                  guidePts cabPts mergedPts angleInternal autoAngle autoAngleDeg
                  autoRange manualMode modeError)

  (vl-load-com)

  (defun bf_restore ()
    (if oldLuprec
      (setvar "LUPREC" oldLuprec)
    )
  )

  (defun *error* (msg)
    (bf_restore)
    (if (and msg (/= msg "Function cancelled") (/= msg "quit / exit abort"))
      (prompt (strcat "\nErro: " msg))
    )
    (princ)
  )

  (defun bf_num_p (x)
    (and x (= (type x) 'REAL))
  )

  (defun bf_pt3 (p / x y z)
    (if (and (listp p)
             (numberp (car p))
             (numberp (cadr p)))
      (progn
        (setq x (float (car p)))
        (setq y (float (cadr p)))
        (setq z
          (if (numberp (caddr p))
            (float (caddr p))
            0.0
          )
        )
        (list x y z)
      )
      nil
    )
  )

  (defun bf_pt2 (p / q)
    (setq q (bf_pt3 p))
    (if q
      (list (car q) (cadr q))
      nil
    )
  )

  (defun bf_ceil (x / i)
    (setq i (fix x))
    (if (> x i)
      (1+ i)
      i
    )
  )

  (defun bf_v- (a b)
    (list (- (car a) (car b)) (- (cadr a) (cadr b)) 0.0)
  )

  (defun bf_dot (a b)
    (+ (* (car a) (car b)) (* (cadr a) (cadr b)))
  )

  (defun bf_len (v)
    (sqrt (+ (* (car v) (car v)) (* (cadr v) (cadr v))))
  )

  (defun bf_unit (v / l)
    (setq l (bf_len v))
    (if (> l 1e-12)
      (list (/ (car v) l) (/ (cadr v) l) 0.0)
      nil
    )
  )

  (defun bf_v+ (a b)
    (list (+ (car a) (car b)) (+ (cadr a) (cadr b)) 0.0)
  )

  (defun bf_v* (s v)
    (list (* s (car v)) (* s (cadr v)) 0.0)
  )

  (defun bf_norm_2pi (a)
    (while (< a 0.0)
      (setq a (+ a (* 2.0 pi)))
    )
    (while (>= a (* 2.0 pi))
      (setq a (- a (* 2.0 pi)))
    )
    a
  )

  (defun bf_polarpt (c a r)
    (list
      (+ (car c) (* r (cos a)))
      (+ (cadr c) (* r (sin a)))
      0.0
    )
  )

  (defun bf_asin (x)
    (if (>= x 1.0)
      (/ pi 2.0)
      (if (<= x -1.0)
        (- (/ pi 2.0))
        (atan (/ x (sqrt (- 1.0 (* x x)))))
      )
    )
  )

  (defun bf_closest_point (e pt / p)
    (setq pt (bf_pt3 pt))
    (if (not pt)
      nil
      (progn
        (setq p
          (vl-catch-all-apply
            'vlax-curve-getClosestPointTo
            (list e pt)
          )
        )
        (if (vl-catch-all-error-p p)
          nil
          (bf_pt3 p)
        )
      )
    )
  )

  (defun bf_intersections (e1 e2 / o1 o2 raw pts)
    (if (and e1 e2 (entget e1) (entget e2))
      (progn
        (setq o1 (vlax-ename->vla-object e1))
        (setq o2 (vlax-ename->vla-object e2))
        (setq raw
          (vl-catch-all-apply
            'vlax-invoke
            (list o1 'IntersectWith o2 0)
          )
        )

        (if (or (vl-catch-all-error-p raw) (not raw))
          nil
          (progn
            (if (= (type raw) 'VARIANT)
              (setq raw
                (vl-catch-all-apply
                  'vlax-safearray->list
                  (list (vlax-variant-value raw))
                )
              )
            )
            (if (= (type raw) 'SAFEARRAY)
              (setq raw
                (vl-catch-all-apply
                  'vlax-safearray->list
                  (list raw)
                )
              )
            )

            (setq pts nil)
            (while (and (listp raw) (>= (length raw) 3))
              (setq pts
                (append pts
                  (list
                    (list
                      (float (car raw))
                      (float (cadr raw))
                      (float (caddr raw))
                    )
                  )
                )
              )
              (setq raw (cdddr raw))
            )
            pts
          )
        )
      )
      nil
    )
  )

  (defun bf_best_point (pts ref / best bestD d)
    (if (and pts ref)
      (progn
        (setq best (car pts))
        (setq bestD (distance best ref))
        (foreach p pts
          (setq d (distance p ref))
          (if (< d bestD)
            (progn
              (setq best p)
              (setq bestD d)
            )
          )
        )
        best
      )
      (car pts)
    )
  )

  (defun bf_curve_valid_p (e pt)
    (if (bf_closest_point e pt)
      T
      nil
    )
  )

  (defun bf_breakatpoint (e pt / oldCmd pObj res)
    (if (and e pt)
      (progn
        (setq pObj (bf_closest_point e pt))
        (if (not pObj)
          (setq pObj (bf_pt3 pt))
        )

        (if pObj
          (progn
            (setq oldCmd (getvar "CMDECHO"))

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

            (if (vl-catch-all-error-p res)
              (setq res
                (vl-catch-all-apply
                  'vl-cmdf
                  (list "_.BREAK" (list e pObj) "_F" "_non" pObj "_non" pObj)
                )
              )
            )

            (setvar "CMDECHO" oldCmd)

            (if (vl-catch-all-error-p res)
              nil
              T
            )
          )
          nil
        )
      )
      nil
    )
  )

  (defun bf_dir_from_joint (e pJoint / pStart pEnd dStart dEnd endParam total delta pTest v)
    ;; Direcao local que sai do ponto de quebra para dentro do tramo.
    (if (and e (entget e) pJoint)
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
            (setq pStart (bf_pt3 pStart))
            (setq pEnd   (bf_pt3 pEnd))
            (setq dStart (distance pJoint pStart))
            (setq dEnd   (distance pJoint pEnd))

            (setq endParam
              (vl-catch-all-apply
                'vlax-curve-getEndParam
                (list e)
              )
            )

            (if (vl-catch-all-error-p endParam)
              nil
              (progn
                (setq total
                  (vl-catch-all-apply
                    'vlax-curve-getDistAtParam
                    (list e endParam)
                  )
                )

                (if (or (vl-catch-all-error-p total) (<= total 1e-9))
                  nil
                  (progn
                    (setq delta (min 1.0 (* total 0.10)))
                    (setq delta (max delta 0.001))
                    (if (> delta total)
                      (setq delta (* total 0.5))
                    )

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
                        (setq v (bf_v- (bf_pt3 pTest) pJoint))
                        (bf_unit v)
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

  (defun bf_select_side_segment (e1 e2 pJoint pSide / vSide v1 v2 s1 s2)
    ;; Escolhe o tramo da cabeceira que sai da quebra para o lado indicado.
    (setq vSide
      (if (and pJoint pSide)
        (bf_unit (bf_v- pSide pJoint))
        nil
      )
    )

    (if (not vSide)
      nil
      (if (and e1 (entget e1) e2 (entget e2))
        (progn
          (setq v1 (bf_dir_from_joint e1 pJoint))
          (setq v2 (bf_dir_from_joint e2 pJoint))
          (if (and v1 v2)
            (progn
              (setq s1 (bf_dot v1 vSide))
              (setq s2 (bf_dot v2 vSide))
              (if (>= s1 s2) e1 e2)
            )
            (if v1 e1 (if v2 e2 nil))
          )
        )
        (if (and e1 (entget e1))
          e1
          (if (and e2 (entget e2)) e2 nil)
        )
      )
    )
  )

  (defun bf_pick_from_joint (e pJoint rad / pStart pEnd dStart dEnd endPar total step p)
    ;; Ponto de selecao dentro do tramo, um pouco afastado do extremo quebrado.
    (if (and e (entget e) pJoint)
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
        (setq endPar
          (vl-catch-all-apply
            'vlax-curve-getEndParam
            (list e)
          )
        )

        (if (or (vl-catch-all-error-p pStart)
                (vl-catch-all-error-p pEnd)
                (vl-catch-all-error-p endPar))
          nil
          (progn
            (setq pStart (bf_pt3 pStart))
            (setq pEnd   (bf_pt3 pEnd))
            (setq total
              (vl-catch-all-apply
                'vlax-curve-getDistAtParam
                (list e endPar)
              )
            )

            (if (or (vl-catch-all-error-p total) (<= total 1e-9))
              nil
              (progn
                (setq dStart (distance pJoint pStart))
                (setq dEnd   (distance pJoint pEnd))
                (setq step (min total (max 0.250 (min (* rad 0.25) (* total 0.25)))))

                (if (<= dStart dEnd)
                  (setq p
                    (vl-catch-all-apply
                      'vlax-curve-getPointAtDist
                      (list e step)
                    )
                  )
                  (setq p
                    (vl-catch-all-apply
                      'vlax-curve-getPointAtDist
                      (list e (- total step))
                    )
                  )
                )

                (if (vl-catch-all-error-p p)
                  nil
                  (bf_pt3 p)
                )
              )
            )
          )
        )
      )
      nil
    )
  )

  (defun bf_dir_to_pick (e pJoint pPick / p v)
    (setq p (bf_closest_point e pPick))
    (if (and p pJoint)
      (progn
        (setq v (bf_v- p pJoint))
        (bf_unit v)
      )
      nil
    )
  )

  (defun bf_angle_between_vectors (v1 v2 / dotv)
    (if (and v1 v2)
      (progn
        (setq dotv (bf_dot v1 v2))
        (if (> dotv 0.999999) (setq dotv 0.999999))
        (if (< dotv -0.999999) (setq dotv -0.999999))
        (atan (sqrt (max 0.0 (- 1.0 (* dotv dotv)))) dotv)
      )
      nil
    )
  )

  (defun bf_auto_range_for_angle (angleDeg ranges / range found lastRange)
    (setq lastRange (car (reverse ranges)))
    (foreach range ranges
      (if (and (not found)
               (>= angleDeg (car range))
               (or (< angleDeg (cadr range))
                   (and (equal range lastRange)
                        (<= angleDeg (cadr range)))))
        (setq found range)
      )
    )
    found
  )

  (defun bf_arc_points_center (cen r pStart pEnd distMax / a0 a1 dCcw dCw dir delta n stepA i pts)
    (setq a0 (angle cen pStart))
    (setq a1 (angle cen pEnd))
    (setq dCcw (bf_norm_2pi (- a1 a0)))
    (setq dCw  (bf_norm_2pi (- a0 a1)))

    (if (<= dCcw dCw)
      (progn
        (setq dir 1.0)
        (setq delta dCcw)
      )
      (progn
        (setq dir -1.0)
        (setq delta dCw)
      )
    )

    (if (or (< delta 1e-10) (not distMax) (<= distMax 1e-10))
      nil
      (progn
        (setq n (max 1 (bf_ceil (/ (* r delta) distMax))))
        (setq stepA (/ delta n))
        (setq pts (list pStart))
        (setq i 1)

        (repeat (1- n)
          (setq pts
            (append pts
              (list
                (bf_polarpt cen (+ a0 (* dir i stepA)) r)
              )
            )
          )
          (setq i (1+ i))
        )

        (append pts (list pEnd))
      )
    )
  )

  (defun bf_fillet_geometry (e1 e2 pVertex rad / u1 u2 dotv theta tanHalf d bis cen pT1 pT2)
    ;; Calcula os pontos de tangencia sem chamar o comando FILLET do AutoCAD.
    ;; e1 e e2 ja devem ser os dois tramos que saem da intersecao escolhida.
    (setq u1 (bf_dir_from_joint e1 pVertex))
    (setq u2 (bf_dir_from_joint e2 pVertex))

    (if (not (and u1 u2 pVertex rad (> rad 0.0)))
      nil
      (progn
        (setq dotv (bf_dot u1 u2))
        (if (> dotv 0.999999) (setq dotv 0.999999))
        (if (< dotv -0.999999) (setq dotv -0.999999))
        (setq theta
          (atan
            (sqrt (max 0.0 (- 1.0 (* dotv dotv))))
            dotv
          )
        )

        (if (or (< theta 1e-6) (> theta (- pi 1e-6)))
          nil
          (progn
            (setq tanHalf (/ (sin (/ theta 2.0)) (cos (/ theta 2.0))))
            (setq d (/ rad tanHalf))
            (setq bis (bf_unit (bf_v+ u1 u2)))

            (if (not bis)
              nil
              (progn
                (setq cen (bf_v+ pVertex (bf_v* (/ rad (sin (/ theta 2.0))) bis)))
                (setq pT1 (bf_v+ pVertex (bf_v* d u1)))
                (setq pT2 (bf_v+ pVertex (bf_v* d u2)))
                ;; Tangencia 1, tangencia 2, centro, afastamento e angulo interno.
                (list pT1 pT2 cen d theta)
              )
            )
          )
        )
      )
    )
  )

  (defun bf_replace_last (data code value / rev pair)
    (setq rev (reverse data))
    (setq pair (assoc code rev))
    (if pair
      (reverse (subst (cons code value) pair rev))
      data
    )
  )

  (defun bf_set_curve_ends (pts pStart pEnd / middle)
    ;; Faz a polilinha do arco terminar exatamente nos pontos reais das curvas.
    (if (and pts pStart pEnd (>= (length pts) 2))
      (progn
        (setq middle (reverse (cdr (reverse (cdr pts)))))
        (append (list pStart) middle (list pEnd))
      )
      pts
    )
  )

  (defun bf_set_points_z (pts z)
    ;; Mantem a mesma elevacao da geometria que sera unida ao arco.
    (if (and pts (numberp z))
      (mapcar
        '(lambda (p) (list (car p) (cadr p) (float z)))
        pts
      )
      pts
    )
  )

  (defun bf_curve_points_to_outer (e pJoint pTangent distMax
                                   / pJ pTan endPar total dJ dTan dOuter eType markers ordered
                                     pVertex dVertex n step i j d0 d1 d p pts)
    ;; Retorna o tramo desde a tangencia ate o extremo exterior da curva.
    ;; Para LWPOLYLINE, preserva todos os vertices reais para que o solver nao
    ;; calcule uma tangencia sobre uma corda que atravesse um vertice.
    (setq pJ   (bf_closest_point e pJoint))
    (setq pTan (bf_closest_point e pTangent))
    (setq endPar
      (vl-catch-all-apply 'vlax-curve-getEndParam (list e))
    )

    (if (or (not pJ)
            (not pTan)
            (vl-catch-all-error-p endPar)
            (not distMax)
            (<= distMax 1e-10))
      nil
      (progn
        (setq total
          (vl-catch-all-apply
            'vlax-curve-getDistAtParam
            (list e endPar)
          )
        )
        (setq dJ
          (vl-catch-all-apply
            'vlax-curve-getDistAtPoint
            (list e pJ)
          )
        )
        (setq dTan
          (vl-catch-all-apply
            'vlax-curve-getDistAtPoint
            (list e pTan)
          )
        )

        (if (or (vl-catch-all-error-p total)
                (vl-catch-all-error-p dJ)
                (vl-catch-all-error-p dTan)
                (<= total 1e-10))
          nil
          (progn
            ;; pJoint e um extremo do tramo; o outro extremo e o que fica.
            (setq dOuter (if (<= dJ (/ total 2.0)) total 0.0))
            (setq eType (cdr (assoc 0 (entget e))))
            (setq markers nil)

            ;; Los parametros enteros de una LWPOLYLINE corresponden a sus
            ;; vertices. Se incorporan todos los que quedan dentro del tramo.
            (if (= eType "LWPOLYLINE")
              (progn
                (setq i 0)
                (repeat (1+ (fix endPar))
                  (setq pVertex
                    (vl-catch-all-apply
                      'vlax-curve-getPointAtParam
                      (list e i)
                    )
                  )
                  (if (not (vl-catch-all-error-p pVertex))
                    (progn
                      (setq dVertex
                        (vl-catch-all-apply
                          'vlax-curve-getDistAtPoint
                          (list e pVertex)
                        )
                      )
                      (if (and (not (vl-catch-all-error-p dVertex))
                               (> dVertex (min dTan dOuter))
                               (< dVertex (max dTan dOuter)))
                        (setq markers (append markers (list dVertex)))
                      )
                    )
                  )
                  (setq i (1+ i))
                )
              )
            )

            (if (< dTan dOuter)
              (setq ordered (append (list dTan) markers (list dOuter)))
              (setq ordered (append (list dTan) (reverse markers) (list dOuter)))
            )

            (setq d0 (car ordered))
            (setq pts (list pTan))
            (foreach d1 (cdr ordered)
              ;; La polilinea fuente conserva sus vertices. La distancia de
              ;; segmentacion se aplica solo al arco nuevo de concordancia.
              (setq n
                (if (= eType "LWPOLYLINE")
                  1
                  (max 1 (bf_ceil (/ (abs (- d1 d0)) distMax)))
                )
              )
              (setq step (/ (- d1 d0) n))
              (setq j 1)
              (repeat n
                (setq d (+ d0 (* j step)))
                (setq p
                  (vl-catch-all-apply
                    'vlax-curve-getPointAtDist
                    (list e d)
                  )
                )
                (if (not (vl-catch-all-error-p p))
                  (setq pts (append pts (list (bf_pt3 p))))
                )
                (setq j (1+ j))
              )
              (setq d0 d1)
            )
            (if (>= (length pts) 2) pts nil)
          )
        )
      )
    )
  )

  (defun bf_cross2 (a b)
    (- (* (car a) (cadr b)) (* (cadr a) (car b)))
  )

  (defun bf_path_segments (pts / p0 p1 len distOut data)
    ;; Cada segmento: ponto inicial, ponto final, distancia acumulada e comprimento.
    (setq distOut 0.0)
    (setq data nil)
    (while (and pts (cdr pts))
      (setq p0 (car pts))
      (setq p1 (cadr pts))
      (setq len (distance p0 p1))
      (if (> len 1e-9)
        (progn
          (setq data (append data (list (list p0 p1 distOut len))))
          (setq distOut (+ distOut len))
        )
      )
      (setq pts (cdr pts))
    )
    data
  )

  (defun bf_limit_path (pts maxLen / out last p used d stop)
    ;; Limita a busca ao entorno da intersecao para evitar combinar tramos distantes.
    (if (not pts)
      nil
      (progn
        (setq out (list (car pts)))
        (setq last (car pts))
        (setq used 0.0)
        (setq stop nil)
        (foreach p (cdr pts)
          (if (not stop)
            (progn
              (setq d (distance last p))
              (if (<= (+ used d) maxLen)
                (progn
                  (setq out (append out (list p)))
                  (setq used (+ used d))
                  (setq last p)
                )
                (setq stop T)
              )
            )
          )
        )
        out
      )
    )
  )

  (defun bf_limit_path_radius (pts center rad / out last p dLast dP v q a b c disc t1 t2 tParam hit stop)
    ;; Mantem todos os vertices consecutivos dentro da janela circular de giro.
    ;; Ao sair do raio, inclui o ponto exato de cruzamento e encerra a busca.
    (if (or (not pts) (not center) (not rad) (<= rad 0.0))
      nil
      (progn
        (setq out  (list (car pts)))
        (setq last (car pts))
        (setq stop nil)
        (foreach p (cdr pts)
          (if (not stop)
            (progn
              (setq dLast (distance last center))
              (setq dP    (distance p center))
              (if (<= dP (+ rad 1e-9))
                (progn
                  (setq out (append out (list p)))
                  (setq last p)
                )
                (if (<= dLast (+ rad 1e-9))
                  (progn
                    ;; Segmento sai da janela: resolve a intersecao com o circulo.
                    (setq v (bf_v- p last))
                    (setq q (bf_v- last center))
                    (setq a (bf_dot v v))
                    (setq b (* 2.0 (bf_dot q v)))
                    (setq c (- (bf_dot q q) (* rad rad)))
                    (setq disc (- (* b b) (* 4.0 a c)))
                    (if (and (> a 1e-12) (>= disc 0.0))
                      (progn
                        (setq t1 (/ (+ (- b) (sqrt disc)) (* 2.0 a)))
                        (setq t2 (/ (- (- b) (sqrt disc)) (* 2.0 a)))
                        (setq tParam
                          (if (and (>= t1 0.0) (<= t1 1.0))
                            t1
                            (if (and (>= t2 0.0) (<= t2 1.0)) t2 nil)
                          )
                        )
                        (if tParam
                          (progn
                            (setq hit (bf_v+ last (bf_v* tParam v)))
                            (if (> (distance hit last) 1e-9)
                              (setq out (append out (list hit)))
                            )
                          )
                        )
                      )
                    )
                    (setq stop T)
                  )
                  (setq stop T)
                )
              )
            )
          )
        )
        out
      )
    )
  )

  (defun bf_segment_intersection (a b c d / r s den q ratio u p)
    ;; Retorna o ponto de intersecao entre dois segmentos, ou nil.
    (setq r (bf_v- b a))
    (setq s (bf_v- d c))
    (setq den (bf_cross2 r s))
    (if (< (abs den) 1e-12)
      nil
      (progn
        (setq q (bf_v- c a))
        (setq ratio (/ (bf_cross2 q s) den))
        (setq u (/ (bf_cross2 q r) den))
        (if (and (>= ratio -1e-9) (<= ratio (+ 1.0 1e-9))
                 (>= u -1e-9) (<= u (+ 1.0 1e-9)))
          (bf_v+ a (bf_v* ratio r))
          nil
        )
      )
    )
  )

  (defun bf_near_point_p (a b tol)
    (and a b (<= (distance a b) tol))
  )

  (defun bf_arc_crosses_segments (arcPts obstacleSegs pStart pEnd tol / arcSegs as os hit crosses)
    ;; Rejeita qualquer arco que corte guia/cabeceira fora das duas tangencias.
    (setq arcSegs (bf_path_segments arcPts))
    (setq crosses nil)
    (foreach as arcSegs
      (foreach os obstacleSegs
        (setq hit
          (bf_segment_intersection
            (car as) (cadr as)
            (car os) (cadr os)
          )
        )
        (if (and hit
                 (not (bf_near_point_p hit pStart tol))
                 (not (bf_near_point_p hit pEnd tol)))
          (setq crosses T)
        )
      )
    )
    crosses
  )

  (defun bf_circle_candidates_on_segments (seg1 seg2 rad / p1 p2 q1 q2 u1 u2 n1 n2 den cands s1 s2 a b q t1 t2 cen pt1 pt2)
    ;; Centros de circulos de raio rad tangentes aos dois segmentos finitos.
    (setq p1 (car seg1))
    (setq p2 (cadr seg1))
    (setq q1 (car seg2))
    (setq q2 (cadr seg2))
    (setq u1 (bf_unit (bf_v- p2 p1)))
    (setq u2 (bf_unit (bf_v- q2 q1)))
    (setq den (if (and u1 u2) (bf_cross2 u1 u2) 0.0))
    (setq cands nil)

    (if (or (not u1) (not u2) (< (abs den) 1e-10))
      nil
      (progn
        (setq n1 (list (- (cadr u1)) (car u1) 0.0))
        (setq n2 (list (- (cadr u2)) (car u2) 0.0))
        (foreach s1 (list -1.0 1.0)
          (foreach s2 (list -1.0 1.0)
            (setq a (bf_v+ p1 (bf_v* (* s1 rad) n1)))
            (setq b (bf_v+ q1 (bf_v* (* s2 rad) n2)))
            (setq q (bf_v- b a))
            (setq t1 (/ (bf_cross2 q u2) den))
            (setq cen (bf_v+ a (bf_v* t1 u1)))
            (setq t1 (bf_dot (bf_v- cen p1) u1))
            (setq t2 (bf_dot (bf_v- cen q1) u2))

            (if (and (>= t1 -1e-7)
                     (<= t1 (+ (cadddr seg1) 1e-7))
                     (>= t2 -1e-7)
                     (<= t2 (+ (cadddr seg2) 1e-7)))
              (progn
                (setq pt1 (bf_v+ p1 (bf_v* t1 u1)))
                (setq pt2 (bf_v+ q1 (bf_v* t2 u2)))
                (setq cands (append cands (list (list pt1 pt2 cen))))
              )
            )
          )
        )
        cands
      )
    )
  )

  (defun bf_angle_between_points (pJoint p1 p2 / u1 u2 dotv)
    (setq u1 (bf_unit (bf_v- p1 pJoint)))
    (setq u2 (bf_unit (bf_v- p2 pJoint)))
    (if (and u1 u2)
      (progn
        (setq dotv (bf_dot u1 u2))
        (if (> dotv 0.999999) (setq dotv 0.999999))
        (if (< dotv -0.999999) (setq dotv -0.999999))
        (atan (sqrt (max 0.0 (- 1.0 (* dotv dotv)))) dotv)
      )
      nil
    )
  )

  (defun bf_fillet_solver (eGuide eCab eCabOther pJoint rad distMax
                           / step gPts cPts oPts gSegs cSegs oSegs allSegs
                                g0 c0 vG vC sg sc cand ptG ptC cen candPts score scoreMax
                                best bestScore bestMax theta dToGuide dToCab)
    ;; Solver para curvas reais: busca um circulo de raio fixo tangente a
    ;; segmentos validos da guia e da cabeceira e rejeita arcos que cruzem a geometria.
    (setq step (max 0.100 (min distMax 1.000)))
    (setq gPts (bf_curve_points_to_outer eGuide pJoint pJoint step))
    (setq cPts (bf_curve_points_to_outer eCab pJoint pJoint step))
    (setq oPts
      (if (and eCabOther (entget eCabOther))
        (bf_curve_points_to_outer eCabOther pJoint pJoint step)
        nil
      )
    )

    (if (not (and gPts cPts))
      nil
      (progn
        (setq gPts (bf_limit_path_radius gPts pJoint rad))
        (setq cPts (bf_limit_path_radius cPts pJoint rad))
        (setq oPts (bf_limit_path_radius oPts pJoint rad))
        (setq gSegs (bf_path_segments gPts))
        (setq cSegs (bf_path_segments cPts))
        (setq oSegs (bf_path_segments oPts))
        (setq allSegs (append gSegs cSegs oSegs))
        (setq g0 (car gSegs))
        (setq c0 (car cSegs))
        (setq vG (if g0 (bf_unit (bf_v- (cadr g0) (car g0))) nil))
        (setq vC (if c0 (bf_unit (bf_v- (cadr c0) (car c0))) nil))
        (setq best nil)
        (setq bestScore nil)
        (setq bestMax nil)

        (if (not (and gSegs cSegs vG vC))
          nil
          (progn
            ;; A busca percorre os segmentos reais que seguem a intersecao.
            ;; Isso suporta curvas aproximadas por vertices curtos sem aceitar
            ;; uma solucao distante ou desequilibrada entre os dois bracos.
            (foreach sg gSegs
              (foreach sc cSegs
                (foreach cand (bf_circle_candidates_on_segments sg sc rad)
                  (setq ptG (car cand))
                  (setq ptC (cadr cand))
                  (setq cen (caddr cand))
                  (setq dToGuide (+ (caddr sg) (distance (car sg) ptG)))
                  (setq dToCab   (+ (caddr sc) (distance (car sc) ptC)))
                  (setq scoreMax (max dToGuide dToCab))
                  (setq score (+ dToGuide dToCab))

                  ;; O centro deve ficar no angulo interno dos dois bracos iniciais.
                  (if (and
                        (or (not bestMax)
                            (< scoreMax bestMax)
                            (and (equal scoreMax bestMax 1e-9)
                                 (< score bestScore)))
                        (> (bf_dot (bf_v- cen pJoint) vG) 1e-8)
                        (> (bf_dot (bf_v- cen pJoint) vC) 1e-8))
                    (progn
                      (setq candPts (bf_arc_points_center cen rad ptG ptC distMax))
                      (if (and candPts
                               (not (bf_arc_crosses_segments candPts allSegs ptG ptC 0.001)))
                        (progn
                          (setq theta (bf_angle_between_points pJoint ptG ptC))
                          (if theta
                            (progn
                              (setq best (list ptG ptC cen dToGuide theta candPts))
                              (setq bestMax scoreMax)
                              (setq bestScore score)
                            )
                          )
                        )
                      )
                    )
                  )
                )
              )
            )
            best
          )
        )
      )
    )
  )

  (defun bf_endpoint_distance_to (e p / pStart pEnd)
    ;; Distancia do ponto ao extremo mais proximo da curva.
    (setq pStart (bf_pt3 (vlax-curve-getStartPoint e)))
    (setq pEnd   (bf_pt3 (vlax-curve-getEndPoint e)))
    (if (and pStart pEnd p)
      (min (distance p pStart) (distance p pEnd))
      1e99
    )
  )

  (defun bf_join_two (eBase eAdd / oldCmd oldPedit res ok fuzz)
    ;; Une tramos nas tangencias sem reconstruir a polilinha. Primeiro usa JOIN
    ;; exato e, para microdiferencas criadas pelo BREAKATPOINT, tenta PEDIT JOIN
    ;; com tolerancia de 1 mm. Nenhuma das alternativas altera os bulges.
    (if (and eBase eAdd (entget eBase) (entget eAdd))
      (progn
        (setq oldCmd (getvar "CMDECHO"))
        (setq oldPedit
          (vl-catch-all-apply 'getvar (list "PEDITACCEPT"))
        )
        (setq fuzz 0.001)
        (setvar "CMDECHO" 0)
        (if (not (vl-catch-all-error-p oldPedit))
          (setvar "PEDITACCEPT" 1)
        )
        (setq res
          (vl-catch-all-apply
            'vl-cmdf
            (list "_.JOIN" eBase eAdd "")
          )
        )

        (setq ok
          (and
            (not (vl-catch-all-error-p res))
            (entget eBase)
            (not (entget eAdd))
          )
        )

        (if (not ok)
          (progn
            (setq res
              (vl-catch-all-apply
                'vl-cmdf
                (list "_.PEDIT" eBase "_J" eAdd "" fuzz "")
              )
            )
            (setq ok
              (and
                (not (vl-catch-all-error-p res))
                (entget eBase)
                (not (entget eAdd))
              )
            )
          )
        )

        (setvar "CMDECHO" oldCmd)
        (if (not (vl-catch-all-error-p oldPedit))
          (setvar "PEDITACCEPT" oldPedit)
        )
        ok
      )
      nil
    )
  )

  (defun bf_trim_endpoint (e pJoint pTangent / before after e2 d1 d2 eKeep eOther)
    ;; Replica BOTA2: BREAKATPOINT cria um extremo real em pTangent.
    ;; Depois conserva somente o tramo afastado de pJoint, pronto para JOIN.
    (if (and e pJoint pTangent (entget e))
      (if (< (bf_endpoint_distance_to e pTangent) 1e-6)
        e
        (progn
          (setq before (entlast))
          (if (bf_breakatpoint e pTangent)
            (progn
              (setq after (bf_next_created before))
              (if (and after (/= after before))
                (progn
                  (setq e2 after)
                  (setq d1 (bf_endpoint_distance_to e pJoint))
                  (setq d2 (bf_endpoint_distance_to e2 pJoint))
                  (if (>= d1 d2)
                    (progn (setq eKeep e)  (setq eOther e2))
                    (progn (setq eKeep e2) (setq eOther e))
                  )
                  (if eOther (entdel eOther))
                  eKeep
                )
                nil
              )
            )
            nil
          )
        )
      )
      nil
    )
  )

  (defun bf_break_keep_side (e pJoint pPick / pStart pEnd before after e2 eKeep eOther)
    ;; Parte uma curva somente quando a intersecao esta no seu interior e
    ;; devolve (tramo-escolhido outro-tramo). O outro pode ser mantido ou apagado.
    (setq pStart (bf_pt3 (vlax-curve-getStartPoint e)))
    (setq pEnd   (bf_pt3 (vlax-curve-getEndPoint e)))
    (if (not (and pStart pEnd pJoint))
      nil
      (if (or (< (distance pJoint pStart) 1e-6)
              (< (distance pJoint pEnd) 1e-6))
        (list e nil)
        (progn
          (setq before (entlast))
          (if (bf_breakatpoint e pJoint)
            (progn
              (setq after (bf_next_created before))
              (if (and after (/= after before))
                (progn
                  (setq e2 after)
                  (setq eKeep (bf_select_side_segment e e2 pJoint pPick))
                  (setq eOther (if (= eKeep e) e2 e))
                  (if eKeep (list eKeep eOther) nil)
                )
                nil
              )
            )
            nil
          )
        )
      )
    )
  )

  (defun bf_lwpoly_open_like (pts source / ed layer color ltype elev data)
    (setq ed    (entget source))
    (setq layer (cdr (assoc 8 ed)))
    (setq color (assoc 62 ed))
    (setq ltype (assoc 6 ed))
    (setq elev
      (if (and pts (numberp (caddr (car pts))))
        (caddr (car pts))
        0.0
      )
    )

    (setq data
      (append
        (list
          (cons 0 "LWPOLYLINE")
          (cons 100 "AcDbEntity")
          (cons 8 (if layer layer (getvar "CLAYER")))
        )
        (if color (list color) nil)
        (if ltype (list ltype) nil)
        (list
          (cons 100 "AcDbPolyline")
          (cons 90 (length pts))
          (cons 70 0)
          (cons 38 elev)
        )
        (apply 'append
          (mapcar
            '(lambda (p)
              (list
                (cons 10 (bf_pt2 p))
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

  (defun bf_curve_segment_points (e pFrom distMax / pS pE endPar total n stepD i pts d p q)
    ;; Segmenta qualquer curva retornada pelo FILLET em cordas retas.
    ;; A lista e ordenada pelo extremo mais proximo de pFrom.
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
        (setq pS (bf_pt3 pS))
        (setq pE (bf_pt3 pE))
        (setq pFrom (bf_pt3 pFrom))
        (if (not pFrom)
          (setq pFrom pS)
        )

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

            (if (or (not pS)
                    (not pE)
                    (not pFrom)
                    (not distMax)
                    (vl-catch-all-error-p total)
                    (<= total 1e-10)
                    (<= distMax 1e-10))
              nil
              (progn
                (setq n (max 1 (bf_ceil (/ total distMax))))
                (setq stepD (/ total n))
                (setq pts nil)
                (setq i 0)

                (if (<= (distance pFrom pS) (distance pFrom pE))
                  (progn
                    (repeat (1+ n)
                      (setq d (* i stepD))
                      (if (> d total) (setq d total))
                      (setq p
                        (vl-catch-all-apply
                          'vlax-curve-getPointAtDist
                          (list e d)
                        )
                      )
                      (if (not (vl-catch-all-error-p p))
                        (progn
                          (setq q (bf_pt3 p))
                          (if q
                            (setq pts (append pts (list q)))
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
                      (setq p
                        (vl-catch-all-apply
                          'vlax-curve-getPointAtDist
                          (list e d)
                        )
                      )
                      (if (not (vl-catch-all-error-p p))
                        (progn
                          (setq q (bf_pt3 p))
                          (if q
                            (setq pts (append pts (list q)))
                          )
                        )
                      )
                      (setq i (1+ i))
                    )
                  )
                )

                (if (>= (length pts) 2)
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

  (defun bf_segment_fillet_entity (e pFrom distMax / pts eNew)
    (setq pts (bf_curve_segment_points e pFrom distMax))
    (if pts
      (progn
        (setq eNew (bf_lwpoly_open_like pts e))
        (if eNew
          (progn
            (entdel e)
            eNew
          )
          nil
        )
      )
      nil
    )
  )

  (defun bf_next_created (before / e last)
    (setq e
      (if before
        (entnext before)
        (entnext)
      )
    )
    (while e
      (setq last e)
      (setq e (entnext e))
    )
    last
  )

  (defun bf_fillet_direct (e1 p1 e2 p2 rad / oldRad oldTrim oldCmd before after res afterData afterType)
    ;; Executa o FILLET como no video: linha primeiro, cabeceira depois, com recorte ativo.
    (setq p1 (bf_pt3 p1))
    (setq p2 (bf_pt3 p2))

    (if (not (and e1 e2 p1 p2 rad (> rad 0.0)))
      (progn
        (prompt "\nDados insuficientes para executar o FILLET.")
        nil
      )
      (progn
        (setq oldRad  (getvar "FILLETRAD"))
        (setq oldTrim (getvar "TRIMMODE"))
        (setq oldCmd  (getvar "CMDECHO"))

        (setvar "FILLETRAD" rad)
        (setvar "TRIMMODE" 1)
        (setvar "CMDECHO" 0)

        (setq before (entlast))
        (initcommandversion 1)

        (setq res
          (vl-catch-all-apply
            'vl-cmdf
            (list
              "_.FILLET"
              "_R"
              rad
              (list e1 p1)
              (list e2 p2)
            )
          )
        )

        (setq after (bf_next_created before))
        (if (not after)
          (setq after (entlast))
        )

        (setvar "FILLETRAD" oldRad)
        (setvar "TRIMMODE" oldTrim)
        (setvar "CMDECHO" oldCmd)

        (if (vl-catch-all-error-p res)
          (progn
            (prompt
              (strcat
                "\nNao foi possivel executar o FILLET: "
                (vl-catch-all-error-message res)
              )
            )
            nil
          )
          (if (or (not after) (= after before) (not (setq afterData (entget after))))
            (progn
              (prompt "\nO FILLET foi chamado, mas AutoCAD nao retornou uma entidade nova. Pode ter modificado a propria polilinha.")
              nil
            )
            (if (not
                  (member
                    (setq afterType (cdr (assoc 0 afterData)))
                    (list "ARC" "LWPOLYLINE" "POLYLINE")
                  )
                )
              (progn
                (prompt
                  (strcat
                    "\nAutoCAD criou uma entidade do tipo "
                    (if afterType afterType "desconhecido")
                    ", que nao pode ser segmentada por este comando."
                  )
                )
                nil
              )
              after
            )
          )
        )
      )
    )
  )

  (if (not *BOTAF_FILLET_R*)   (setq *BOTAF_FILLET_R* 10.000))
  (if (not *BOTAF_FILLET_SEG*) (setq *BOTAF_FILLET_SEG* 1.500))

  (setq oldLuprec (getvar "LUPREC"))
  (setvar "LUPREC" 3)

  (prompt "\nBOTAF - Fillet automatico entre cabeceira e linha, convertido em segmentos.")

  (setq selCab (entsel "\nSelecione a cabeceira perto da zona desejada: "))

  (if (not selCab)
    (prompt "\nNenhuma cabeceira selecionada.")
    (progn
      (setq entCab   (car selCab))
      (setq pPickCab (bf_pt3 (cadr selCab)))

      (if (not (bf_curve_valid_p entCab pPickCab))
        (prompt "\nA entidade selecionada como cabeceira nao e uma curva valida.")
        (progn
          (setq selLinha (entsel "\nSelecione a linha: "))

          (if (not selLinha)
            (prompt "\nNenhuma linha selecionada.")
            (progn
              (setq entLinha   (car selLinha))
              (setq pPickLinha (bf_pt3 (cadr selLinha)))

              (if (not (bf_curve_valid_p entLinha pPickLinha))
                (prompt "\nA entidade selecionada como linha nao e uma curva valida.")
                (progn
                  ;; BOTAF nao cria offsets: o primeiro clique na cabeceira
                  ;; define diretamente qual tramo recebera a concordancia.
                  (setq pSide pPickCab)

                  (if (not pSide)
                    (prompt "\nNao foi possivel definir o lado a partir dos cliques na cabeceira e na guia.")
                    (progn
                      (prompt "\nTramo da cabeceira definido pelo clique na cabeceira.")

                      (setq pBreak
                        (bf_best_point
                          (bf_intersections entCab entLinha)
                          pPickCab
                        )
                      )

                      (if pBreak
                        (prompt "\nIntersecao cabecera/linha encontrada para o BREAK.")
                        (prompt "\nAviso: nao foi encontrada intersecao real; usando o ponto selecionado na cabeceira.")
                      )

                      (setq pCabSel
                        (if pBreak
                          pBreak
                          (bf_closest_point entCab pPickCab)
                        )
                      )
                      (if (not pCabSel)
                        (setq pCabSel pPickCab)
                      )

                      ;; O ponto usado para selecionar a linha define o seu braco.
                      ;; Antes era usado pSide aqui, e isso podia escolher o braco oposto.
                      (setq pLinhaSel (bf_closest_point entLinha pPickLinha))
                      (if (not pLinhaSel)
                        (setq pLinhaSel pPickLinha)
                      )

                      (initget "R")
                      (setq cfg
                        (getkword
                          (strcat
                            "\nParametros atuais:"
                            " Concordancia R=" (rtos *BOTAF_FILLET_R* 2 3)
                            " | Dist.Max.Vert.=" (rtos *BOTAF_FILLET_SEG* 2 3)
                            "\nPressione Enter para modo automatico ou [R] manual: "
                          )
                        )
                      )

                      (setq manualMode (= cfg "R"))
                      (setq modeError nil)

                      (if manualMode
                        (progn
                          (setq filletR
                            (getdist
                              (strcat
                                "\nRaio da concordancia <"
                                (rtos *BOTAF_FILLET_R* 2 3)
                                ">: "
                              )
                            )
                          )
                          (if (not filletR)
                            (setq filletR *BOTAF_FILLET_R*)
                          )
                          (setq filletDistSeg
                            (getdist
                              (strcat
                                "\nDistancia Max. Vertices <"
                                (rtos *BOTAF_FILLET_SEG* 2 3)
                                ">: "
                              )
                            )
                          )
                          (if (not filletDistSeg)
                            (setq filletDistSeg *BOTAF_FILLET_SEG*)
                          )
                          (if (> filletR 0.0)
                            (setq *BOTAF_FILLET_R* filletR)
                          )
                          (if (> filletDistSeg 0.0)
                            (setq *BOTAF_FILLET_SEG* filletDistSeg)
                          )
                          (prompt
                            (strcat
                              "\nModo manual: raio R="
                              (rtos filletR 2 3)
                              " | Dist.Vert.="
                              (rtos filletDistSeg 2 3)
                              "."
                            )
                          )
                        )
                        (progn
                          ;; Antes do BREAK, usa os bracos escolhidos pelo usuario para
                          ;; encontrar a faixa de raio correspondente ao angulo interno.
                          (setq autoAngle
                            (bf_angle_between_vectors
                              (bf_dir_to_pick entCab pCabSel pSide)
                              (bf_dir_to_pick entLinha pCabSel pLinhaSel)
                            )
                          )
                          (if autoAngle
                            (progn
                              (setq autoAngleDeg (/ (* autoAngle 180.0) pi))
                              (setq autoRange
                                (bf_auto_range_for_angle
                                  autoAngleDeg
                                  *BOTAF_AUTO_RANGES*
                                )
                              )
                              (if autoRange
                                (progn
                                  (setq filletR (caddr autoRange))
                                  (setq filletDistSeg (nth 3 autoRange))
                                  (prompt
                                    (strcat
                                      "\nModo automatico: angulo="
                                      (rtos autoAngleDeg 2 3)
                                      " graus | faixa="
                                      (rtos (car autoRange) 2 3)
                                      "-"
                                      (rtos (cadr autoRange) 2 3)
                                      " | raio R="
                                      (rtos filletR 2 3)
                                      " | Dist.Vert.="
                                      (rtos filletDistSeg 2 3)
                                      "."
                                    )
                                  )
                                )
                                (setq modeError
                                  (strcat
                                    "\nO angulo detectado ("
                                    (rtos autoAngleDeg 2 3)
                                    " graus) nao pertence a nenhuma faixa configurada."
                                  )
                                )
                              )
                            )
                            (setq modeError
                              "\nNao foi possivel determinar o angulo entre os bracos selecionados."
                            )
                          )
                        )
                      )

                      (if (or (not filletR)
                              (not filletDistSeg)
                              (not (bf_pt3 pCabSel))
                              (not (bf_pt3 pLinhaSel))
                              (<= filletR 0.0)
                              (<= filletDistSeg 0.0))
                        (prompt
                          (if modeError
                            modeError
                            "\nDados invalidos. Revise os pontos selecionados, o raio e a distancia de segmentacao do fillet."
                          )
                        )
                        (progn
                          ;; Fluxo independente de FILLET: parte os dois objetos na intersecao,
                          ;; conserva os bracos indicados e cria a concordancia segmentada.
                          (setq cabParts (bf_break_keep_side entCab pCabSel pSide))

                          (if (not cabParts)
                            (prompt "\nNao foi possivel partir a cabeceira na intersecao.")
                            (progn
                              (setq entCabFillet (car cabParts))
                              (setq entCabOther  (cadr cabParts))
                              (prompt "\nBREAK da cabeceira: OK.")

                              (setq guideParts (bf_break_keep_side entLinha pCabSel pLinhaSel))
                              (if (not guideParts)
                                (prompt "\nNao foi possivel partir a linha na intersecao.")
                                (progn
                                  (setq entGuideFillet (car guideParts))
                                  (setq entGuideOther  (cadr guideParts))
                                  (setq geom
                                    (bf_fillet_solver
                                      entGuideFillet
                                      entCabFillet
                                      entCabOther
                                      pCabSel
                                      filletR
                                      filletDistSeg
                                    )
                                  )

                                  (if (not geom)
                                    (prompt "\nNao foi encontrada uma concordancia tangente sem cruzar a cabeceira. Reduza o raio ou escolha outro lado.")
                                    (progn
                                      (setq pTanGuide (car geom))
                                      (setq pTanCab   (cadr geom))
                                      (setq pCenter   (caddr geom))
                                      (setq angleInternal (nth 4 geom))
                                      (setq pts (nth 5 geom))
                                      (prompt
                                        (strcat
                                          "\nAngulo interno entre guia e cabeceira: "
                                          (rtos (/ (* angleInternal 180.0) pi) 2 3)
                                          " graus."
                                        )
                                      )
                                      ;; Os pontos vieram de segmentos reais; a projecao final
                                      ;; apenas corrige diferencas numericas de amostragem.
                                      (setq pRealTanGuide (bf_closest_point entGuideFillet pTanGuide))
                                      (setq pRealTanCab   (bf_closest_point entCabFillet pTanCab))

                                      (if (and pRealTanGuide pRealTanCab)
                                        (progn
                                          (setq arcZ (caddr pRealTanGuide))
                                          (setq pts
                                            (bf_set_curve_ends
                                              (bf_set_points_z
                                                pts
                                                arcZ
                                              )
                                              pRealTanGuide
                                              pRealTanCab
                                            )
                                          )
                                        )
                                      )

                                      (if (not pts)
                                        (prompt "\nNao foi possivel gerar os pontos do arco da concordancia.")
                                        (progn
                                          ;; Mantem os tramos originais. Reconstruir guia e
                                          ;; cabeceira por uma lista de pontos elimina os bulges
                                          ;; e transforma arcos que nao participam do fillet em
                                          ;; cordas. Apenas o arco novo e segmentado.
                                          (setq entSegmentado
                                            (bf_lwpoly_open_like pts entCabFillet)
                                          )

                                          (if (not entSegmentado)
                                            (prompt "\nNao foi possivel criar o arco segmentado da concordancia.")
                                            (progn
                                              ;; BREAK nas duas tangencias: preserva o trecho
                                              ;; externo nativo de cada polilinha, inclusive arcos.
                                              (setq trimGuide
                                                (bf_trim_endpoint
                                                  entGuideFillet pCabSel pRealTanGuide
                                                )
                                              )
                                              (setq trimCab
                                                (bf_trim_endpoint
                                                  entCabFillet pCabSel pRealTanCab
                                                )
                                              )

                                              (if (not (and trimGuide trimCab))
                                                (prompt "\nNao foi possivel recortar os tramos nas tangencias da concordancia.")
                                                (progn
                                                  ;; A ordem preserva guia exterior -> arco novo ->
                                                  ;; cabeceira exterior. JOIN mantem os bulges dos
                                                  ;; tramos de origem; somente o arco novo possui
                                                  ;; vertices segmentados.
                                                  (setq joinGuideOk
                                                    (bf_join_two trimGuide entSegmentado)
                                                  )
                                                  (if (not joinGuideOk)
                                                    (prompt "\nNao foi possivel unir o arco segmentado a linha guia.")
                                                    (progn
                                                      (setq joinCabOk
                                                        (bf_join_two trimGuide trimCab)
                                                      )
                                                      (if (not joinCabOk)
                                                        (prompt "\nNao foi possivel unir o arco segmentado a cabeceira.")
                                                        (progn
                                                          ;; O outro braco da guia nao faz parte da
                                                          ;; concordancia. A outra parte da cabeceira
                                                          ;; permanece intacta no desenho.
                                                          (if (and entGuideOther (entget entGuideOther))
                                                            (entdel entGuideOther)
                                                          )
                                                          (prompt
                                                            (strcat
                                                              "\nConcordancia criada preservando os arcos originais."
                                                              " Raio=" (rtos filletR 2 3)
                                                              " | Dist.Max.=" (rtos filletDistSeg 2 3)
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

  (bf_restore)
  (princ)
)

;; ============================================================
;; CARGA INICIAL - MUESTRA AYUDA AL CARGAR EL LISP
;; ============================================================

(princ "\n---------------------------------------------")
(princ "\nFerramentas BOTA v5.0 carregadas corretamente.")
(princ "\nComandos: BOTA | BOTA2 | BOTA3 | BOTAF | BOTAC | BOTAH")
(princ "\n---------------------------------------------")

;; Abre a janela de ajuda automaticamente ao carregar
(_bota_show_help)

(princ)
