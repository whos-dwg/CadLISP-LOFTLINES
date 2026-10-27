; LOFTLINES_TWEEN_SAFE_V3.LSP
; Command: LOFTLINES
;
; Optimized interpolation rules:
;
; 1. LINE + LINE
;    -> Intermediate LINE entities.
;    -> Only start/end points are used.
;
; 2. Two-vertex straight LINE/POLYLINE combinations
;    -> Intermediate LWPOLYLINE entities with ONLY 2 vertices.
;    -> No unnecessary sampled vertices.
;
; 3. More complex LINE/POLYLINE combinations
;    -> Intermediate LWPOLYLINE.
;
; 4. If a true curved object is involved
;    -> Intermediate SPLINE.
;
; Internal names are unique to avoid collisions with older versions.

(vl-load-com)

(defun LTV3:CurveEntityP (ent / r)
  (if (and ent (= (type ent) 'ENAME))
    (progn
      (setq r
        (vl-catch-all-apply
          'vlax-curve-getEndParam
          (list ent)
        )
      )
      (not (vl-catch-all-error-p r))
    )
    nil
  )
)

(defun LTV3:SelectCurve (msg / pick ent done)
  (setq ent nil
        done nil)
  (while (not done)
    (setq pick (entsel msg))
    (cond
      ((null pick)
       (setq done T
             ent nil)
      )
      ((LTV3:CurveEntityP (car pick))
       (setq done T
             ent (car pick))
      )
      (T
       (prompt "\nSelected object is not a supported curve.")
      )
    )
  )
  ent
)

(defun LTV3:EntityType (ent / d)
  (if (and ent (= (type ent) 'ENAME))
    (progn
      (setq d (entget ent))
      (if d
        (cdr (assoc 0 d))
        nil
      )
    )
    nil
  )
)

(defun LTV3:LinearFamilyP (ent / typ)
  (setq typ (LTV3:EntityType ent))
  (or (= typ "LINE")
      (= typ "LWPOLYLINE")
      (= typ "POLYLINE"))
)

(defun LTV3:LWPolylineTwoVertexStraightP (ent / d n bulges ok)
  (setq d (entget ent))
  (if (and d
           (= (cdr (assoc 0 d)) "LWPOLYLINE")
           (= (cdr (assoc 90 d)) 2))
    (progn
      (setq bulges nil)
      (foreach x d
        (if (= (car x) 42)
          (setq bulges (cons (cdr x) bulges))
        )
      )
      (setq ok T)
      (foreach b bulges
        (if (> (abs b) 1e-12)
          (setq ok nil)
        )
      )
      ok
    )
    nil
  )
)

(defun LTV3:OldPolylineTwoVertexStraightP (ent / d flags v count ok vd b)
  (setq d (entget ent))
  (if (and d
           (= (cdr (assoc 0 d)) "POLYLINE"))
    (progn
      (setq flags (if (assoc 70 d) (cdr (assoc 70 d)) 0))
      ; Reject polygon meshes/polyface meshes.
      (if (/= 0 (logand flags (+ 16 64)))
        nil
        (progn
          (setq v (entnext ent)
                count 0
                ok T)
          (while (and v ok)
            (setq vd (entget v))
            (cond
              ((= (cdr (assoc 0 vd)) "VERTEX")
               (setq count (1+ count))
               (setq b (if (assoc 42 vd) (cdr (assoc 42 vd)) 0.0))
               (if (> (abs b) 1e-12)
                 (setq ok nil)
               )
              )
              ((= (cdr (assoc 0 vd)) "SEQEND")
               (setq v nil)
              )
            )
            (if v
              (setq v (entnext v))
            )
          )
          (and ok (= count 2))
        )
      )
    )
    nil
  )
)

(defun LTV3:SimpleStraightP (ent / typ)
  (setq typ (LTV3:EntityType ent))
  (cond
    ((= typ "LINE") T)
    ((= typ "LWPOLYLINE")
     (LTV3:LWPolylineTwoVertexStraightP ent))
    ((= typ "POLYLINE")
     (LTV3:OldPolylineTwoVertexStraightP ent))
    (T nil)
  )
)

(defun LTV3:CurveLength (ent / ep d)
  (setq ep
    (vl-catch-all-apply
      'vlax-curve-getEndParam
      (list ent)
    )
  )
  (if (vl-catch-all-error-p ep)
    nil
    (progn
      (setq d
        (vl-catch-all-apply
          'vlax-curve-getDistAtParam
          (list ent ep)
        )
      )
      (if (vl-catch-all-error-p d)
        nil
        d
      )
    )
  )
)

(defun LTV3:PointAtFraction (ent frac / len p)
  (setq len (LTV3:CurveLength ent))
  (if (and len (> len 1e-12))
    (progn
      (setq p
        (vl-catch-all-apply
          'vlax-curve-getPointAtDist
          (list ent (* len frac))
        )
      )
      (if (vl-catch-all-error-p p)
        nil
        p
      )
    )
    nil
  )
)

(defun LTV3:ReverseNeeded (e1 e2 / a0 a1 b0 b1 same cross)
  (setq a0 (LTV3:PointAtFraction e1 0.0)
        a1 (LTV3:PointAtFraction e1 1.0)
        b0 (LTV3:PointAtFraction e2 0.0)
        b1 (LTV3:PointAtFraction e2 1.0))
  (if (and a0 a1 b0 b1)
    (progn
      (setq same
        (+ (distance a0 b0)
           (distance a1 b1))
      )
      (setq cross
        (+ (distance a0 b1)
           (distance a1 b0))
      )
      (< cross same)
    )
    nil
  )
)

(defun LTV3:InterpPoint (p1 p2 tval)
  (list
    (+ (car p1)
       (* (- (car p2) (car p1)) tval))
    (+ (cadr p1)
       (* (- (cadr p2) (cadr p1)) tval))
    (+ (if (caddr p1) (caddr p1) 0.0)
       (* (- (if (caddr p2) (caddr p2) 0.0)
             (if (caddr p1) (caddr p1) 0.0))
          tval))
  )
)

(defun LTV3:AddLine (p1 p2)
  (if (and p1 p2 (> (distance p1 p2) 1e-12))
    (entmakex
      (list
        '(0 . "LINE")
        '(100 . "AcDbEntity")
        (cons 8 (getvar "CLAYER"))
        '(100 . "AcDbLine")
        (cons 10 p1)
        (cons 11 p2)
      )
    )
    nil
  )
)

(defun LTV3:AddLWPolyline (pts / data p)
  (if (>= (length pts) 2)
    (progn
      (setq data
        (list
          '(0 . "LWPOLYLINE")
          '(100 . "AcDbEntity")
          (cons 8 (getvar "CLAYER"))
          '(100 . "AcDbPolyline")
          (cons 90 (length pts))
          '(70 . 0)
        )
      )
      (foreach p pts
        (setq data
          (append
            data
            (list
              (cons 10 (list (car p) (cadr p)))
            )
          )
        )
      )
      (entmakex data)
    )
    nil
  )
)

(defun LTV3:RemoveConsecutiveDuplicates (pts / out p lastp)
  (setq out nil
        lastp nil)
  (foreach p pts
    (if (or (null lastp)
            (> (distance p lastp) 1e-10))
      (progn
        (setq out (cons p out))
        (setq lastp p)
      )
    )
  )
  (reverse out)
)

(defun LTV3:ActiveSpace (/ doc)
  (setq doc
    (vla-get-ActiveDocument
      (vlax-get-acad-object)
    )
  )
  (if (= 1 (getvar "CVPORT"))
    (vla-get-PaperSpace doc)
    (vla-get-ModelSpace doc)
  )
)

(defun LTV3:PointsToArray (pts / flat p arr)
  (setq flat nil)
  (foreach p pts
    (setq flat
      (append flat
        (list
          (float (car p))
          (float (cadr p))
          (float (if (caddr p) (caddr p) 0.0))
        )
      )
    )
  )
  (if flat
    (progn
      (setq arr
        (vlax-make-safearray
          vlax-vbDouble
          (cons 0 (1- (length flat)))
        )
      )
      (vlax-safearray-fill arr flat)
      arr
    )
    nil
  )
)

(defun LTV3:Vector (p1 p2)
  (list
    (- (car p2) (car p1))
    (- (cadr p2) (cadr p1))
    (- (if (caddr p2) (caddr p2) 0.0)
       (if (caddr p1) (caddr p1) 0.0))
  )
)

(defun LTV3:SafeVector (v)
  (if (and v
           (> (distance '(0.0 0.0 0.0) v) 1e-12))
    v
    '(1.0 0.0 0.0)
  )
)

(defun LTV3:AddSpline (space pts / arr sv ev result n)
  (setq n (length pts))
  (if (>= n 2)
    (progn
      (setq arr (LTV3:PointsToArray pts)
            sv
              (LTV3:SafeVector
                (LTV3:Vector
                  (car pts)
                  (cadr pts)))
            ev
              (LTV3:SafeVector
                (LTV3:Vector
                  (nth (- n 2) pts)
                  (nth (- n 1) pts))))
      (if arr
        (progn
          (setq result
            (vl-catch-all-apply
              'vla-AddSpline
              (list
                space
                arr
                (vlax-3d-point sv)
                (vlax-3d-point ev)
              )
            )
          )
          (if (vl-catch-all-error-p result)
            nil
            result
          )
        )
        nil
      )
    )
    nil
  )
)

(defun LTV3:BuildInterpolatedPoints
       (e1 e2 reverseFlag tval samples / j frac p1 p2 pts)
  (setq j 0
        pts nil)
  (repeat (1+ samples)
    (setq frac
      (/ (float j) (float samples))
    )
    (setq p1
      (LTV3:PointAtFraction e1 frac)
    )
    (setq p2
      (LTV3:PointAtFraction
        e2
        (if reverseFlag
          (- 1.0 frac)
          frac
        )
      )
    )
    (if (and p1 p2)
      (setq pts
        (cons
          (LTV3:InterpPoint p1 p2 tval)
          pts
        )
      )
    )
    (setq j (1+ j))
  )
  (LTV3:RemoveConsecutiveDuplicates
    (reverse pts)
  )
)

(defun LTV3:GetInterpolatedEnds
       (e1 e2 reverseFlag tval / a0 a1 b0 b1 p0 p1)
  (setq a0 (LTV3:PointAtFraction e1 0.0)
        a1 (LTV3:PointAtFraction e1 1.0)
        b0 (LTV3:PointAtFraction
             e2
             (if reverseFlag 1.0 0.0))
        b1 (LTV3:PointAtFraction
             e2
             (if reverseFlag 0.0 1.0)))
  (if (and a0 a1 b0 b1)
    (progn
      (setq p0 (LTV3:InterpPoint a0 b0 tval)
            p1 (LTV3:InterpPoint a1 b1 tval))
      (list p0 p1)
    )
    nil
  )
)

(defun c:LOFTLINES
       (/ *error* oldCmdecho e1 e2 count idx tval
          reverseFlag type1 type2 bothLines bothSimple
          polyMode samples pts ends space result made)

  (defun *error* (msg)
    (if oldCmdecho
      (setvar "CMDECHO" oldCmdecho)
    )
    (if (and msg
             (/= msg "Function cancelled")
             (/= msg "quit / exit abort"))
      (prompt
        (strcat "\nError: " msg)
      )
    )
    (princ)
  )

  (setq oldCmdecho (getvar "CMDECHO"))
  (setvar "CMDECHO" 0)

  (setq e1
    (LTV3:SelectCurve
      "\nSelect first boundary curve: "
    )
  )

  (if e1
    (progn
      (setq e2
        (LTV3:SelectCurve
          "\nSelect second boundary curve: "
        )
      )

      (cond
        ((null e2)
         nil
        )

        ((eq e1 e2)
         (prompt
           "\nThe two boundary curves must be different objects."
         )
        )

        (T
         (initget 6)
         (setq count
           (getint
             "\nNumber of intermediate curves <5>: "
           )
         )
         (if (null count)
           (setq count 5)
         )

         (setq type1 (LTV3:EntityType e1)
               type2 (LTV3:EntityType e2)
               bothLines
                 (and
                   (= type1 "LINE")
                   (= type2 "LINE"))
               bothSimple
                 (and
                   (LTV3:SimpleStraightP e1)
                   (LTV3:SimpleStraightP e2))
               polyMode
                 (and
                   (LTV3:LinearFamilyP e1)
                   (LTV3:LinearFamilyP e2))
               reverseFlag
                 (LTV3:ReverseNeeded e1 e2)
               samples 40
               space (LTV3:ActiveSpace)
               idx 1
               made 0)

         (repeat count
           (setq tval
             (/ (float idx)
                (float (1+ count)))
           )

           (cond
             ; LINE + LINE:
             ; exact LINE using only start/end.
             (bothLines
              (setq ends
                (LTV3:GetInterpolatedEnds
                  e1 e2 reverseFlag tval
                )
              )
              (if (and ends
                       (LTV3:AddLine
                         (car ends)
                         (cadr ends)))
                (setq made (1+ made))
              )
             )

             ; Straight two-vertex LINE/POLYLINE:
             ; exact 2-vertex LWPOLYLINE.
             (bothSimple
              (setq ends
                (LTV3:GetInterpolatedEnds
                  e1 e2 reverseFlag tval
                )
              )
              (if (and ends
                       (LTV3:AddLWPolyline ends))
                (setq made (1+ made))
              )
             )

             ; More complex LINE/POLYLINE:
             ; LWPOLYLINE using sampled geometry.
             (polyMode
              (setq pts
                (LTV3:BuildInterpolatedPoints
                  e1 e2 reverseFlag tval samples
                )
              )
              (if (LTV3:AddLWPolyline pts)
                (setq made (1+ made))
              )
             )

             ; True curved source object:
             ; SPLINE.
             (T
              (setq pts
                (LTV3:BuildInterpolatedPoints
                  e1 e2 reverseFlag tval samples
                )
              )
              (setq result
                (LTV3:AddSpline space pts)
              )
              (if result
                (progn
                  (vl-catch-all-apply
                    'vla-put-Layer
                    (list
                      result
                      (getvar "CLAYER"))
                  )
                  (setq made (1+ made))
                )
              )
             )
           )

           (setq idx (1+ idx))
         )

         (prompt
           (strcat
             "\nCreated "
             (itoa made)
             " intermediate object"
             (if (= made 1) "." "s.")
           )
         )
        )
      )
    )
  )

  (setvar "CMDECHO" oldCmdecho)
  (princ)
)

(princ
  "\nLOFTLINES V3 loaded. Type LOFTLINES to start."
)
(princ)
