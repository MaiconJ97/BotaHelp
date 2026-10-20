;; Load bota_help_v5_pt.lsp first. Run (b3t_run) in an EMPTY disposable drawing.
;; Uses desktop AutoCAD/Civil 3D ActiveX and real FILLET/BREAK/JOIN commands.
(defun b3t_check (label value)
  (write-line (strcat (if value "PASS: " "FAIL: ") label) b3tLog)
  (if (not value) (setq b3tFailures (1+ b3tFailures)))
)

(defun b3t_run (/ b3tLog b3tFailures header guide result savedHeader savedGuide errorResult)
  (vl-load-com)
  (_bota3_define_helpers)
  (_bota3_define_pipeline)
  (_bota2_define_helpers)
  (setq b3tFailures 0)
  (setq b3tLog (open (strcat (getvar "TEMPPREFIX") "bota3-native.log") "w"))
  (setq header (b3_lwpoly_open '((-100.0 0.0 0.0) (100.0 0.0 0.0)) nil))
  (setq guide (b3_lwpoly_open '((25.0 -50.0 0.0) (-50.0 100.0 0.0)) nil))
  (setq savedHeader (entget header) savedGuide (entget guide))
  (setq errorResult (vl-catch-all-apply 'b3_pipeline
    (list header guide '(-40.0 0.0 0.0) '(-30.0 60.0 0.0) '(0.0 10.0 0.0) 10.0
      '(0.0 0.0 0.0) '(1.0 0.0 0.0) (b3_nseg_inscribed 10.0 0.9) 25.0 1.5 28.289)))
  (if (vl-catch-all-error-p errorResult)
    (write-line (vl-catch-all-error-message errorResult) b3tLog)
    (setq result errorResult))
  (b3t_check "native fillet and complete join" result)
  (if *BOTA3_FILLET_FAIL* (write-line *BOTA3_FILLET_FAIL* b3tLog))
  (b3t_check "originals replaced only on success"
    (if result (and (not (entget header)) (not (entget guide)))
      (and (equal savedHeader (entget header)) (equal savedGuide (entget guide)))))
  (write-line (strcat "Failures: " (itoa b3tFailures)) b3tLog)
  (close b3tLog)
  (princ)
)
