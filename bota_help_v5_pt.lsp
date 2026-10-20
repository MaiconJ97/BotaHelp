;; ============================================================
;; BOTA TOOLS - SUITE DE FERRAMENTAS DE MANOBRAS (Civil3D / AutoCAD)
;; Criador: Maicon Marcarini
;; Versao: 5.0
;; Comandos incluidos: BOTA / BOTA2 (B2) / BOTAM / BOTA3 / BOTAFILLET (BOTAF, BF) / BOTAC / BOTAH
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
(if (not *BOTA_TRANS_L*)    (setq *BOTA_TRANS_L* 5.000))
(if (not *BOTA_RECTO_K*)    (setq *BOTA_RECTO_K* 1.000))
(defun _bota3_init_densification ()
  ;; A marca preserva nil (desativado), inclusive ao recarregar o LSP.
  (if (not *BOTA3_DENSIFY_CONFIGURADO*)
    (setq *BOTA3_DENSIFY* T *BOTA3_DENSIFY_CONFIGURADO* T))
  (if (not *BOTA_TRANS_L*) (setq *BOTA_TRANS_L* 5.000))
  (if (not *BOTA3_DENSIFY_SEG*) (setq *BOTA3_DENSIFY_SEG* 1.000))
)
(_bota3_init_densification)
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
    (if (not (and (listp range)
                  (= (length range) 4)
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

(defun c:BOTA2DEBUGCLEAR ()
  (vl-load-com)
  (_bota2d_ensure_layer)
  (_bota2d_clear)
  (prompt "\nBOTA2DEBUG: objetos de diagnostico eliminados.")
  (princ)
)

(defun c:BOTA2DEBUG
    (/ *error* selCab selGuide eCab eGuide pCabPick pGuidePick pCab pGuide
       tamImpl seguridad data pOffsetPoint usedVirtual cabSelected guideSelected
       height pLegend legendRows offsetError offsetComError tangentError tangentData
       pCenterRaw pCenterCorrected pTangentDebug tanErr outerErr rGiro rBarra pJoint
       b2Temps b2Outputs b2Original b2Committed
       offCab offGuia offCentro tmpExtCircle guiaLocal cabLocal)
  (_bota_session_pull)
  (vl-load-com)
  (_bota2_define_helpers)

  (defun *error* (msg)
    (b2_clear_temporaries)
    (_bota2d_clear)
    (if (and msg (/= msg "Function cancelled") (/= msg "quit / exit abort"))
      (prompt (strcat "\nErro em BOTA2DEBUG: " msg))
    )
    (princ)
  )

  (setq tamImpl *BOTA_IMPL* seguridad *BOTA_SEGURIDAD*)
  (setq height (max 0.250 (min 2.500 (/ tamImpl 10.0))))
  (_bota2d_ensure_layer)
  (_bota2d_clear)
  (prompt "\nBOTA2DEBUG - clics, offsets e intersecao usados por BOTA2.")
  (setq selCab (entsel "\nSelecione a cabeceira no mesmo ponto usado em BOTA2: "))
  (if selCab
    (progn
      (setq eCab (car selCab) pCabPick (b2_pt3 (cadr selCab)))
      (setq pCab (b2_closest_point eCab pCabPick))
      (if pCab
        (progn
          (setq selGuide (entsel "\nSelecione a linha guia no mesmo ponto usado em BOTA2: "))
          (if selGuide
            (progn
              (setq eGuide (car selGuide) pGuidePick (b2_pt3 (cadr selGuide)))
              (setq pGuide (b2_closest_point eGuide pGuidePick))
              (if (and pGuide (> tamImpl 0.0) (>= seguridad 0.0))
                (progn
                  (setq data
                    (b2_prepare_offsets eCab eGuide pCab pGuidePick tamImpl seguridad))
                  (setq cabSelected (car data) guideSelected (cadr data))
                  (setq pOffsetPoint (caddr data) usedVirtual (cadddr data))
                  (setq cabLocal (nth 4 data))
                  (setq pJoint (nth 5 data))
                  (setq rGiro *BOTA_RGIRO*)
                  (setq rBarra (+ rGiro (/ tamImpl 2.0)))
                  (if (and cabSelected pOffsetPoint)
                    (progn
                      (setq offCentro
                        (b2_offset_select_toward
                          (if cabLocal cabLocal eCab) rGiro pGuidePick
                        )
                      )
                      (setq tmpExtCircle (b2_circle_entity pOffsetPoint rBarra nil))
                      (setq tangentData
                        (if (and offCentro tmpExtCircle)
                          (b2_tangent_solution
                            (if cabLocal cabLocal eCab)
                            offCentro tmpExtCircle pOffsetPoint rGiro rBarra pJoint
                          )
                          nil
                        )
                      )
                      (if tangentData
                        (progn
                          (setq pCenterCorrected (car tangentData))
                          (setq pTangentDebug (cadr tangentData))
                          (setq pCenterRaw (caddr tangentData))
                          (setq tanErr (nth 3 tangentData))
                          (setq outerErr (nth 4 tangentData))
                        )
                      )
                    )
                  )
                  (if cabSelected (_bota2d_style_entity cabSelected 3))
                  (if guideSelected (_bota2d_style_entity guideSelected 4))
                  (_bota2d_mark pCabPick nil 2 height)
                  (_bota2d_mark pGuidePick nil 30 height)
                  (setq legendRows
                    (list (list "CLIC CABECEIRA" 2) (list "CLIC GUIA" 30)))
                  (if pOffsetPoint
                    (progn
                      (_bota2d_mark pOffsetPoint nil 5 height)
                      (setq legendRows
                        (append legendRows
                          (list (list
                            (if usedVirtual "INTERSECAO VIRTUAL (ATE 1 m)"
                              "INTERSECAO REAL DOS OFFSETS") 5))))
                    )
                  )
                  (if pCenterRaw
                    (progn
                      (_bota2d_mark pCenterRaw nil 1 height)
                      (setq legendRows
                        (append legendRows (list (list "CENTRO CANDIDATO" 1)))
                      )
                    )
                  )
                  (if pCenterCorrected
                    (progn
                      (_bota2d_mark pCenterCorrected nil 6 height)
                      (_bota2d_mark pTangentDebug nil 140 height)
                      (setq legendRows
                        (append legendRows
                          (list
                            (list "CENTRO CORRIGIDO" 6)
                            (list
                              (strcat
                                "TANGENCIA | Erro int.=" (rtos tanErr 2 3)
                                " | Erro ext.=" (rtos outerErr 2 3)
                              )
                              140
                            )
                          )
                        )
                      )
                    )
                  )
                  (if cabSelected
                    (setq legendRows (append legendRows
                      (list (list "OFFSET CABECEIRA SELECIONADO" 3))))
                  )
                  (if guideSelected
                    (setq legendRows (append legendRows
                      (list (list "OFFSET GUIA SELECIONADO" 4))))
                  )
                  (setq pLegend
                    (_bota2d_default_legend_point pCabPick pGuidePick
                      (if pOffsetPoint pOffsetPoint pCabPick) height))
                  (_bota2d_draw_legend pLegend legendRows height)
                  (setq b2Outputs (list cabSelected guideSelected) b2Committed T)
                  (b2_clear_temporaries)
                  (if offsetError (prompt (strcat "\n" offsetError)))
                  (if tangentError (prompt (strcat "\n" tangentError)))
                  (prompt "\nUse BOTA2DEBUGCLEAR para apagar somente este diagnostico.")
                )
                (prompt "\nGuia ou parametros invalidos.")
              )
            )
            (prompt "\nNenhuma linha guia selecionada.")
          )
        )
        (prompt "\nA cabeceira selecionada nao e uma curva valida.")
      )
    )
    (prompt "\nNenhuma cabeceira selecionada.")
  )
  (b2_clear_temporaries)
  (princ)
)

;; ============================================================
;; COMANDO BOTAC - JANELA DCL DE CONFIGURACAO DE PARAMETROS
;; Criador: Maicon Marcarini
;; ============================================================

(defun _bota_cfg_default_file (/ folder)
  (setq folder (getvar "DWGPREFIX"))
  (if (or (not folder) (= folder ""))
    (setq folder (getvar "TEMPPREFIX"))
  )
  (strcat folder "BotaHelp_config.txt")
)

(defun _bota_cfg_number (text / value)
  ;; A conversao e deliberadamente numerica: o arquivo nunca e avaliado como Lisp.
  (if (and text (= (type text) 'STR))
    (progn
      (setq value
        (distof
          (vl-string-translate "," "." (vl-string-trim " \t" text))
          2
        )
      )
      (if (numberp value) (float value) nil)
    )
    nil
  )
)

(defun _bota_cfg_split (text separator / pos out)
  (setq out nil)
  (while (setq pos (vl-string-search separator text))
    (setq out (append out (list (substr text 1 pos))))
    (setq text (substr text (+ pos 2)))
  )
  (append out (list text))
)

(defun _bota_cfg_range_from_text (text / values)
  (if text
    (progn
      (setq values (_bota_cfg_split text ";"))
      (if (= (length values) 4)
        (mapcar '_bota_cfg_number values)
        nil
      )
    )
    nil
  )
)

(defun _bota_cfg_value (data key / pair)
  (setq pair (assoc key data))
  (if pair (cdr pair) nil)
)

(defun _bota_cfg_values_valid_p (values / rGiro tamImpl distSeg seguridad filletR filletSeg botafR botafSeg ranges joinCab cutCircle densify transLength transSeg)
  (if (and (listp values) (= (length values) 14))
    (progn
      (setq rGiro     (nth 0 values))
      (setq tamImpl   (nth 1 values))
      (setq distSeg   (nth 2 values))
      (setq seguridad (nth 3 values))
      (setq filletR   (nth 4 values))
      (setq filletSeg (nth 5 values))
      (setq botafR    (nth 6 values))
      (setq botafSeg  (nth 7 values))
      (setq ranges    (nth 8 values))
      (setq joinCab   (nth 9 values))
      (setq cutCircle (nth 10 values))
      (setq densify   (nth 11 values))
      (setq transLength (nth 12 values))
      (setq transSeg  (nth 13 values))
      (and (numberp rGiro) (> rGiro 0.0)
           (numberp tamImpl) (> tamImpl 0.0)
           (numberp distSeg) (> distSeg 0.0)
           (numberp seguridad) (>= seguridad 0.0)
           (numberp filletR) (> filletR 0.0)
           (numberp filletSeg) (> filletSeg 0.0)
           (numberp botafR) (> botafR 0.0)
           (numberp botafSeg) (> botafSeg 0.0)
           (_bota_botaf_ranges_valid_p ranges)
           (or (= joinCab 0.0) (= joinCab 1.0))
           (or (= cutCircle 0.0) (= cutCircle 1.0))
           (numberp densify) (or (= densify 0.0) (= densify 1.0))
           (numberp transLength) (>= transLength 0.0)
           (numberp transSeg) (> transSeg 0.0)
      )
    )
    nil
  )
)

(defun _bota_cfg_set_values (values)
  (setq *BOTA_RGIRO*      (nth 0 values))
  (setq *BOTA_IMPL*       (nth 1 values))
  (setq *BOTA_DISTSEG*    (nth 2 values))
  (setq *BOTA_SEGURIDAD*  (nth 3 values))
  (setq *BOTA_FILLET_R*   (nth 4 values))
  (setq *BOTA_FILLET_SEG* (nth 5 values))
  (setq *BOTAF_FILLET_R*  (nth 6 values))
  (setq *BOTAF_FILLET_SEG* (nth 7 values))
  (setq *BOTAF_AUTO_RANGES* (nth 8 values))
  (setq *BOTA_CONECTAR_CAB* (/= (nth 9 values) 0.0))
  (setq *BOTA_CORTAR_CIRCULO* (/= (nth 10 values) 0.0))
  (setq *BOTA_CONECTAR_CAB_CONFIGURADO* T)
  (setq *BOTA_CORTAR_CIRCULO_CONFIGURADO* T)
  (setq *BOTA3_DENSIFY* (/= (nth 11 values) 0.0))
  (setq *BOTA_TRANS_L* (nth 12 values))
  (setq *BOTA3_DENSIFY_SEG* (nth 13 values))
  (setq *BOTA3_DENSIFY_CONFIGURADO* T)
)

(defun _bota_cfg_current_values ()
  (list *BOTA_RGIRO* *BOTA_IMPL* *BOTA_DISTSEG* *BOTA_SEGURIDAD*
        *BOTA_FILLET_R* *BOTA_FILLET_SEG* *BOTAF_FILLET_R* *BOTAF_FILLET_SEG*
        *BOTAF_AUTO_RANGES*
        (if *BOTA_CONECTAR_CAB* 1.0 0.0)
        (if *BOTA_CORTAR_CIRCULO* 1.0 0.0)
        (if *BOTA3_DENSIFY* 1.0 0.0)
        *BOTA_TRANS_L* *BOTA3_DENSIFY_SEG*)
)

(defun _bota_session_publish (/ values factor)
  ;; Um unico snapshot validado, comum aos desenhos desta instancia do AutoCAD.
  ;; Nao publica entidades, resultados derivados ou estado temporario de comandos.
  (setq values (_bota_cfg_current_values)
        factor (if (numberp *BOTA_RECTO_K*) *BOTA_RECTO_K* 1.0))
  (if (and (_bota_cfg_values_valid_p values) (>= factor 0.0))
    (progn
      (vl-bb-set 'BOTAHELP_SETTINGS_V1 (list values factor))
      T))
)

(defun _bota_session_pull (/ snapshot values factor)
  ;; Importar nunca publica: carregar outro desenho nao substitui a sessao.
  (setq snapshot (vl-bb-ref 'BOTAHELP_SETTINGS_V1))
  (if (and (listp snapshot) (= (length snapshot) 2))
    (progn
      (setq values (car snapshot) factor (cadr snapshot))
      (if (and (_bota_cfg_values_valid_p values)
               (numberp factor) (>= factor 0.0))
        (progn
          (_bota_cfg_set_values values)
          (setq *BOTA_RECTO_K* factor)
          T))))
)

(defun _bota_session_start ()
  ;; Somente a primeira carga fornece os valores iniciais da sessao.
  (if (not (_bota_session_pull)) (_bota_session_publish))
)

(defun _bota_cfg_apply_values (values)
  (if (_bota_cfg_values_valid_p values)
    (progn
      (_bota_cfg_set_values values)
      (_bota_session_publish)))
)

(defun _bota_cfg_write_pair (fn key value)
  (write-line (strcat key "=" value) fn)
)

(defun _bota_cfg_range_to_text (range)
  (strcat
    (rtos (car range) 2 6) ";"
    (rtos (cadr range) 2 6) ";"
    (rtos (caddr range) 2 6) ";"
    (rtos (nth 3 range) 2 6)
  )
)

(defun _bota_cfg_save_file (path / fn ranges i)
  (_bota3_init_densification)
  (setq fn (open path "w"))
  (if fn
    (progn
      (write-line "BOTA_CONFIG_V1" fn)
      (_bota_cfg_write_pair fn "RGIRO" (rtos *BOTA_RGIRO* 2 6))
      (_bota_cfg_write_pair fn "IMPL" (rtos *BOTA_IMPL* 2 6))
      (_bota_cfg_write_pair fn "DISTSEG" (rtos *BOTA_DISTSEG* 2 6))
      (_bota_cfg_write_pair fn "SEGURIDAD" (rtos *BOTA_SEGURIDAD* 2 6))
      (_bota_cfg_write_pair fn "FILLET_R" (rtos *BOTA_FILLET_R* 2 6))
      (_bota_cfg_write_pair fn "FILLET_SEG" (rtos *BOTA_FILLET_SEG* 2 6))
      (_bota_cfg_write_pair fn "BOTAF_R" (rtos *BOTAF_FILLET_R* 2 6))
      (_bota_cfg_write_pair fn "BOTAF_SEG" (rtos *BOTAF_FILLET_SEG* 2 6))
      (setq ranges *BOTAF_AUTO_RANGES*)
      (setq i 1)
      (foreach range ranges
        (_bota_cfg_write_pair
          fn
          (strcat "BOTAF_RANGE_" (itoa i))
          (_bota_cfg_range_to_text range)
        )
        (setq i (1+ i))
      )
      (_bota_cfg_write_pair fn "JOIN_CAB" (if *BOTA_CONECTAR_CAB* "1" "0"))
      (_bota_cfg_write_pair fn "CUT_CIRCLE" (if *BOTA_CORTAR_CIRCULO* "1" "0"))
      (_bota_cfg_write_pair fn "BOTA3_DENSIFY" (if *BOTA3_DENSIFY* "1" "0"))
      (_bota_cfg_write_pair fn "BOTA3_TRANS_L" (rtos *BOTA_TRANS_L* 2 6))
      (_bota_cfg_write_pair fn "BOTA3_DENSIFY_SEG" (rtos *BOTA3_DENSIFY_SEG* 2 6))
      (close fn)
      T
    )
    nil
  )
)

(defun _bota_cfg_optional_number (data key default / pair)
  ;; Ausente: perfil anterior. Presente e invalido: rejeitar o perfil.
  (setq pair (assoc key data))
  (if pair (_bota_cfg_number (cdr pair)) default)
)

(defun _bota_cfg_values_from_file (path / fn header line pos key value data ranges values)
  (setq fn (open path "r"))
  (if fn
    (progn
      (setq header (read-line fn))
      (if (= header "BOTA_CONFIG_V1")
        (progn
          (setq data nil)
          (while (setq line (read-line fn))
            (setq pos (vl-string-search "=" line))
            (if (and pos (> pos 0))
              (progn
                (setq key (strcase (vl-string-trim " \t" (substr line 1 pos))))
                (setq value (vl-string-trim " \t" (substr line (+ pos 2))))
                (setq data (cons (cons key value) data))
              )
            )
          )
          (close fn)
          (setq ranges
            (list
              (_bota_cfg_range_from_text (_bota_cfg_value data "BOTAF_RANGE_1"))
              (_bota_cfg_range_from_text (_bota_cfg_value data "BOTAF_RANGE_2"))
              (_bota_cfg_range_from_text (_bota_cfg_value data "BOTAF_RANGE_3"))
              (_bota_cfg_range_from_text (_bota_cfg_value data "BOTAF_RANGE_4"))
            )
          )
          (setq values
            (list
              (_bota_cfg_number (_bota_cfg_value data "RGIRO"))
              (_bota_cfg_number (_bota_cfg_value data "IMPL"))
              (_bota_cfg_number (_bota_cfg_value data "DISTSEG"))
              (_bota_cfg_number (_bota_cfg_value data "SEGURIDAD"))
              (_bota_cfg_number (_bota_cfg_value data "FILLET_R"))
              (_bota_cfg_number (_bota_cfg_value data "FILLET_SEG"))
              (_bota_cfg_number (_bota_cfg_value data "BOTAF_R"))
              (_bota_cfg_number (_bota_cfg_value data "BOTAF_SEG"))
              ranges
              (_bota_cfg_number (_bota_cfg_value data "JOIN_CAB"))
              (_bota_cfg_number (_bota_cfg_value data "CUT_CIRCLE"))
              (_bota_cfg_optional_number data "BOTA3_DENSIFY" 1.0)
              (_bota_cfg_optional_number data "BOTA3_TRANS_L" 5.0)
              (_bota_cfg_optional_number data "BOTA3_DENSIFY_SEG" 1.0)
            )
          )
          (if (_bota_cfg_values_valid_p values)
            values
            nil
          )
        )
        (progn
          (close fn)
          nil
        )
      )
    )
    nil
  )
)

(defun _bota_cfg_save_interactive (/ path)
  (setq path
    (getfiled
      "Salvar configuracao BOTA"
      (_bota_cfg_default_file)
      "txt"
      1
    )
  )
  (if path
    (if (_bota_cfg_save_file path)
      (prompt (strcat "\nConfiguracao BOTA salva em: " path))
      (alert "Nao foi possivel salvar o arquivo de configuracao.")
    )
  )
)

(defun _bota_cfg_load_interactive (/ path values)
  (setq path
    (getfiled
      "Carregar configuracao BOTA"
      (_bota_cfg_default_file)
      "txt"
      0
    )
  )
  (if path
    (progn
      (setq values (_bota_cfg_values_from_file path))
      (if values
        (progn
          (_bota_cfg_apply_values values)
          (prompt (strcat "\nConfiguracao BOTA carregada de: " path))
          T
        )
        (alert "Arquivo invalido, incompleto ou de versao nao suportada. As configuracoes atuais foram mantidas.")
      )
    )
    nil
  )
)

(defun _bota_cfg_dcl_commit_action (status)
  (strcat
    "(progn "
    "(setq _bota_dcl_values (list "
    "(atof (get_tile \"rGiro\")) "
    "(atof (get_tile \"tamImpl\")) "
    "(atof (get_tile \"distSeg\")) "
    "(atof (get_tile \"seguridad\")) "
    "(atof (get_tile \"filletR\")) "
    "(atof (get_tile \"filletSeg\")) "
    "(atof (get_tile \"botafR\")) "
    "(atof (get_tile \"botafSeg\")) "
    "(_bota_botaf_ranges_from_dcl) "
    "(if (= (get_tile \"joinCab\") \"1\") 1.0 0.0) "
    "(if (= (get_tile \"cutCircle\") \"1\") 1.0 0.0) "
    "(if (= (get_tile \"b3Densify\") \"1\") 1.0 0.0) "
    "(_bota_cfg_number (get_tile \"b3TransL\")) "
    "(_bota_cfg_number (get_tile \"b3DensSeg\")))) "
    "(if (_bota_cfg_values_valid_p _bota_dcl_values) "
    "(progn (_bota_cfg_apply_values _bota_dcl_values) (done_dialog "
    (itoa status)
    ")) "
    "(alert \"Informe valores validos. Densificacao: extensao >= 0 e distancia entre vertices > 0. As faixas devem estar entre 0 e 180 graus, sem sobreposicao, e ter raio e segmento maiores que zero.\"))"
    ")"
  )
)

(defun _bota_show_dcl (/ dclFile fn dclId status keepOpen _bota_dcl_values i range)
  (vl-load-com)
  (_bota_session_pull)
  (_bota3_init_densification)
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
      (write-line "      label = \"Seguranca (BOTA2 / BOTA3)\";" fn)
      (write-line "      : edit_box { label = \"Seguranca Linha Guia (m):\"; key = \"seguridad\"; edit_width = 12; }" fn)
      (write-line "    }" fn)
      (write-line "    : boxed_column {" fn)
      (write-line "      label = \"Fillet (BOTA3)\";" fn)
      (write-line "      : edit_box { label = \"Raio do Fillet (m):\"; key = \"filletR\"; edit_width = 12; }" fn)
      (write-line "      : edit_box { label = \"Distancia Max. Vertices Fillet (m):\"; key = \"filletSeg\"; edit_width = 12; }" fn)
      (write-line "      : toggle { label = \"Ativar densificacao de BOTA3\"; key = \"b3Densify\"; }" fn)
      (write-line "      : edit_box { label = \"Extensao antes/depois da manobra (m):\"; key = \"b3TransL\"; edit_width = 12; }" fn)
      (write-line "      : edit_box { label = \"Distancia Max. Vertices no percurso (m):\"; key = \"b3DensSeg\"; edit_width = 12; }" fn)
      (write-line "    }" fn)
      (write-line "    : boxed_column {" fn)
      (write-line "      label = \"Concordancia Segmentada (BOTAFILLET)\";" fn)
       (write-line "      : edit_box { label = \"Raio da Concordancia (m):\"; key = \"botafR\"; edit_width = 12; }" fn)
       (write-line "      : edit_box { label = \"Distancia Max. Vertices (m):\"; key = \"botafSeg\"; edit_width = 12; }" fn)
       (write-line "    }" fn)
       (write-line "    : boxed_column {" fn)
       (write-line "      label = \"Raio Automatico BOTAFILLET por Angulo\";" fn)
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
      (write-line "      : button { label = \"Salvar arquivo\"; key = \"saveFile\"; width = 16; }" fn)
      (write-line "      : button { label = \"Carregar arquivo\"; key = \"loadFile\"; width = 16; }" fn)
      (write-line "    }" fn)
      (write-line "    : row {" fn)
      (write-line "      : button { label = \"Salvar / Aceitar\"; key = \"accept\"; is_default = true; width = 16; }" fn)
      (write-line "      : button { label = \"Cancelar\"; key = \"cancel\"; is_cancel = true; width = 16; }" fn)
      (write-line "    }" fn)
      (write-line "  }" fn)
      (write-line "}" fn)
      (close fn)

      (setq dclId (load_dialog dclFile))
      (setq keepOpen T)
      (while keepOpen
        (if (new_dialog "bota_config_dialog" dclId)
          (progn
            (set_tile "rGiro"     (rtos *BOTA_RGIRO* 2 3))
            (set_tile "tamImpl"   (rtos *BOTA_IMPL* 2 3))
            (set_tile "distSeg"   (rtos *BOTA_DISTSEG* 2 3))
            (set_tile "seguridad" (rtos *BOTA_SEGURIDAD* 2 3))
            (set_tile "filletR"   (rtos *BOTA_FILLET_R* 2 3))
            (set_tile "filletSeg" (rtos *BOTA_FILLET_SEG* 2 3))
            (set_tile "b3Densify" (if *BOTA3_DENSIFY* "1" "0"))
            (set_tile "b3TransL" (rtos *BOTA_TRANS_L* 2 3))
            (set_tile "b3DensSeg" (rtos *BOTA3_DENSIFY_SEG* 2 3))
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
            (set_tile "joinCab" (if *BOTA_CONECTAR_CAB* "1" "0"))
            (set_tile "cutCircle" (if *BOTA_CORTAR_CIRCULO* "1" "0"))

            (action_tile "accept" (_bota_cfg_dcl_commit_action 1))
            (action_tile "saveFile" (_bota_cfg_dcl_commit_action 2))
            (action_tile "loadFile" "(done_dialog 3)")
            (action_tile "cancel" "(done_dialog 0)")

            (setq status (start_dialog))
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
            (if (= status 2) (_bota_cfg_save_interactive))
            (if (= status 3) (_bota_cfg_load_interactive))
            (if (and (/= status 2) (/= status 3))
              (setq keepOpen nil)
            )
          )
          (progn
            (prompt "\nErro ao abrir a janela de dialogo DCL.")
            (setq keepOpen nil)
          )
        )
      )
      (unload_dialog dclId)
      (vl-file-delete dclFile)
      status
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
      (write-line "        : text_part { label = \"BOTA2 (B2) - Manobra automatica com cabeceira e linha guia.\"; }" fn)
      (write-line "        : text_part { label = \"BOTAM - BOTA2 com ponto manual para definir o lado do giro.\"; }" fn)
      (write-line "        : text_part { label = \"BOTA3 (B3) - Manobra por linha guia com fillet automatico.\"; }" fn)
      (write-line "        : text_part { label = \"BOTAFILLET (BOTAF/BF) - Concordancia automatica entre cabeceira e linha.\"; }" fn)
      (write-line "        : text_part { label = \"BOTAC - Configura e salva/carrega perfis de parametros.\"; }" fn)
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
      (write-line "        : text_part { label = \"BOTAC permite ativar/desativar a densificacao de BOTA3.\"; }" fn)
      (write-line "        : text_part { label = \"O limite cobre giro, reta e fillet, com extensao antes/depois.\"; }" fn)
      (write-line "        : text_part { label = \"Padrao: 5 m por extremo e maximo de 1 m entre vertices.\"; }" fn)
      (write-line "      }" fn)
      (write-line "    }" fn)
      (write-line "    : boxed_column {" fn)
      (write-line "      label = \"Parametros de Concordancia (BOTAFILLET)\";" fn)
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

  (_bota_session_pull)
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
  (setq sel (entsel "\nSelecione a cabeceira perto da zona desejada: "))

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
                    (progn (setq *BOTA_RGIRO* rGiro) (_bota_session_publish))
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
                  (_bota_session_publish)

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

(defun _bota2_define_helpers ()
  ;; BOTA2 e BOTA2DEBUG inicializam o mesmo calculo. O estado temporario
  ;; pertence ao comando chamador, inclusive durante erros dentro dos helpers.

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
    (setq p
      (vl-catch-all-apply 'vlax-curve-getClosestPointTo (list e pt)))
    (if (or (not p) (vl-catch-all-error-p p)) nil (b2_pt3 p))
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

  (defun b2_track_temp (e)
    (if e (setq b2Temps (cons e b2Temps)))
    e
  )

  (defun b2_clear_temporaries (/ e)
    (if (and b2Original (not b2Committed) (not (entget b2Original)))
      (vl-catch-all-apply 'entdel (list b2Original))
    )
    (foreach e b2Temps
      (if (not (and b2Committed (member e b2Outputs)))
        (b2_delete_ent e)
      )
    )
    (setq b2Temps nil)
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
    (if (and guiaLocal (entget guiaLocal))
      (b2_delete_ent guiaLocal)
    )
    (if (and cabLocal (entget cabLocal))
      (b2_delete_ent cabLocal)
    )
    (setq offCab nil)
    (setq offGuia nil)
    (setq offCentro nil)
    (setq tmpExtCircle nil)
    (setq guiaLocal nil)
    (setq cabLocal nil)
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
          (progn
            (setq offsetComError (vl-catch-all-error-message res))
            nil
          )
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
                (setq out (cons (b2_track_temp en) out))
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

  (defun b2_endpoint_contacts (e1 e2 / pts pair p q)
    ;; Reserva de custo constante para pontas conectadas omitidas pelo COM.
    ;; Projeta sobre a curva nativa: nunca substitui arcos por cordas.
    (setq pts nil)
    (foreach pair (list (list e1 e2) (list e2 e1))
      (foreach p
        (list
          (vl-catch-all-apply 'vlax-curve-getStartPoint (list (car pair)))
          (vl-catch-all-apply 'vlax-curve-getEndPoint (list (car pair)))
        )
        (if (and p (not (vl-catch-all-error-p p)))
          (progn
            (setq p (b2_pt3 p))
            (setq q (b2_closest_point (cadr pair) p))
            (if (and q (<= (distance p q) 1e-4))
              (setq pts (cons p pts))
            )
          )
        )
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

  (defun b2_real_intersections (e1 e2 / pts valid p)
    ;; IMPORTANTE:
    ;; Busca somente intersecao REAL entre os offsets.
    ;; Nao estende as entidades.
    ;; Se nao existir intersecao real, devolve nil. Mantem todos os pontos
    ;; validos para que o solver de tangencia possa avaliar cada centro.

    (setq pts (b2_intersections e1 e2 0))
    (setq valid nil)
    (foreach p pts
      (if (and (b2_point_on_curve_p e1 p 1e-4)
               (b2_point_on_curve_p e2 p 1e-4))
        (setq valid (cons p valid))
      )
    )
    (if (not valid)
      (setq valid (b2_endpoint_contacts e1 e2))
    )

    valid
  )

  (defun b2_intersection_best (e1 e2 pref / valid)
    (setq valid (b2_real_intersections e1 e2))

    (if valid
      (b2_best_point valid pref)
      nil
    )
  )

  (defun b2_tangent_solution
    (eHeader eCenterOffset eOuterCircle pVert rInner rOuter pReference
     / tol centers rawCenter pTang rawErr v correctedCenter outerErr solution)
    ;; A tolerancia vale somente para validar e corrigir o CENTRO calculado.
    ;; Nao altera offset, guia, cortes ou a cabecaria original.
    (setq tol 0.050)
    (setq tangentError nil)
    (setq solution nil)
    (setq centers (b2_real_intersections eCenterOffset eOuterCircle))
    ;; A intersecao mais proxima de pJoint e a unica que pertence a manobra
    ;; solicitada. Avaliar o outro lado do circulo pode inverter o giro.
    ;; Este e o mesmo criterio geometrico usado antes da tolerancia.
    (setq rawCenter (if centers (b2_best_point centers pReference) nil))
    (if rawCenter
      (progn
        (setq rawCenter (b2_pt3 rawCenter))
        (setq pTang (b2_closest_point eHeader rawCenter))
        (if pTang
          (progn
            (setq rawErr (abs (- (distance rawCenter pTang) rInner)))
            (setq v (b2_unit (b2_v- rawCenter pTang)))
            (if v
              (progn
                ;; A tangencia final e exata; tol aceita somente o pequeno
                ;; ajuste numerico devolvido pelo OFFSET/IntersectWith.
                (setq correctedCenter (b2_v+ pTang (b2_v* rInner v)))
                (setq outerErr
                  (abs (- (distance correctedCenter pVert) rOuter))
                )
                ;; Margem minima evita que 0.050 seja rejeitado por arredondamento
                ;; binario, mantendo o limite operacional em 0.050 m.
                (if (and (<= rawErr (+ tol 1e-9))
                         (<= outerErr (+ tol 1e-9)))
                  ;; (centro-corrigido tangencia centro-original
                  ;;  erro-interno erro-externo)
                  (setq solution
                    (list correctedCenter pTang rawCenter rawErr outerErr)
                  )
                )
              )
            )
          )
        )
      )
    )
    (if (not solution)
      (setq tangentError
        (if centers
          "Centros candidatos excedem a tolerancia de tangencia de 0.050 m."
          "Nao foi encontrado centro candidato entre o offset da cabeceira e o circulo externo."
        )
      )
    )
    solution
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

  (defun b2_signed_entry_by_side (entries eBase pSide sameSide / best bestScore bestDist entry score dist)
    ;; Seleciona pelo lado geometrico do offset, nao pela distancia entre
    ;; curvas. Isso preserva a regra mesmo quando os tramos sao paralelos.
    (setq best nil)
    (setq bestScore nil)
    (setq bestDist nil)
    (foreach entry entries
      (if (and entry (car entry) (entget (car entry)))
        (progn
          (setq score (b2_offset_side_score eBase (car entry) pSide))
          (setq dist (b2_dist_to_ent (car entry) pSide))
          (if (or (not best)
                  (if sameSide
                    (or (> score bestScore)
                        (and (equal score bestScore 1e-9) (< dist bestDist)))
                    (or (< score bestScore)
                        (and (equal score bestScore 1e-9) (> dist bestDist)))
                  ))
            (progn
              (setq best entry)
              (setq bestScore score)
              (setq bestDist dist)
            )
          )
        )
      )
    )
    (if (and best (if sameSide (> bestScore 1e-9) (< bestScore -1e-9))) best nil)
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
            (if (vl-catch-all-error-p en) nil (b2_track_temp en))
          )
        )
      )
      nil
    )
  )

  (defun b2_point_on_curve_p (e p tol / q)
    (setq q (b2_closest_point e p))
    (and q (<= (distance q p) tol))
  )

  (defun b2_piece_matches_p (e p1 p2 expectedLength / a b total)
    (setq a (vl-catch-all-apply 'vlax-curve-getStartPoint (list e)))
    (setq b (vl-catch-all-apply 'vlax-curve-getEndPoint (list e)))
    (setq total (b2_curve_total_length e))
    (and a b total
         (not (vl-catch-all-error-p a))
         (not (vl-catch-all-error-p b))
         (equal total expectedLength 1e-4)
         (or (and (equal a p1 1e-4) (equal b p2 1e-4))
             (and (equal b p1 1e-4) (equal a p2 1e-4))))
  )

  (defun b2_split_copy_at_point
    (e pBreak / cutDist total pStart pEnd before after res valid)
    ;; So recebe copias. Valida os dois tramos antes de aceitar o BREAK.
    (setq cutDist (b2_curve_dist_at_point e pBreak))
    (setq total (b2_curve_total_length e))
    (if (and cutDist total (b2_point_on_curve_p e pBreak 1e-4))
      (if (or (<= cutDist 1e-5) (<= (- total cutDist) 1e-5))
        (list e)
        (progn
          (setq pStart (vlax-curve-getStartPoint e))
          (setq pEnd (vlax-curve-getEndPoint e))
          (setq before (entlast))
          (setq res (b2_breakatpoint e pBreak))
          (setq after (entlast))
          (if (and after (/= after before))
            (b2_track_temp after)
          )
          (setq valid
            (and (not (vl-catch-all-error-p res))
                 after (/= after before) (entget e) (entget after)
                 (or
                   (and (b2_piece_matches_p e pStart pBreak cutDist)
                        (b2_piece_matches_p after pBreak pEnd (- total cutDist)))
                   (and (b2_piece_matches_p after pStart pBreak cutDist)
                        (b2_piece_matches_p e pBreak pEnd (- total cutDist)))))
          )
          (if valid
            (list e after)
            (progn
              (b2_delete_ent e)
              (if (and after (/= after before)) (b2_delete_ent after))
              nil
            )
          )
        )
      )
      (progn (b2_delete_ent e) nil)
    )
  )

  (defun b2_break_copy_keep_toward
    (e pBreak pRef / cutDist refDist total pStart pEnd parts keep wantedPoint wantedLength part)
    ;; Mede a referencia ANTES do BREAK. O rumo inicial de uma curva nao
    ;; identifica o ramo que contem o clique quando ela faz uma volta.
    (setq cutDist (b2_curve_dist_at_point e pBreak))
    (setq refDist (b2_curve_dist_at_point e pRef))
    (setq total (b2_curve_total_length e))
    (if (and cutDist refDist total (b2_point_on_curve_p e pBreak 1e-4))
      (if (or (<= cutDist 1e-5) (<= (- total cutDist) 1e-5))
        e
        (if (equal cutDist refDist 1e-5)
          (progn (b2_delete_ent e) nil)
          (progn
            (setq pStart (vlax-curve-getStartPoint e))
            (setq pEnd (vlax-curve-getEndPoint e))
            (if (< refDist cutDist)
              (setq wantedPoint pStart wantedLength cutDist)
              (setq wantedPoint pEnd wantedLength (- total cutDist))
            )
            (setq parts (b2_split_copy_at_point e pBreak))
            (setq keep nil)
            (foreach part parts
              (if (b2_piece_matches_p part wantedPoint pBreak wantedLength)
                (setq keep part)
              )
            )
            (foreach part parts
              (if (/= part keep) (b2_delete_ent part))
            )
            keep
          )
        )
      )
      (progn (b2_delete_ent e) nil)
    )
  )

  (defun b2_curve_total_length (e / endParam total)
    ;; Comprimento real da curva, preservando arcos e bulges da polilinha.
    (setq endParam
      (vl-catch-all-apply 'vlax-curve-getEndParam (list e))
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
        (if (vl-catch-all-error-p total) nil total)
      )
    )
  )

  (defun b2_guide_temp_segment
    (e pJoint pGuideRef segLength reserveLength
     / work total jointDist guideDist pBefore pAfter)
    ;; Mantem uma reserva curta do lado oposto ao clique e 1,5 x implemento
    ;; no lado do clique. Os dois cortes ocorrem somente na copia.
    (setq work (b2_copy_entity e))
    (if work
      (progn
        ;; As medidas usam a curva original para que o segundo corte conserve
        ;; o sentido correto mesmo apos a primeira quebra da copia.
        (setq total (b2_curve_total_length e))
        (setq jointDist (b2_curve_dist_at_point e pJoint))
        (setq guideDist (b2_curve_dist_at_point e pGuideRef))
        (if (and total jointDist guideDist)
          (progn
            (if (>= guideDist jointDist)
              (progn
                (setq pBefore (max 0.0 (- jointDist reserveLength)))
                (setq pAfter (min total (+ jointDist segLength)))
              )
              (progn
                (setq pBefore (max 0.0 (- jointDist segLength)))
                (setq pAfter (min total (+ jointDist reserveLength)))
              )
            )
            (if (> pBefore 1e-5)
              (progn
                (setq pBefore
                  (vl-catch-all-apply 'vlax-curve-getPointAtDist
                    (list e pBefore)))
                (if (and pBefore (not (vl-catch-all-error-p pBefore)))
                  (setq work
                    (b2_break_copy_keep_toward work (b2_pt3 pBefore) pJoint))
                  (progn (b2_delete_ent work) (setq work nil))
                )
              )
            )
            (if (and work (< pAfter (- total 1e-5)))
              (progn
                (setq pAfter
                  (vl-catch-all-apply 'vlax-curve-getPointAtDist
                    (list e pAfter)))
                (if (and pAfter (not (vl-catch-all-error-p pAfter)))
                  (setq work
                    (b2_break_copy_keep_toward work (b2_pt3 pAfter) pJoint))
                  (progn (b2_delete_ent work) (setq work nil))
                )
              )
            )
          )
          (progn (b2_delete_ent work) (setq work nil))
        )
      )
    )
    work
  )

  (defun b2_curve_dist_at_point (e p / q value)
    (setq q (b2_closest_point e p))
    (if q
      (progn
        (setq value
          (vl-catch-all-apply
            'vlax-curve-getDistAtPoint
            (list e q)
          )
        )
        (if (vl-catch-all-error-p value) nil value)
      )
      nil
    )
  )

  (defun b2_header_temp_segment
    (e pJoint segLength / work total jointDist pBefore pAfter)
    ;; Conserva os arcos nativos dos dois lados da intersecao.
    (setq work (b2_copy_entity e))
    (if work
      (progn
        (setq total (b2_curve_total_length e))
        (setq jointDist (b2_curve_dist_at_point e pJoint))
        (if (and total jointDist)
          (progn
            (if (> jointDist (+ segLength 1e-5))
              (progn
                (setq pBefore
                  (vl-catch-all-apply 'vlax-curve-getPointAtDist
                    (list e (- jointDist segLength)))
                )
                (if (and pBefore (not (vl-catch-all-error-p pBefore)))
                  (setq work
                    (b2_break_copy_keep_toward work (b2_pt3 pBefore) pJoint))
                  (progn (b2_delete_ent work) (setq work nil))
                )
              )
            )
            (if (and work (< jointDist (- total segLength 1e-5)))
              (progn
                (setq pAfter
                  (vl-catch-all-apply 'vlax-curve-getPointAtDist
                    (list e (+ jointDist segLength)))
                )
                (if (and pAfter (not (vl-catch-all-error-p pAfter)))
                  (setq work
                    (b2_break_copy_keep_toward work (b2_pt3 pAfter) pJoint))
                  (progn (b2_delete_ent work) (setq work nil))
                )
              )
            )
          )
          (progn (b2_delete_ent work) (setq work nil))
        )
      )
    )
    work
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
    ;; O centro obedece ao mesmo lado usado no offset inicial da cabecaria.
    ;; Se apenas o lado contrario existir, retorna nil para a reserva local.
    (setq entries (b2_offset_candidates_signed e dist))
    (setq keep (b2_signed_entry_by_side entries e ref T))
    (b2_delete_signed_entries_except entries (if keep (car keep) nil))
    (if keep (car keep) nil)
  )

  (defun b2_offset_pair_for_maneuver
    (eCab eGuia distCab distGuia pCabRef pGuideRef pJoint
     / cabEntries guideEntries cabEntry guideEntry match)
    ;; Cabecaria no lado da guia; guia no lado oposto ao clique da cabecaria.
    ;; As duas curvas ja chegam limitadas a uma janela temporaria local.
    (setq offsetError nil offsetComError nil)
    (setq cabEntries (b2_offset_candidates_signed eCab distCab))
    (setq cabEntry (b2_signed_entry_by_side cabEntries eCab pGuideRef T))
    (if (not cabEntry)
      (progn
        (b2_delete_signed_entries_except cabEntries nil)
        (setq cabEntries nil)
        (setq offsetError
          (strcat
            "Nao foi possivel criar o offset da cabeceira no lado do clique da guia."
            (if offsetComError (strcat " Civil 3D: " offsetComError) "")))
      )
    )
    (if cabEntry
      (progn
        (setq guideEntries (b2_offset_candidates_signed eGuia distGuia))
        (setq guideEntry
          (b2_signed_entry_by_side guideEntries eGuia pCabRef nil))
        (if (not guideEntry)
          (setq offsetError
            "Nao foi possivel criar o offset da guia no lado oposto ao clique da cabeceira.")
        )
      )
    )
    (if (and cabEntry guideEntry)
      (progn
        (setq match
          (b2_find_offset_intersection (car cabEntry) (list guideEntry) pJoint T))
        (if (not match)
          (setq offsetError
            "Os offsets selecionados nao se intersectam; a extensao virtual de 1.000 m tambem nao encontrou solucao.")
        )
      )
    )
    (b2_delete_signed_entries_except cabEntries (if cabEntry (car cabEntry) nil))
    (b2_delete_signed_entries_except guideEntries (if guideEntry (car guideEntry) nil))
    ;; Mesmo sem intersecao, o debug pode mostrar exatamente os offsets que
    ;; o comando selecionou. Somente um ponto valido autoriza a manobra.
    (if (or cabEntry guideEntry)
      (list (car cabEntry) (car guideEntry) (cadr match) (caddr match))
      nil
    )
  )

  (defun b2_prepare_offsets
    (eCab eGuide pCabRef pGuideRef impl safety / joint guideLocal cabLocal data)
    ;; Entrada unica do solver para BOTA2, BOTAM e BOTA2DEBUG.
    (setq offsetError nil offsetComError nil)
    (setq joint (b2_reference_intersection eCab eGuide pCabRef))
    (if joint
      (progn
        (setq guideLocal
          (b2_guide_temp_segment
            eGuide joint pGuideRef (* 1.5 impl) (* 0.2 impl)))
        (if guideLocal
          (progn
            ;; Isola a cabecaria antes do OFFSET, como no BREAK manual que
            ;; resolve guias conectadas em outros extremos.
            (setq cabLocal (b2_header_temp_segment eCab joint (* 2.0 impl)))
            (if cabLocal
              (progn
                (setq data
                  (b2_offset_pair_for_maneuver
                    cabLocal guideLocal (/ impl 2.0) (+ (/ impl 2.0) safety)
                    pCabRef pGuideRef joint))
                (if data
                  (append data (list cabLocal joint))
                  nil)
              )
              (progn
                (setq offsetError "Nao foi possivel criar o tramo temporario da cabeceira.")
                nil
              )
            )
          )
          (progn
            (setq offsetError "Nao foi possivel criar o tramo temporario da linha guia.")
            nil
          )
        )
      )
      (progn
        (setq offsetError "Nao foi encontrada intersecao real entre a cabeceira e a linha guia.")
        nil
      )
    )
  )

  (defun b2_reference_intersection (e1 e2 pref)
    (b2_intersection_best e1 e2 pref)
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

  (defun b2_commit_maneuver (/ work parts stageError result)
    ;; BREAK e JOIN trabalham numa copia. O original so sai do desenho
    ;; quando todos os objetos finais ja existem e a uniao foi validada.
    (setq b2Committed nil b2Original nil b2Outputs nil)
    (setq work (b2_copy_entity ent))
    (setq parts (if work (b2_split_copy_at_point work pTang) nil))
    (if (not parts)
      (setq stageError "Nao foi possivel cortar a copia da cabeceira na tangencia.")
    )
    (if (not stageError)
      (progn
        (setq giroData
          (if *BOTA_CORTAR_CIRCULO*
            (b2_circle_gap_directional centro rGiro pTang pCutRef nSegGiro nil)
            (b2_circle_full_directional centro rGiro pTang pCutRef nSegGiro nil)))
        (setq entGiro (b2_track_temp (car giroData)))
        (if (not (and entGiro (entget entGiro)))
          (setq stageError "Nao foi possivel criar a polilinha da manobra.")
        )
      )
    )
    (if (and (not stageError) *BOTA_CONECTAR_CAB*)
      (progn
        (setq entCabJoin
          (b2_select_side_segment (car parts) (cadr parts) pTang pCutRef))
        (setq joinOk (b2_join_two entGiro entCabJoin))
        (if (not joinOk)
          (setq stageError "Nao foi possivel unir a manobra ao tramo da cabeceira.")
        )
      )
    )
    (if (not stageError)
      (progn
        (setq entBarra (b2_track_temp (b2_circle_entity centro rBarra 6)))
        (if (not (and entBarra (entget entBarra)))
          (setq stageError "Nao foi possivel criar o circulo externo.")
        )
      )
    )
    (if (not stageError)
      (progn
        (setq b2Outputs (append (list entGiro entBarra) parts))
        (setq b2Original ent)
        (setq result (vl-catch-all-apply 'entdel (list ent)))
        (if (and (not (vl-catch-all-error-p result)) result (not (entget ent)))
          (setq b2Committed T)
          (setq stageError "Nao foi possivel substituir a cabeceira original.")
        )
      )
    )
    (b2_clear_temporaries)
    (if stageError
      (prompt (strcat "\n" stageError " A cabeceira original foi preservada."))
      (progn
        (if (not *BOTA_CONECTAR_CAB*)
          (prompt "\nConexao com cabeceira desativada para BOTA2.")
        )
        (prompt
          (strcat "\nRaio Interno: " (rtos rGiro 2 3)
                  " - Raio Externo: " (rtos rBarra 2 3)))
      )
    )
    b2Committed
  )

  (defun b2_run_simple ()
    (setq rBarra (+ rGiro (/ tamImpl 2.0)))
    (b2_clear_temporaries)
    (setq offsetData
      (b2_prepare_offsets ent guia pCab pGuiaPick tamImpl seguridad))
    ;; Registra los offsets aunque no exista pVert. Asi, un intento fallido
    ;; no deja copias de las curvas en el dibujo.
    (setq offCab (car offsetData) offGuia (cadr offsetData))
    (setq pVert (caddr offsetData))
    (if pVert
      (progn
        (setq usedVirtual (cadddr offsetData) cabLocal (nth 4 offsetData))
        (setq pJoint (nth 5 offsetData))
        (if usedVirtual
          (prompt "\nIntersecao dos offsets obtida por extensao virtual de ate 1.000 m.")
        )
        (b2_delete_ent offCab)
        (b2_delete_ent offGuia)
        (setq offCab nil offGuia nil)
        ;; O lado do centro permanece o do clique na guia, na mesma copia
        ;; local de cabecaria usada pelos offsets da manobra.
        (setq offCentro
          (b2_offset_select_toward cabLocal rGiro pGuiaPick))
        (setq tmpExtCircle (b2_circle_entity pVert rBarra nil))
        (setq tangentData
          (if (and offCentro tmpExtCircle)
            (b2_tangent_solution
              cabLocal offCentro tmpExtCircle pVert rGiro rBarra pJoint
            )
            nil
          )
        )
        (if tangentData
          (progn
            (setq centro (car tangentData))
            (setq pTang (cadr tangentData))
          )
          (setq centro nil pTang nil)
        )
        (b2_clear_temporaries)
        (if (and centro pTang)
          (progn
            ;; Regra de giro existente: oposto a intersecao; BOTAM usa o mouse.
            (setq pCutRef
              (if manualSideMode pSide (b2_opposite_point pTang pVert)))
            (setq nSegGiro (b2_nseg_inscribed rGiro distSeg))
            (b2_commit_maneuver)
          )
          (prompt
            (strcat
              "\n"
              (if tangentError tangentError
                "Nao ha tangencia valida no lado solicitado da cabeceira."
              )
            )
          )
        )
      )
      (progn
        (b2_clear_temporaries)
        (prompt
          (strcat "\n" (if offsetError offsetError
            "Nao foi encontrada intersecao valida entre os offsets selecionados.")))
      )
    )
  )

  (princ)
)

(defun c:BOTA2 (/ *error* oldLuprec cfg sel ent guia pPick pCab pGuiaPick pSide pJoint manualSideMode
                  offsetData usedVirtual offsetError offsetComError tangentError tangentData guiaLocal cabLocal
                  b2Temps b2Outputs b2Original b2Committed
                  rGiro tamImpl seguridad rBarra distSeg offCabDist offGuiaDist
                  offCab offGuia offCentro tmpExtCircle pVert pCutRef
                  pTang centro nSegGiro giroData entGiro entBarra ptsGiro
                  pGapIni pGapFin entCabJoin joinOk)
  (_bota_session_pull)
  (vl-load-com)
  (_bota2_define_helpers)
  (setq manualSideMode
    (and (boundp '*BOTA2_MANUAL_SIDE_MODE*) *BOTA2_MANUAL_SIDE_MODE*)
  )
  (setq *BOTA2_MANUAL_SIDE_MODE* nil)

  (defun b2_restore ()
    (if oldLuprec (setvar "LUPREC" oldLuprec))
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
  ;; Inicio del comando
  ;; -------------------------

  ;; Parametros preconfigurados
  (if (not *BOTA_RGIRO*)     (setq *BOTA_RGIRO* 10.000))
  (if (not *BOTA_IMPL*)      (setq *BOTA_IMPL* 36.578))
  (if (not *BOTA_DISTSEG*)   (setq *BOTA_DISTSEG* 0.900))
  (if (not *BOTA_SEGURIDAD*) (setq *BOTA_SEGURIDAD* 0.200))
  (_bota_init_boolean_options)

  (setq oldLuprec (getvar "LUPREC"))
  (setvar "LUPREC" 3)

  (if manualSideMode
    (prompt "\nBOTAM - Manobra por linha guia com lado manual.")
    (prompt "\nBOTA2 - Manobra por linha guia.")
  )
  (setq sel (entsel "\nSelecione a cabeceira perto da zona desejada: "))

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

          (setq sel (entsel "\nSelecione a linha guia: "))

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
                        (progn (setq *BOTA_RGIRO* rGiro) (_bota_session_publish))
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
                      (_bota_session_publish)

                      (b2_run_simple)
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
;; COMANDO BOTAM - BOTA2 COM PONTO MANUAL DE LADO
;; ============================================================

(defun c:BOTAM ()
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

(defun c:BOTA3 (/ *error* oldLuprec cfg sel ent guia guiaLocal cabLocal pPick pCab pJoint pSide pVert pCutRef
                  rGiro tamImpl seguridad rBarra distSeg filletR filletDistSeg
                  offCabDist offGuiaDist offCab offGuia tol radioTrabajo stepGuia stepCab
                  endParam i p1 p2 u n segLen side base rel tProj pFoot dPerp
                  maxDelta t1 t2 tc candidates candidate bestScore pTang centro
                  nSegGiro score c entGiro entBarra ptsGiro lastBefore lastAfter
                  entCab2 entCabJoin joinOk tmpCircle tmpGuide tmpFillet
                  giroData pGapIni pGapFin pGuiaPick
                  vCenter tmpL
                  entFillet joinFilletOk
                  tmpL)

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
  (_bota3_define_helpers)
  (_bota3_define_pipeline)

  ;; Las definiciones se cargan tambien desde las pruebas nativas.
  (b3_command_body)
  (b3_restore)
  (princ)
)

(defun _bota3_define_helpers ()
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

)

(defun _bota3_define_pipeline ()
  (_bota2_define_helpers)
  (_bota3_init_densification)

  (defun b3_densify_stations (d0 d1 low high spacing / a b count step index d stations)
    ;; Apenas estacoes novas internas ao segmento; inclui os limites da janela.
    (setq a (max d0 low) b (min d1 high))
    (if (> (- b a) 1e-8)
      (progn
        (setq count (max 1 (b3_ceil (/ (- b a) spacing)))
              step (/ (- b a) count) index 0)
        (repeat (1+ count)
          (setq d (if (= index count) b (+ a (* index step))))
          (if (and (> d (+ d0 1e-8)) (< d (- d1 1e-8)))
            (setq stations (cons d stations)))
          (setq index (1+ index)))))
    (reverse stations)
  )

  (defun b3_bulge_fraction (bulge fraction / angle)
    ;; Bulge = tan(angulo/4). Subdivide o arco sem substituir por cordas.
    (if (= fraction 1.0) bulge
      (progn
        (setq angle (* (atan bulge) fraction))
        (/ (sin angle) (cos angle))))
  )

  (defun b3_densify_segment (e obj index low high spacing
                           / d0 d1 stations station inserts p fraction nextFraction bulge w0 w1 pointArray)
    (setq d0 (vlax-curve-getDistAtParam e index)
          d1 (vlax-curve-getDistAtParam e (1+ index))
          stations (b3_densify_stations d0 d1 low high spacing))
    (if stations
      (progn
        (setq bulge (vla-GetBulge obj index))
        (vla-GetWidth obj index 'w0 'w1)
        ;; Mede todos os pontos ANTES da primeira insercao neste segmento.
        (foreach station stations
          (setq p (trans (vlax-curve-getPointAtDist e station) 0 e))
          (setq inserts (cons (list (/ (- station d0) (- d1 d0)) p) inserts)))
        (setq nextFraction 1.0)
        ;; Do fim para o inicio: os indices dos vertices existentes nao mudam.
        (foreach p inserts
          (setq fraction (car p)
                pointArray (vlax-make-safearray vlax-vbDouble '(0 . 1)))
          (vlax-safearray-fill pointArray (list (car (cadr p)) (cadr (cadr p))))
          (vla-AddVertex obj (1+ index) (vlax-make-variant pointArray))
          (vla-SetBulge obj (1+ index) (b3_bulge_fraction bulge (- nextFraction fraction)))
          (vla-SetWidth obj (1+ index)
            (+ w0 (* fraction (- w1 w0)))
            (+ w0 (* nextFraction (- w1 w0))))
          (setq nextFraction fraction))
        (vla-SetBulge obj index (b3_bulge_fraction bulge nextFraction))
        (vla-SetWidth obj index w0 (+ w0 (* nextFraction (- w1 w0))))))
  )

  (defun b3_density_valid_p (e low high spacing / index count a b valid)
    (setq index 0 count (fix (vlax-curve-getEndParam e)) valid T)
    (repeat count
      (setq a (vlax-curve-getDistAtParam e index)
            b (vlax-curve-getDistAtParam e (1+ index)))
      (if (and (> b (+ low 1e-8)) (< a (- high 1e-8))
               (> (- b a) (+ spacing 1e-6)))
        (setq valid nil))
      (setq index (1+ index)))
    valid
  )

  (defun b3_densify_interval (e low high spacing / obj lengthBefore startBefore endBefore index)
    ;; Recebe somente o resultado temporario, nunca as entidades originais.
    (if (and e (= (cdr (assoc 0 (entget e))) "LWPOLYLINE")
             (numberp spacing) (> spacing 0.0) (< low high))
      (progn
        (setq obj (vlax-ename->vla-object e)
              lengthBefore (b2_curve_total_length e)
              startBefore (vlax-curve-getStartPoint e)
              endBefore (vlax-curve-getEndPoint e)
              index (fix (vlax-curve-getEndParam e)))
        (repeat index
          (setq index (1- index))
          (b3_densify_segment e obj index low high spacing))
        (vla-Update obj)
        (if (and (equal lengthBefore (b2_curve_total_length e) 1e-5)
                 (equal startBefore (vlax-curve-getStartPoint e) 1e-6)
                 (equal endBefore (vlax-curve-getEndPoint e) 1e-6)
                 (b3_density_valid_p e low high spacing))
          e)))
  )

  (defun b3_apply_densification (e entry exitPoint / dEntry dExit total low high result)
    (if (not *BOTA3_DENSIFY*) e
      (progn
        (if (and (numberp *BOTA_TRANS_L*) (>= *BOTA_TRANS_L* 0.0)
                 (numberp *BOTA3_DENSIFY_SEG*) (> *BOTA3_DENSIFY_SEG* 0.0)
                 entry exitPoint
                 (b3_point_really_on_curve e entry 1e-4)
                 (b3_point_really_on_curve e exitPoint 1e-4))
          (progn
            (setq dEntry (b2_curve_dist_at_point e entry)
                  dExit (b2_curve_dist_at_point e exitPoint)
                  total (b2_curve_total_length e)
                  low (max 0.0 (- (min dEntry dExit) *BOTA_TRANS_L*))
                  high (min total (+ (max dEntry dExit) *BOTA_TRANS_L*)))
            (setq result (b3_densify_interval e low high *BOTA3_DENSIFY_SEG*))))
        (if (not result)
          (setq *BOTA3_FILLET_FAIL* "Nao foi possivel densificar o percurso preservando a geometria."))
        result))
  )
  (defun b3_validate_inputs (header headerPick guide guidePick)
    ;; Valida as entidades sem medir ou limitar o angulo da manobra.
    (setq *BOTA3_FILLET_FAIL* nil)
    (if (or (= header guide) (not (b3_open_xy_poly_p header)) (not (b3_open_xy_poly_p guide)))
      (setq *BOTA3_FILLET_FAIL* "Selecione duas polilinhas abertas no plano XY, em camadas desbloqueadas."))
    (not *BOTA3_FILLET_FAIL*)
  )

  ;; Todas as entidades modificadas durante o FILLET sao copias descartaveis.
  (defun b3_track (e)
    (if (and e (not (member e b3Temps))) (setq b3Temps (cons e b3Temps)))
    e
  )

  (defun b3_open_xy_poly_p (e / data flags normal layer)
    (setq data (entget e) flags (cdr (assoc 70 data))
          normal (cdr (assoc 210 data)) layer (tblsearch "LAYER" (cdr (assoc 8 data))))
    (and (member (cdr (assoc 0 data)) '("LWPOLYLINE" "POLYLINE"))
         (= 0 (logand (if flags flags 0) 127))
         (or (not normal) (equal normal '(0.0 0.0 1.0) 1e-8))
         (= 0 (logand 4 (cdr (assoc 70 layer))))
         (equal (caddr (vlax-curve-getStartPoint e)) 0.0 1e-6)
         (equal (caddr (vlax-curve-getEndPoint e)) 0.0 1e-6))
  )

  (defun b3_end_on (e p)
    (or (equal (vlax-curve-getStartPoint e) p 1e-4)
        (equal (vlax-curve-getEndPoint e) p 1e-4))
  )

  (defun b3_join_chain (entities / base rest pending e a b joined progress)
    ;; JOIN so recebe objetos com extremos coincidentes; nunca cria pontes.
    (setq base (car entities) rest (cdr entities) progress T)
    (while (and base rest progress)
      (setq pending nil progress nil)
      (foreach e rest
        (if (and (entget base) (entget e))
          (progn
            (setq a (vlax-curve-getStartPoint e) b (vlax-curve-getEndPoint e))
            (if (or (b3_end_on base a) (b3_end_on base b))
              (progn
                (b3_join_two base e)
                (setq joined
                  (if (and (entget base) (not (entget e))) base
                    (if (and (entget e) (not (entget base))) e nil)))
                (if joined (setq base joined progress T)
                  (setq pending (cons e pending))))
              (setq pending (cons e pending))))))
      (setq rest (reverse pending)))
    (if (and base (entget base) (not rest)) base nil)
  )

  (defun b3_lwpoly_styled (pts style / data code value)
    ;; LWPOLYLINE abierta con capa/color/tipo de linea de la cabecera.
    (setq data (list '(0 . "LWPOLYLINE") '(100 . "AcDbEntity")))
    (foreach code '(8 6 62 420 440 48 370)
      (if (setq value (assoc code (entget style)))
        (setq data (append data (list value)))))
    (setq data (append data (list '(100 . "AcDbPolyline") (cons 90 (length pts)) '(70 . 0))))
    (foreach value pts
      (setq data (append data (list (cons 10 (list (car value) (cadr value))) '(42 . 0.0)))))
    (b3_track (entmakex data))
  )

  (defun b3_guide_pieces (guide / n i a b da db bulge len k j p q d0 d1 out)
    ;; Tramos rectos de la guia: (A B distA distB).
    ;; Los tramos con bulge se discretizan en cuerdas de ~0.25.
    (setq n (fix (vlax-curve-getEndParam guide)) i 0)
    (repeat n
      (setq a  (b3_pt3 (vlax-curve-getPointAtParam guide i))
            b  (b3_pt3 (vlax-curve-getPointAtParam guide (1+ i)))
            da (vlax-curve-getDistAtParam guide i)
            db (vlax-curve-getDistAtParam guide (1+ i))
            bulge (vl-catch-all-apply 'vla-getBulge
                    (list (vlax-ename->vla-object guide) i)))
      (if (or (vl-catch-all-error-p bulge) (< (abs bulge) 1e-9))
        (setq out (cons (list a b da db) out))
        (progn
          (setq k (max 2 (b3_ceil (/ (- db da) 0.25))) j 0 p a d0 da)
          (repeat k
            (setq j (1+ j)
                  d1 (+ da (* (- db da) (/ (float j) k)))
                  q (if (= j k) b (b3_pt3 (vlax-curve-getPointAtDist guide d1))))
            (setq out (cons (list p q d0 d1) out) p q d0 d1))))
      (setq i (1+ i)))
    (reverse out)
  )

  (defun b3_selected_guide_pieces (guide pick / pieces pickDist picked reference direction pc run selected stopped)
    ;; Isola o passe CONTINUO que contem o clique. O retorno pode estar perto
    ;; no desenho, mas nao pertence a este passe. Nao salta por cima de uma
    ;; dobra para admitir outro passe posterior com a mesma orientacao.
    (setq pieces (b3_guide_pieces guide)
          pickDist (b2_curve_dist_at_point guide pick))
    (foreach pc pieces
      (if (and pickDist (not picked)
               (>= pickDist (- (nth 2 pc) 1e-6))
               (<= pickDist (+ (nth 3 pc) 1e-6))
               (b3_unit (b3_v- (cadr pc) (car pc))))
        (setq picked pc)))
    (if picked
      (progn
        (setq reference (b3_unit (b3_v- (cadr picked) (car picked))))
        (foreach pc pieces
          (if (not stopped)
            (progn
              (setq direction (b3_unit (b3_v- (cadr pc) (car pc))))
              (if direction
                (if (> (b3_dot direction reference) 1e-6)
                  (progn
                    (setq run (cons pc run))
                    (if (equal (nth 2 pc) (nth 2 picked) 1e-8) (setq selected T)))
                  (if selected (setq stopped T) (setq run nil)))))))
        (if selected (reverse run))))
  )

  (defun b3_joint_on_selected_guide (header guide headerPick pieces / low high points p d valid)
    ;; O cruzamento tambem deve pertencer ao passe clicado, inclusive quando
    ;; a cabeceira cruza varios passes da mesma polilinha.
    (if pieces
      (progn
        (setq low (nth 2 (car pieces)) high (nth 3 (last pieces))
              points (b2_real_intersections header guide))
        (foreach p points
          (setq d (b2_curve_dist_at_point guide p))
          (if (and d (>= d (- low 1e-4)) (<= d (+ high 1e-4)))
            (setq valid (cons p valid))))
        (b2_best_point valid headerPick)))
  )

  (defun b3_local_guide_from_pick (header guide headerPick guidePick radius spacing
                                 / pieces joint d low high station points)
    ;; Limita a copia usada pelo OFFSET ao mesmo passe do FILLET. Somente
    ;; amostra pontos; nao altera a guia nem os helpers de corte de BOTA2.
    (setq pieces (b3_selected_guide_pieces guide guidePick)
          joint (b3_joint_on_selected_guide header guide headerPick pieces))
    (if joint
      (progn
        (setq d (b2_curve_dist_at_point guide joint)
              low (max (nth 2 (car pieces)) (- d radius))
              high (min (nth 3 (last pieces)) (+ d radius))
              station low)
        (while (< station (- high 1e-8))
          (setq points (cons (b3_pt3 (vlax-curve-getPointAtDist guide station)) points)
                station (+ station spacing)))
        (setq points (cons (b3_pt3 (vlax-curve-getPointAtDist guide high)) points))
        (if (> (length points) 1) (b3_lwpoly_open (reverse points) nil))))
  )

    (defun b3_analytic_fillet_ls (header guide headerPick guidePick cen cr anchor count fr spacing turnData
                               / joint dJoint dPick gsgn guideEnd dirKeep step travelMax pc pa pb da db
                                 u nrm len side a0 w wu disc sq root tt f pG dG vcf pCirc arcDir sweep
                                 radG arrTan tdir travel ext cands cand best nPieces pts k p filPts
                                 pGx copy parts tail arcEnt e
                                 ls dctr cph sph sgnA nc nopt pEx pFl t1v pFin guidePieces)
    ;; cen/cr = centro y radio del giro; fr = radio del fillet.
    ;; ls = longitud de la reta entre el final del giro y el inicio del fillet (*B3_LS*).
    (setq guidePieces (b3_selected_guide_pieces guide guidePick)
          joint (b3_joint_on_selected_guide header guide headerPick guidePieces))
    (cond
      ((not joint)
       (setq *BOTA3_FILLET_FAIL* "Nao foi possivel localizar o cruzamento cabeceira x guia.")
       nil
      )
      (T
       (setq dJoint    (b2_curve_dist_at_point guide joint)
             dPick     (b2_curve_dist_at_point guide guidePick)
             gsgn      (if (> dPick dJoint) 1.0 -1.0)
             guideEnd  (if (> gsgn 0.0)
                         (vlax-curve-getEndPoint guide)
                         (vlax-curve-getStartPoint guide))
             dirKeep   (- (nth 3 turnData))
             step      (/ (* 2.0 pi) count)
             travelMax (- (* 2.0 pi) (* 2.0 step) 1e-6)
             nPieces   0
             ls        (if *B3_LS* (max 0.0 *B3_LS*) 0.0)
             dctr      (sqrt (+ (* (+ cr fr) (+ cr fr)) (* ls ls)))
             cph       (/ (+ cr fr) dctr)
             sph       (/ ls dctr)
             cands     nil)

       ;; ---- Candidatos ------------------------------------------------
       (foreach pc guidePieces
         (setq pa  (car pc)
               pb  (cadr pc)
               da  (nth 2 pc)
               db  (nth 3 pc)
               len (distance pa pb)
               u   (b3_unit (b3_v- pb pa)))
         (if (and u (> len 1e-9)
                  (< (distance pa cen) (+ dctr fr len 1.0)))
           (progn
             (setq nPieces (1+ nPieces)
                   nrm     (b3_rot90ccw u))
             (foreach side '(1.0 -1.0)
               ;; Centro del fillet: paralela a la guia a distancia fr
               ;; y a distancia dctr del centro del giro.
               (setq a0   (b3_v+ pa (b3_v* (* side fr) nrm))
                     w    (b3_v- a0 cen)
                     wu   (b3_dot w u)
                     disc (- (* wu wu) (- (b3_dot w w) (* dctr dctr))))
               (if (>= disc -1e-9)
                 (progn
                   (setq sq (sqrt (max 0.0 disc)))
                   (foreach root (list (+ (- wu) sq) (- (- wu) sq))
                     (if (and (>= root -1e-6) (<= root (+ len 1e-6)))
                       (progn
                         (setq tt  (max 0.0 (min len root))
                               f   (b3_v+ a0 (b3_v* tt u))
                               pG  (b3_v+ pa (b3_v* tt u))
                               dG  (+ da (* (- db da) (/ tt len)))
                               vcf (b3_unit (b3_v- f cen)))
                         (if (and vcf (>= (* gsgn (- dG dJoint)) -1e-4))
                           (progn
                             ;; Tangente interna comun:
                             ;; P1 = cen + cr*nc (fin del giro)
                             ;; P2 = f - fr*nc   (inicio del fillet)
                             (setq nopt nil)
                             (foreach sgnA '(1.0 -1.0)
                               (setq nc  (b3_v+ (b3_v* cph vcf)
                                                (b3_v* (* sgnA sph) (b3_rot90ccw vcf)))
                                     pEx (b3_v+ cen (b3_v* cr nc))
                                     pFl (b3_v- f (b3_v* fr nc))
                                     t1v (if (> dirKeep 0.0) (b3_rot90ccw nc) (b3_rot90cw nc)))
                               (if (>= (b3_dot (b3_v- pFl pEx) t1v) (- ls 1e-6))
                                 (setq nopt (list pEx pFl))
                               )
                             )
                             (if nopt
                               (progn
                                 (setq pCirc  (car nopt)
                                       pFin   (cadr nopt)
                                       arcDir (- dirKeep)
                                       sweep  (b3_arc_delta_dir f pFin pG arcDir)
                                       travel (b3_arc_delta_dir cen anchor pCirc dirKeep)
                                       radG   (b3_unit (b3_v- pG f))
                                       arrTan (if (> arcDir 0.0) (b3_rot90ccw radG) (b3_rot90cw radG))
                                       tdir   (b3_v* gsgn u))
                                 (if (and (> sweep 1e-6) (<= sweep (+ pi 1e-6))
                                          (> travel 0.05) (<= travel travelMax)
                                          (> (b3_dot arrTan tdir) 0.999))
                                   (progn
                                     (setq ext (b3_fillet_externality cen cr f fr pFin pG arcDir))
                                     (setq cands
                                       (cons
                                         (list ext
                                               (+ (* cr travel) ls (* fr sweep))
                                               f pCirc pG arcDir sweep travel pFin)
                                         cands))
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

       (if (not cands)
         (progn
           (setq *BOTA3_FILLET_FAIL*
             (strcat "Nenhum fillet de raio " (rtos fr 2 3)
                     " com reta de " (rtos ls 2 3)
                     ", tangente ao giro e a guia no braco indicado (trechos avaliados: "
                     (itoa nPieces) ")."))
           nil
         )
         (progn
           ;; ---- Mejor candidato: max externalidad; empate -> menor recorrido
           (setq best (car cands))
           (foreach cand (cdr cands)
             (if (or (> (car cand) (+ (car best) 0.001))
                     (and (<= (abs (- (car cand) (car best))) 0.001)
                          (< (cadr cand) (cadr best))))
               (setq best cand)
             )
           )
           (setq f      (nth 2 best)
                 pCirc  (nth 3 best)
                 pG     (nth 4 best)
                 arcDir (nth 5 best)
                 travel (nth 7 best)
                 pFin   (nth 8 best))

           ;; ---- Giro (vertices del circulo) + RETA + fillet
           (setq pGx (b3_closest_point guide pG)
                 k   0
                 pts nil)
           (foreach p (nth 4 turnData)
             (if (< (* k step) (- travel 1e-6))
               (setq pts (cons p pts))
             )
             (setq k (1+ k))
           )
           (setq filPts (b3_arc_points_center f fr pFin pG arcDir spacing))
           ;; pCirc = fin del giro; pFin = inicio del fillet. Entre ambos queda la reta.
           (setq pts
             (append (reverse pts)
                     (if (> ls 1e-6) (list pCirc))
                     filPts))
           ;; El ultimo vertice pasa a ser exactamente el punto sobre la guia.
           (setq pts (append (reverse (cdr (reverse pts))) (list pGx)))
           (setq arcEnt (b3_lwpoly_styled pts header))

           ;; ---- Brazo conservado de la guia (conserva vertices y bulges)
           (setq copy  (b2_copy_entity guide)
                 parts (if copy (b2_split_copy_at_point copy pGx)))
           (setq tail
             (cond
               ((and (car parts)  (b3_end_on (car parts)  guideEnd)) (car parts))
               ((and (cadr parts) (b3_end_on (cadr parts) guideEnd)) (cadr parts))
             )
           )
           (foreach e parts
             (if (/= e tail) (b3_delete_ent e))
           )

           (if (and arcEnt tail)
             (progn
               (setq arcEnt (b3_join_chain (list arcEnt tail)))
               (if arcEnt (list arcEnt pGx)))
             (progn
               (setq *BOTA3_FILLET_FAIL* "Nao foi possivel separar o braco conservado da guia.")
               nil
             )
           )
         )
       )
      )
    )
  )

  (defun b3_analytic_fillet (header guide headerPick guidePick cen cr anchor count fr spacing turnData
                            / k lMax f res)
    ;; Reta automatica: k * radio de giro, reduciendo hasta que exista solucion.
    ;; Prueba 100%, 75%, 50%, 25% y 0% de la longitud objetivo.
    (setq k    (if *BOTA_RECTO_K* *BOTA_RECTO_K* 1.0)
          lMax (* k cr)
          f    1.0
          res  nil)
    (while (and (not res) (>= f 0.0))
      (setq *B3_LS* (* f lMax))
      (setq res
        (b3_analytic_fillet_ls header guide headerPick guidePick
                               cen cr anchor count fr spacing turnData))
      (if (not res)
        (setq f
          (cond
            ((> f 0.2) (- f 0.25))
            ((> f 0.0) 0.0)
            (T -1.0)
          )
        )
      )
    )
    (if res
      (progn
        (setq *BOTA3_FILLET_FAIL* nil)
        (prompt
          (strcat "\nReta entre curvas aplicada: " (rtos *B3_LS* 2 3)
                  " (objetivo " (rtos lMax 2 3) ")"))
      )
    )
    res
  )

  (defun b3_stage (header guide headerPick guidePick center radius anchor cutRef count filletRadius spacing outerRadius
                  / turnData turn output copy parts keep other outer result maneuverData exitPoint)
    (if (not (b3_validate_inputs header headerPick guide guidePick))
      nil
      (progn
        (setq turnData (b3_circle_gap_directional center radius anchor cutRef count nil))
        (setq turn (b3_track (car turnData)))
        (setq maneuverData (if turn (b3_analytic_fillet header guide headerPick guidePick center radius
                                                  anchor count filletRadius spacing turnData)))
        (setq output (car maneuverData) exitPoint (cadr maneuverData))
        (if (not output)
          (setq *BOTA3_FILLET_FAIL*
            (if *BOTA3_FILLET_FAIL*
              *BOTA3_FILLET_FAIL*
              "O raio de fillet nao cabe no braco indicado sem prolongar a guia ou alterar o giro."))
          (progn
            (setq copy (b2_copy_entity header) parts (if copy (b2_split_copy_at_point copy anchor)))
            (setq keep (if parts (b3_select_opposite_pside (car parts) (cadr parts) anchor (nth 4 turnData))))
            (setq other (if (= keep (car parts)) (cadr parts) (car parts)))
            (setq result (if keep (b3_join_chain (list output keep))))
            (if result (setq result (b3_apply_densification result anchor exitPoint)))
            (if (not result)
              (if (not *BOTA3_FILLET_FAIL*)
                (setq *BOTA3_FILLET_FAIL* "Nao foi possivel unir a cabeceira a manobra; os originais foram preservados."))
              (progn
                (setq outer (b3_track (b3_circle_entity center outerRadius 6)))
                (if outer (setq b3Outputs (list result outer other))
                  (setq *BOTA3_FILLET_FAIL* "Nao foi possivel criar a referencia externa."))))))))
    (if b3Outputs
      (progn
        ;; entdel permite restaurar o primeiro original se o segundo falhar.
        (setq b3Originals (list header guide))
        (if (and (entdel header) (entdel guide) (not (entget header)) (not (entget guide)))
          (setq b3Committed T)
          (setq *BOTA3_FILLET_FAIL* "Nao foi possivel substituir os originais."))))
    (if b3Committed b3Outputs nil)
  )

  (defun b3_pipeline (header guide headerPick guidePick center radius anchor cutRef count filletRadius spacing outerRadius
                      / b3Temps b3Outputs b3Originals b3Committed b2Temps saved pair doc mark result e)
    (_bota2_define_helpers)
    (setq *BOTA3_FILLET_FAIL* nil)
    (foreach pair '("CMDECHO" "OSMODE" "PEDITACCEPT")
      (setq saved (cons (cons pair (getvar pair)) saved)))
    (setq doc  (vla-get-ActiveDocument (vlax-get-acad-object)))
    (setq mark (vl-catch-all-apply 'vla-StartUndoMark (list doc)))
    (setvar "CMDECHO" 0)
    (setvar "OSMODE" 0)
    (setq result (vl-catch-all-apply 'b3_stage
      (list header guide headerPick guidePick center radius anchor cutRef count filletRadius spacing outerRadius)))
    (if (vl-catch-all-error-p result)
      (setq *BOTA3_FILLET_FAIL* (vl-catch-all-error-message result)))
    (if (not b3Committed)
      (foreach e b3Originals
        (if (not (entget e)) (vl-catch-all-apply 'entdel (list e)))))
    (foreach e (append b3Temps b2Temps)
      (if (not (and b3Committed (member e b3Outputs))) (b3_delete_ent e)))
    (foreach pair saved (setvar (car pair) (cdr pair)))
    (if (not (vl-catch-all-error-p mark)) (vla-EndUndoMark doc))
    (if b3Committed b3Outputs nil)
  )
)

(defun b3_command_body ()
  (_bota_session_pull)
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


  ;; Factor de la reta automatica entre giro y fillet (x radio de giro)
  (if (not *BOTA_RECTO_K*)      (setq *BOTA_RECTO_K* 1.0))

  (setq oldLuprec (getvar "LUPREC"))
  (setvar "LUPREC" 3)

  (prompt "\nBOTA3 - Manobra com base BOTA2 + FILLET automatico para linha guia.")
  (setq sel (entsel "\nSelecione a cabeceira perto da zona desejada: "))

  (if (not sel)
    (prompt "\nNenhuma cabeceira selecionada.")
    (progn

      (setq ent   (car sel))
      (setq pPick (b3_pt3 (trans (cadr sel) 1 0)))

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

          (setq sel (entsel "\nSelecione a linha guia: "))

          (if (not sel)
            (prompt "\nNenhuma linha guia selecionada.")
            (progn

              (setq guia      (car sel))
              (setq pGuiaPick (b3_pt3 (trans (cadr sel) 1 0)))
              ;; Referencia completa do clique, como em BOTA2. Misturar X da
              ;; cabecaria com Y da guia torna o lado dependente da orientacao.
              (setq pSide pGuiaPick)

              (if (not (b3_validate_inputs ent pCab guia pGuiaPick))
                (progn (prompt (strcat "\n" *BOTA3_FILLET_FAIL*)) (exit)))

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

                  (initget "C B R L")
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
                        " | Reta auto (x R giro)=" (rtos *BOTA_RECTO_K* 2 2)
                        " | Densificacao=" (if *BOTA3_DENSIFY* "Sim" "Nao")
                        " | Uniao completa=Sim"
                        "\nPressione Enter para continuar ou [R] raios / [C] gerais / [B] fillet / [L] reta: "
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
                          (progn (setq *BOTA_RGIRO* rGiro) (_bota_session_publish))
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
                          (progn (setq *BOTA_IMPL* tamImpl) (_bota_session_publish))
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
                          (progn (setq *BOTA_SEGURIDAD* seguridad) (_bota_session_publish))
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
                          (progn (setq *BOTA_DISTSEG* distSeg) (_bota_session_publish))
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
                          (progn (setq *BOTA_FILLET_R* filletR) (_bota_session_publish))
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
                          (progn (setq *BOTA_FILLET_SEG* filletDistSeg) (_bota_session_publish))
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
                          (progn (setq *BOTA_RGIRO* rGiro) (_bota_session_publish))
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
                          (progn (setq *BOTA_FILLET_R* filletR) (_bota_session_publish))
                        )
                      )
                    )

                    ((= cfg "L")
                      (progn
                        (setq tmpL
                          (getreal
                            (strcat
                              "\nFator da reta (x raio de giro, 0 = sem reta) <"
                              (rtos *BOTA_RECTO_K* 2 2)
                              ">: "
                            )
                          )
                        )
                        (if tmpL
                          (progn (setq *BOTA_RECTO_K* (max 0.0 tmpL)) (_bota_session_publish))
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

                      ;; Mesmo cruzamento e janela da cabecaria usados como
                      ;; referencia de BOTA2; o clique nao desloca a busca para
                      ;; a outra solucao do circulo.
                      (setq pJoint
                        (b3_joint_on_selected_guide ent guia pCab
                          (b3_selected_guide_pieces guia pGuiaPick)))
                      (setq guiaLocal
                        (b3_local_guide_from_pick ent guia pCab pGuiaPick radioTrabajo stepGuia)
                      )

                      (setq cabLocal
                        (if pJoint
                          (b3_local_poly_from_curve ent pJoint (* 2.0 tamImpl) stepCab))
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
                            (b3_offset_select cabLocal offCabDist pGuiaPick)
                          )

                          (setq offGuia
                            (b3_offset_select_opposite guiaLocal offGuiaDist pCab)
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
                              ;; Mesmo criterio de BOTA2: mais perto do cruzamento selecionado.
                              (setq pVert
                                (b3_intersection_best offCab offGuia pJoint)
                              )

                              ;; Borra auxiliares temporales que ya no usa el solver.
                              (b3_delete_ent offCab)
                              (b3_delete_ent offGuia)
                              (b3_delete_ent guiaLocal)

                              (if (not pVert)
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

                                                              ;; BOTA2 elige el centro mas cercano al cruce.
                                                              ;; La otra raiz puede invertir el giro aunque
                                                              ;; su tangencia este mas cerca del mouse.
                                                              (setq score (distance centro pJoint))

                                                              ;; La tangencia queda en la misma ventana
                                                              ;; de dos implementos a cada lado del cruce.
                                                              (if (<= (distance pTang pJoint) (* 2.0 tamImpl))
                                                                (setq candidates
                                                                  (cons
                                                                    (list
                                                                      score
                                                                      pTang
                                                                      centro
                                                                      (b2_opposite_point pTang pVert)
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

                                      ;; Mantem o criterio do centro usado por BOTA2.
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
                                          (setq pCutRef (b2_opposite_point pTang pVert))
                                          (if cabLocal (b3_delete_ent cabLocal))

                                          ;; Segmentacion base del circulo interno
                                          (setq nSegGiro (b3_nseg_inscribed rGiro distSeg))

                                          ;; Executa FILLET, recortes e uniao em copias.
                                          ;; O clique original na guia define o braco conservado.
                                          (setq giroData
                                            (b3_pipeline ent guia pCab pGuiaPick centro rGiro
                                              pTang pCutRef nSegGiro filletR filletDistSeg rBarra))
                                          (if giroData
                                            (prompt
                                              (strcat "\nBOTA3 concluido: cabeceira, giro, fillet e guia unidos."
                                                "\nRaio Interno: " (rtos rGiro 2 3)
                                                " - Raio Externo: " (rtos rBarra 2 3)
                                                " - Fillet: " (rtos filletR 2 3)))
                                            (prompt
                                              (strcat "\nBOTA3: "
                                                (if *BOTA3_FILLET_FAIL* *BOTA3_FILLET_FAIL* "Falha no fillet.")
                                                " Os originais foram preservados.")))
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
;; COMANDO BOTAFILLET
;; Fillet automatico entre cabeceira e linha, convertido em segmentos
;; ============================================================

(defun c:BOTAFILLET (/ *error* oldLuprec selCab selLinha entCab entLinha pPickCab pPickLinha
                  pSide pCabSel pLinhaSel cfg filletR filletDistSeg entFillet
                  entSegmentado lastBefore lastAfter entCab2 entCabFillet pCabFillet breakOk
                  pBreak cabParts guideParts entCabOther entGuideFillet entGuideOther
                  geom pTanGuide pTanCab pRealTanGuide pRealTanCab pCenter pts trimGuide trimCab
                  joinOk joinGuideOk joinCabOk joinGuideEnt joinCabEnt arcZ
                  guidePts cabPts mergedPts angleInternal autoAngle autoAngleDeg
                  autoRange manualMode modeError)

  (_bota_session_pull)
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

  (prompt "\nBOTAFILLET - Concordancia automatica entre cabeceira e linha, convertida em segmentos.")

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
                          (_bota_session_publish)
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

(defun c:B2 ()
  (c:BOTA2)
  (princ)
)

(defun c:B3 ()
  (c:BOTA3)
  (princ)
)

(defun c:BOTAF ()
  (c:BOTAFILLET)
  (princ)
)

(defun c:BF ()
  (c:BOTAFILLET)
  (princ)
)

(_bota_session_start)

(princ "\nComandos: BOTA | BOTA2 (B2) | BOTAM | BOTA3 (B3) | BOTAFILLET (BOTAF/BF) | BOTAC | BOTAH")
(princ "\n---------------------------------------------")

;; Abre a janela de ajuda automaticamente ao carregar
(if (not *BOTAHELP_SUPPRESS_STARTUP_HELP*) (_bota_show_help))

(princ)
