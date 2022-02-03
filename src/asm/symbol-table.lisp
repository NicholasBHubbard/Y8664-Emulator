;;;; This package exists to export the *SYMBOL-TABLE* special variable which
;;;; is a lexical closure that can be used to query and insert into the Y86-64
;;;; symbol table.

(defpackage symbol-table
  (:use #:cl)
  (:shadow #:symbol-name)
  (:export #:*symbol-table*
           #:symbol-name
           #:undefined-symbol
           #:duplicate-symbol))

(in-package #:symbol-table)

;;; ==================== Types ====================

(defun symbol-name-p (string)
  (cl-ppcre:scan "^[.a-zA-Z][-a-zA-Z0-9]*$" string))

(deftype symbol-name ()
  '(and string (satisfies symbol-name-p)))

(u:defstruct-read-only entry
  "The type of a single symbol table entry."
  (name  nil :type symbol-name)
  (type  nil :type keyword)
  (value nil :type (unsigned-byte 64)))

;;; ==================== Conditions ====================

(define-condition undefined-symbol (error)
  ((symbol-name :initarg :symbol-name :reader symbol-name :type symbol-name)
   (table :initarg :table :reader table :type hash-table))
  (:documentation "Condition signaled when trying to access a symbol that has not been defined."))

(define-condition duplicate-symbol (error)
  ((symbol-name :initarg :symbol-name :reader symbol-name :type symbol-name)
   (table :initarg :table :reader table :type hash-table))
  (:documentation "Condition signaled when trying to redefine an existing symbol."))

;;; ==================== Symbol Table Definition ====================

(defun init-symbol-table ()
  "Used to initialize the *SYMBOL-TABLE* global variable. This function should
not be exported. "
  (let ((symbol-table (make-hash-table)))
    
    (lambda (function-keyword &rest inputs)
      (case function-keyword
        
        (:entry-p
         ;; T iff (FIRST INPUTS) is the name of an entry in SYMBOL-TABLE
         (nth-value 1 (gethash (first inputs) symbol-table)))
        
        (:insert
         ;; Insert an entry into SYMBOL-TABLE with name, type, and value
         ;; inputted in that order. Signal a duplicate-symbol error if the
         ;; symbol has already been defined.
         (let* ((symbol-name (first inputs))
                (symbol-type (second inputs))
                (symbol-value (third inputs))
                (symbol-exists (nth-value 1 (gethash symbol-name symbol-table))))
           (if (not symbol-exists)
               (setf (gethash symbol-name symbol-table)
                     (make-entry :name symbol-name
                                 :type symbol-type
                                 :value symbol-value))
               (error 'duplicate-symbol :symbol-name symbol-name :table symbol-table))))

        (:symbol-value
         ;; The value of the symbol named (FIRST INPUTS).          
         (let* ((symbol-name (first inputs))
                (symbol-exists (nth-value 1 (gethash symbol-name symbol-table))))
           (if symbol-exists
               (entry-value (gethash symbol-name symbol-table))
               (error 'undefined-symbol :symbol-name symbol-name :table symbol-table))))
        
        (:symbol-type
         ;; The type of the symbol named (FIRST INPUTS)
         (let* ((symbol-name (first inputs))
                (symbol-exists (nth-value 1 (gethash symbol-name symbol-table))))
           (if symbol-exists
               (entry-type (gethash symbol-name symbol-table))
               (error 'undefined-symbol :symbol-name symbol-name :table symbol-table))))))))

(defparameter *symbol-table* (init-symbol-table)
  "Lexical closure over the symbol table that can be used to query and add
symbols.")
