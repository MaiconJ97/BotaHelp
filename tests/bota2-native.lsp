;; Load the main LISP first. Run (b2t_run) ONLY in a disposable empty drawing
;; in desktop Civil 3D/AutoCAD. AcCoreConsole does not provide ActiveX objects.
(defun b2t_check (label value)
  (if value
    (prompt (strcat "\nB2TEST PASS: " label))
    (progn
      (setq b2tFailures (1+ b2tFailures))
      (prompt (strcat "\nB2TEST FAIL: " label))
    )
  )
)

(defun b2t_poly (points bulge / data index point)
  (setq data
    (list '(0 . "LWPOLYLINE") '(100 . "AcDbEntity") '(8 . "0")
          '(100 . "AcDbPolyline") (cons 90 (length points)) '(70 . 0)))
  (setq index 0)
  (foreach point points
    (setq data (append data
      (list (cons 10 point) (cons 42 (if (= index 0) bulge 0.0)))))
    (setq index (1+ index))
  )
  (entmakex data)
)

(defun b2t_cases
    (/ b2Temps b2Outputs b2Original b2Committed offsetError offsetComError
       offCab offGuia offCentro tmpExtCircle guiaLocal cabLocal
       arc shortGuide realGuide original work points reverseOrder
       ent guia pCab pGuiaPick tamImpl seguridad rGiro rBarra distSeg
       offsetData pVert pJoint usedVirtual centro pTang pCutRef nSegGiro
       manualSideMode pSide giroData entGiro entBarra entCabJoin joinOk
       *BOTA_CONECTAR_CAB* *BOTA_CORTAR_CIRCULO* connect cut savedGuide savedSnap result)
  (_bota2_define_helpers)
  (setq savedSnap (getvar "OSMODE"))
  (setq arc (b2t_poly '((-10.0 0.0) (10.0 0.0)) -1.0))
  (setq shortGuide (b2t_poly '((0.0 -1.0) (0.0 1.0)) 0.0))
  (setq realGuide (b2t_poly '((0.0 9.0) (0.0 11.0)) 0.0))
  (b2t_check "arc chord is not an intersection"
    (not (b2_intersection_best arc shortGuide '(0.0 0.0 0.0))))
  (b2t_check "native arc intersection"
    (equal (b2_intersection_best arc realGuide '(0.0 0.0 0.0)) '(0.0 10.0 0.0) 1e-4))
  (setq original (entget arc))
  (setq work (b2_header_temp_segment arc '(0.0 10.0 0.0) 5.0))
  (b2t_check "header local copy preserves arc length and tangency region"
    (and work (equal (b2_curve_total_length work) 10.0 1e-4)
         (b2_point_on_curve_p work '(0.0 10.0 0.0) 1e-4)))
  (b2t_check "header source unchanged by local preparation" (equal original (entget arc)))
  (b2_clear_temporaries)

  (setq points '((-20.0 0.0) (0.0 0.0) (10.0 0.0) (10.0 10.0) (-5.0 10.0)))
  (foreach reverseOrder '(nil T)
    (setq guia (b2t_poly (if reverseOrder (reverse points) points) 0.0))
    (setq original (entget guia))
    (setq work
      (b2_break_copy_keep_toward (b2_copy_entity guia)
        '(0.0 0.0 0.0) '(-5.0 10.0 0.0)))
    (b2t_check "returning guide retains clicked interval in both orientations"
      (and work (b2_point_on_curve_p work '(-5.0 10.0 0.0) 1e-4)
           (not (b2_point_on_curve_p work '(-20.0 0.0 0.0) 1e-4))))
    (b2t_check "guide source unchanged by local preparation" (equal original (entget guia)))
    (b2_clear_temporaries)
    (b2_delete_ent guia)
  )

  (foreach connect '(nil T)
    (foreach cut '(nil T)
      (setq ent (b2t_poly '((-100.0 0.0) (100.0 0.0)) 0.0))
      (setq guia (b2t_poly '((0.0 -100.0) (0.0 100.0)) 0.0))
      (setq savedGuide (entget guia))
      (setq pCab '(-20.0 0.0 0.0) pGuiaPick '(0.0 20.0 0.0))
      (setq tamImpl 36.578 seguridad 0.2 rGiro 10.0 distSeg 0.9)
      (setq *BOTA_CONECTAR_CAB* connect *BOTA_CORTAR_CIRCULO* cut)
      (setq b2Committed nil b2Original nil b2Outputs nil)
      (b2_run_simple)
      (b2t_check (strcat "full solver, connect=" (if connect "yes" "no")
                        ", cut=" (if cut "yes" "no"))
        (and b2Committed (not (entget ent)) entGiro (entget entGiro)
             entBarra (entget entBarra)))
      (b2t_check "guide original remains intact after maneuver" (equal savedGuide (entget guia)))
      (b2t_check "OSMODE unchanged" (= savedSnap (getvar "OSMODE")))
      (foreach result b2Outputs (b2_delete_ent result))
      (setq b2Committed nil b2Original nil b2Outputs nil)
      (b2_delete_ent ent)
      (b2_delete_ent guia)
    )
  )
  (b2_delete_ent arc)
  (b2_delete_ent shortGuide)
  (b2_delete_ent realGuide)
)

(defun b2t_run (/ b2tFailures result)
  (setq b2tFailures 0)
  (setq result (vl-catch-all-apply 'b2t_cases nil))
  (if (vl-catch-all-error-p result)
    (progn
      (setq b2tFailures (1+ b2tFailures))
      (prompt (strcat "\nB2TEST ERROR: " (vl-catch-all-error-message result)))
    )
  )
  (prompt (strcat "\nB2TEST FAILURES: " (itoa b2tFailures)))
  (princ)
)
