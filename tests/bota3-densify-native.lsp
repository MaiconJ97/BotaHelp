;; Load the main LSP, then run (b3dt_run) in an EMPTY disposable desktop drawing.
;; Exercises actual ActiveX insertion, bulges, widths and transactional cleanup.
(defun b3dt_check (label value)
  (write-line (strcat (if value "PASS: " "FAIL: ") label) b3dtLog)
  (if (not value) (setq b3dtFailures (1+ b3dtFailures)))
)

(defun b3dt_fixture (reversed / points e obj)
  (setq points '((-20.0 0.0 0.0) (0.0 0.0 0.0) (10.0 10.0 0.0)
                 (10.0 30.0 0.0) (0.0 40.0 0.0) (-20.0 40.0 0.0)))
  (setq e (b3_lwpoly_open (if reversed (reverse points) points) 3))
  (setq obj (vlax-ename->vla-object e))
  (vla-SetBulge obj 1 (* (if reversed -1.0 1.0) (/ (sin (/ pi 8.0)) (cos (/ pi 8.0)))))
  (vla-SetBulge obj 3 (* (if reversed -1.0 1.0) (/ (sin (/ pi 8.0)) (cos (/ pi 8.0)))))
  (vla-SetWidth obj 1 0.2 0.6)
  e
)

(defun b3dt_cases (/ b3Temps b2Temps e reversed before total result samples d p valid
                     entry exitPoint low high idx n a b widthStart widthEnd obj snapshot
                     header guide originalHeader originalGuide beforeCount pipelineResult
                     *BOTA3_DENSIFY* *BOTA_TRANS_L* *BOTA3_DENSIFY_SEG* *BOTA3_DENSIFY_MIN* *BOTA_RECTO_K*)
  (setq *BOTA3_DENSIFY* T *BOTA_TRANS_L* 5.0 *BOTA3_DENSIFY_SEG* 1.0
        *BOTA3_DENSIFY_MIN* 0.0 *BOTA_RECTO_K* 1.0)
  (foreach reversed '(nil T)
    (setq e (b3dt_fixture reversed) total (b2_curve_total_length e) samples nil d 0.0)
    (while (< d total)
      (setq samples (cons (list d (vlax-curve-getPointAtDist e d)) samples) d (+ d 0.37)))
    (setq entry '(0.0 0.0 0.0) exitPoint '(0.0 40.0 0.0))
    (setq low (- (min (b2_curve_dist_at_point e entry) (b2_curve_dist_at_point e exitPoint)) 5.0)
          high (+ (max (b2_curve_dist_at_point e entry) (b2_curve_dist_at_point e exitPoint)) 5.0))
    (setq result (b3_apply_densification e entry exitPoint))
    (b3dt_check "densification succeeds in either orientation" result)
    (setq valid T)
    (foreach p samples
      (if (not (equal (cadr p) (vlax-curve-getPointAtDist e (car p)) 1e-6)) (setq valid nil)))
    (b3dt_check "all sampled points and arc length preserved"
      (and valid (equal total (b2_curve_total_length e) 1e-6)))
    (b3dt_check "whole maneuver and both margins satisfy one metre spacing"
      (b3_density_valid_p e low high 1.0))
    (b3dt_check "outside segments and exact boundary vertices preserved"
      (and (equal (vlax-curve-getPointAtParam e 1)
                  (if reversed '(-5.0 40.0 0.0) '(-5.0 0.0 0.0)) 1e-6)
           (equal (vlax-curve-getPointAtParam e (1- (fix (vlax-curve-getEndParam e))))
                  (if reversed '(-5.0 0.0 0.0) '(-5.0 40.0 0.0)) 1e-6)))
    (setq valid T idx 0 n (fix (vlax-curve-getEndParam e)) obj (vlax-ename->vla-object e))
    (repeat n
      (setq a (vlax-curve-getDistAtParam e idx) b (vlax-curve-getDistAtParam e (1+ idx)))
      (if (<= (- b a) 1e-8) (setq valid nil))
      ;; Original segment 1 has a width ramp, independent of its orientation.
      (if (and (>= a (- 20.0 1e-6)) (<= b (+ 20.0 (* 5.0 pi) 1e-6)))
        (progn
          (vla-GetWidth obj idx 'widthStart 'widthEnd)
          (if (not (and
              (equal widthStart (+ 0.2 (* 0.4 (/ (- a 20.0) (* 5.0 pi)))) 1e-6)
              (equal widthEnd (+ 0.2 (* 0.4 (/ (- b 20.0) (* 5.0 pi)))) 1e-6)))
            (setq valid nil))))
      (setq idx (1+ idx)))
    (b3dt_check "no duplicate vertices and width interpolation preserved" valid)
    (setq snapshot (entget e) *BOTA3_DENSIFY* nil)
    (b3dt_check "disabled densification changes nothing"
      (and (= e (b3_apply_densification e nil nil)) (equal snapshot (entget e))))
    (setq *BOTA3_DENSIFY* T)
    (b3_delete_ent e))

  (setq e (b3_lwpoly_open '((0.0 0.0 0.0) (3.7 0.0 0.0)) nil))
  (b3dt_check "short available arms are clipped, never extended"
    (and (b3_apply_densification e '(1.0 0.0 0.0) '(2.5 0.0 0.0))
         (equal (b2_curve_total_length e) 3.7 1e-8) (b3_density_valid_p e 0.0 3.7 1.0)))
  (b3_delete_ent e)
  (setq e (b3dt_fixture nil) *BOTA_TRANS_L* 0.0)
  (b3dt_check "zero margin densifies only the maneuver"
    (and (b3_apply_densification e '(0.0 0.0 0.0) '(0.0 40.0 0.0))
         (equal (vlax-curve-getPointAtParam e 1) '(0.0 0.0 0.0) 1e-6)))
  (b3_delete_ent e)

  ;; Native DXF rewrite with real bulges and width ramps, in either direction.
  (setq *BOTA_TRANS_L* 5.0 *BOTA3_DENSIFY_MIN* 0.8 *BOTA3_DENSIFY_SEG* 1.5)
  (foreach reversed '(nil T)
    (setq e (b3dt_fixture reversed) total (b2_curve_total_length e) samples nil d 0.0)
    (while (< d total)
      (setq samples (cons (list d (vlax-curve-getPointAtDist e d)) samples) d (+ d 0.37)))
    (setq entry '(0.0 0.0 0.0) exitPoint '(0.0 40.0 0.0)
          low (- (min (b2_curve_dist_at_point e entry) (b2_curve_dist_at_point e exitPoint)) 5.0)
          high (+ (max (b2_curve_dist_at_point e entry) (b2_curve_dist_at_point e exitPoint)) 5.0))
    (b3dt_check "native 0.8..1.5 range succeeds in either direction"
      (and (b3_apply_densification e entry exitPoint) (b3_density_range_valid_p e low high 0.8 1.5)))
    (setq valid T)
    (foreach p samples
      (if (not (equal (cadr p) (vlax-curve-getPointAtDist e (car p)) 1e-6)) (setq valid nil)))
    (b3dt_check "range preserves native curved path and length"
      (and valid (equal total (b2_curve_total_length e) 1e-6)))
    (setq obj (vlax-ename->vla-object e) idx 0 n (fix (vlax-curve-getEndParam e)) valid T)
    (repeat n
      (setq a (vlax-curve-getDistAtParam e idx) b (vlax-curve-getDistAtParam e (1+ idx)))
      (if (and (>= a (- 20.0 1e-6)) (<= b (+ 20.0 (* 5.0 pi) 1e-6)))
        (progn
          (vla-GetWidth obj idx 'widthStart 'widthEnd)
          (if (not (and
              (equal widthStart (+ 0.2 (* 0.4 (/ (- a 20.0) (* 5.0 pi)))) 1e-6)
              (equal widthEnd (+ 0.2 (* 0.4 (/ (- b 20.0) (* 5.0 pi)))) 1e-6)))
            (setq valid nil))))
      (setq idx (1+ idx)))
    (b3dt_check "range preserves native width interpolation" valid)
    (b3_delete_ent e))
  (setq e (b3_lwpoly_open '((0.0 0.0 0.0) (0.2 0.0 0.0) (0.4 0.0 0.0) (3.7 0.0 0.0)) nil))
  (b3dt_check "close collinear vertices become three balanced segments"
    (and (b3_spacing_interval e 0.0 3.7 0.8 1.5) (= (fix (vlax-curve-getEndParam e)) 3)
         (b3_density_range_valid_p e 0.0 3.7 0.8 1.5)))
  (b3_delete_ent e)
  (setq e (b3_lwpoly_open '((0.0 0.0 0.0) (1.0 0.0 0.0) (1.0 0.4 0.0) (2.0 0.4 0.0)) nil)
        snapshot (entget e))
  (b3dt_check "a short corner stays unchanged while the maneuver continues"
    (and (b3_spacing_interval e 0.0 (b2_curve_total_length e) 0.8 1.5)
         *BOTA3_SPACING_SKIPPED*
         (equal (vlax-curve-getPointAtParam e 1) '(1.0 0.0 0.0) 1e-8)
         (equal (vlax-curve-getPointAtParam e 2) '(1.0 0.4 0.0) 1e-8)
         (b3_spacing_result_valid_p e 0.0 (b2_curve_total_length e) 0.8 1.5 *BOTA3_SPACING_SKIPPED*)))
  (b3_delete_ent e)

  ;; Real BOTA3 stage with acute angle and radius 25, including the new metadata.
  (setq *BOTA_TRANS_L* 5.0)
  (setq header (b3_lwpoly_open '((-100.0 0.0 0.0) (100.0 0.0 0.0)) nil)
        guide (b3_lwpoly_open '((25.0 -50.0 0.0) (-50.0 100.0 0.0)) nil))
  (setq pipelineResult (b3_pipeline header guide '(-40.0 0.0 0.0) '(-30.0 60.0 0.0)
    '(0.0 10.0 0.0) 10.0 '(0.0 0.0 0.0) '(1.0 0.0 0.0) (b3_nseg_inscribed 10.0 0.9) 25.0 1.5 28.289))
  (b3dt_check "complete acute-angle BOTA3 pipeline with radius 25 and 0.8..1.5 range" pipelineResult)
  (if (not pipelineResult) (write-line (if *BOTA3_FILLET_FAIL* *BOTA3_FILLET_FAIL* "No diagnostic") b3dtLog))
  (foreach e (append pipelineResult (list header guide)) (b3_delete_ent e))

  (setq header (b3_lwpoly_open '((-100.0 0.0 0.0) (100.0 0.0 0.0)) nil)
        guide (b3_lwpoly_open '((25.0 -50.0 0.0) (-50.0 100.0 0.0)) nil)
        originalHeader (entget header) originalGuide (entget guide)
        beforeCount (vla-get-Count (vla-get-ModelSpace (vla-get-ActiveDocument (vlax-get-acad-object))))
        *BOTA3_DENSIFY_SEG* 0.0)
  (setq pipelineResult (b3_pipeline header guide '(-40.0 0.0 0.0) '(-30.0 60.0 0.0)
    '(0.0 10.0 0.0) 10.0 '(0.0 0.0 0.0) '(1.0 0.0 0.0) (b3_nseg_inscribed 10.0 0.9) 25.0 1.5 28.289))
  (b3dt_check "density failure keeps originals and removes all staged entities"
    (and (not pipelineResult) (equal originalHeader (entget header)) (equal originalGuide (entget guide))
      (= beforeCount (vla-get-Count (vla-get-ModelSpace (vla-get-ActiveDocument (vlax-get-acad-object)))))))
  (foreach e (list header guide) (b3_delete_ent e))
)

(defun b3dt_run (/ b3dtLog b3dtFailures result saved pair doc)
  (vl-load-com)
  (setq doc (vla-get-ActiveDocument (vlax-get-acad-object)))
  (if (/= 0 (vla-get-Count (vla-get-ModelSpace doc)))
    (prompt "\nB3DT: use an empty disposable drawing.")
    (progn
      (_bota3_define_helpers) (_bota3_define_pipeline)
      (setq b3dtFailures 0 b3dtLog (open (strcat (getvar "TEMPPREFIX") "bota3-densify-native.log") "w"))
      (foreach pair '("CMDECHO" "OSMODE" "PEDITACCEPT" "LUPREC")
        (setq saved (cons (cons pair (getvar pair)) saved)))
      (setq result (vl-catch-all-apply 'b3dt_cases nil))
      (if (vl-catch-all-error-p result)
        (b3dt_check (vl-catch-all-error-message result) nil))
      (foreach pair saved
        (b3dt_check (strcat "system variable restored: " (car pair)) (= (cdr pair) (getvar (car pair)))))
      (write-line (strcat "Failures: " (itoa b3dtFailures)) b3dtLog)
      (close b3dtLog)))
  (princ)
)
