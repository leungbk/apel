;;; poe-18.el --- poe API implementation for Emacs 18.*

;; Copyright (C) 1995,1996,1997,1998,1999 Free Software Foundation, Inc.
;; Copyright (C) 1999 Yuuichi Teranishi

;; Author: MORIOKA Tomohiko <tomo@m17n.org>
;;	Shuhei KOBAYASHI <shuhei@aqua.ocn.ne.jp>
;;	Yuuichi Teranishi <teranisi@gohome.org>
;; Keywords: emulation, compatibility

;; This file is part of APEL (A Portable Emacs Library).

;; This program is free software; you can redistribute it and/or
;; modify it under the terms of the GNU General Public License as
;; published by the Free Software Foundation; either version 2, or (at
;; your option) any later version.

;; This program is distributed in the hope that it will be useful, but
;; WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
;; General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program; see the file COPYING.  If not, write to the
;; Free Software Foundation, Inc., 59 Temple Place - Suite 330,
;; Boston, MA 02111-1307, USA.

;;; Commentary:

;; Note to APEL developers and APEL programmers:
;;
;; If old (v18) compiler is used, top-level macros are expanded at
;; *load-time*, not compile-time. Therefore,
;;
;; (1) Definitions with `*-maybe' won't be compiled.
;;
;; (2) you cannot use macros defined with `defmacro-maybe' within function
;;     definitions in the same file.
;;     (`defmacro-maybe' is evaluated at load-time, therefore byte-compiler
;;      treats such use of macros as (unknown) functions and compiles them
;;      into function calls, which will cause errors at run-time.)
;;
;; (3) `eval-when-compile' and `eval-and-compile' are evaluated at
;;     load-time if used at top-level.

;;; Code:

(require 'pym)


;;; @ Compilation.
;;;

(defun defalias (sym newdef)
  "Set SYMBOL's function definition to NEWVAL, and return NEWVAL.
Associates the function with the current load file, if any."
  (fset sym newdef))

(defun byte-code-function-p (object)
  "Return t if OBJECT is a byte-compiled function object."
  (and (consp object)
       (let ((rest (cdr (cdr object)))
	     elt)
	 (if (stringp (car rest))
	     (setq rest (cdr rest)))
	 (catch 'tag
	   (while rest
	     (setq elt (car rest))
	     (if (and (consp elt)
		      (eq (car elt) 'byte-code))
		 (throw 'tag t))
	     (setq rest (cdr rest)))))))

;; (symbol-plist 'cyclic-function-indirection)
(put 'cyclic-function-indirection
     'error-conditions
     '(cyclic-function-indirection error))
(put 'cyclic-function-indirection
     'error-message
     "Symbol's chain of function indirections contains a loop")

;; The following function definition is a direct translation of its
;; C definition in emacs-20.4/src/data.c.
(defun indirect-function (object)
  "Return the function at the end of OBJECT's function chain.
If OBJECT is a symbol, follow all function indirections and return the final
function binding.
If OBJECT is not a symbol, just return it.
Signal a void-function error if the final symbol is unbound.
Signal a cyclic-function-indirection error if there is a loop in the
function chain of symbols."
  (let* ((hare object)
         (tortoise hare))
    (catch 'found
      (while t
        (or (symbolp hare) (throw 'found hare))
        (or (fboundp hare) (signal 'void-function (cons object nil)))
        (setq hare (symbol-function hare))
        (or (symbolp hare) (throw 'found hare))
        (or (fboundp hare) (signal 'void-function (cons object nil)))
        (setq hare (symbol-function hare))

        (setq tortoise (symbol-function tortoise))

        (if (eq hare tortoise)
            (signal 'cyclic-function-indirection (cons object nil)))))
    hare))

;;; Emulate all functions and macros of emacs-20.3/lisp/byte-run.el.
;;; (note: jwz's original compiler and XEmacs compiler have some more
;;;  macros; they are "nuked" by rms in FSF version.)

;; Use `*-maybe' here because new byte-compiler may be installed.
(put 'inline 'lisp-indent-hook 0)
(defmacro-maybe inline (&rest body)
  "Eval BODY forms sequentially and return value of last one.

This emulating macro does not support function inlining because old \(v18\)
compiler does not support inlining feature."
  (cons 'progn body))

(put 'defsubst 'lisp-indent-hook 'defun)
(put 'defsubst 'edebug-form-spec 'defun)
(defmacro-maybe defsubst (name arglist &rest body)
  "Define an inline function.  The syntax is just like that of `defun'.

This emulating macro does not support function inlining because old \(v18\)
compiler does not support inlining feature."
  (cons 'defun (cons name (cons arglist body))))

(defun-maybe make-obsolete (fn new)
  "Make the byte-compiler warn that FUNCTION is obsolete.
The warning will say that NEW should be used instead.
If NEW is a string, that is the `use instead' message.

This emulating function does nothing because old \(v18\) compiler does not
support this feature."
  (interactive "aMake function obsolete: \nxObsoletion replacement: ")
  fn)

(defun-maybe make-obsolete-variable (var new)
  "Make the byte-compiler warn that VARIABLE is obsolete,
and NEW should be used instead.  If NEW is a string, then that is the
`use instead' message.

This emulating function does nothing because old \(v18\) compiler does not
support this feature."
  (interactive "vMake variable obsolete: \nxObsoletion replacement: ")
  var)

(put 'dont-compile 'lisp-indent-hook 0)
(defmacro-maybe dont-compile (&rest body)
  "Like `progn', but the body always runs interpreted \(not compiled\).
If you think you need this, you're probably making a mistake somewhere."
  (list 'eval (list 'quote (if (cdr body) (cons 'progn body) (car body)))))

(put 'eval-when-compile 'lisp-indent-hook 0)
(defmacro-maybe eval-when-compile (&rest body)
  "Like progn, but evaluates the body at compile-time.

This emulating macro does not do compile-time evaluation at all because
of the limitation of old \(v18\) compiler."
  (cons 'progn body))

(put 'eval-and-compile 'lisp-indent-hook 0)
(defmacro-maybe eval-and-compile (&rest body)
  "Like progn, but evaluates the body at compile-time as well as at load-time.

This emulating macro does not do compile-time evaluation at all because
of the limitation of old \(v18\) compiler."
  (cons 'progn body))


;;; @ C primitives emulation.
;;;

(defun member (elt list)
  "Return non-nil if ELT is an element of LIST.  Comparison done with EQUAL.
The value is actually the tail of LIST whose car is ELT."
  (while (and list (not (equal elt (car list))))
    (setq list (cdr list)))
  list)

(defun delete (elt list)
  "Delete by side effect any occurrences of ELT as a member of LIST.
The modified LIST is returned.  Comparison is done with `equal'.
If the first member of LIST is ELT, deleting it is not a side effect;
it is simply using a different list.
Therefore, write `(setq foo (delete element foo))'
to be sure of changing the value of `foo'."
  (if list
      (if (equal elt (car list))
	  (cdr list)
	(let ((rest list)
	      (rrest (cdr list)))
	  (while (and rrest (not (equal elt (car rrest))))
	    (setq rest rrest
		  rrest (cdr rrest)))
	  (setcdr rest (cdr rrest))
	  list))))

(defun default-boundp (symbol)
  "Return t if SYMBOL has a non-void default value.
This is the value that is seen in buffers that do not have their own values
for this variable."
  (condition-case error
      (progn
	(default-value symbol)
	t)
    (void-variable nil)))

;;; @@ current-time.
;;;

(or (fboundp 'si:current-time-string)
    (fset 'si:current-time-string (symbol-function 'current-time-string)))
(defun current-time-string (&optional specified-time)
  "Return the current time, as a human-readable string.
Programs can use this function to decode a time,
since the number of columns in each field is fixed.
The format is `Sun Sep 16 01:03:52 1973'.
If an argument is given, it specifies a time to format
instead of the current time.  The argument should have the form:
  (HIGH . LOW)
or the form:
  (HIGH LOW . IGNORED).
Thus, you can use times obtained from `current-time'
and from `file-attributes'."
  (if (null specified-time)
      (si:current-time-string)
    (or (consp specified-time)
	(error "Wrong type argument %s" specified-time))
    (let ((high (car specified-time))
	  (low  (cdr specified-time))
	  (mdays '(31 28 31 30 31 30 31 31 30 31 30 31))
	  (mnames '("Jan" "Feb" "Mar" "Apr" "May" "Jun" 
		    "Jul" "Aug" "Sep" "Oct" "Nov" "Dec"))
	  (wnames '("Sun" "Mon" "Tue" "Wed" "Thu" "Fri" "Sat"))
	  days dd yyyy lyear mm HH MM SS)
      (if (consp low)
	  (setq low (car low)))
      (or (integerp high)
	  (error "Wrong type argument %s" high))
      (or (integerp low)
	  (error "Wrong type argument %s" low))
      (setq low (+ low 32400))
      (while (> low 65535)
	(setq high (1+ high)
	      low (- low 65536)))
      (setq yyyy 1970)
      (while (or (> high 481)
		 (and (= high 481)
		      (>= low 13184)))
	(if (and (> high 0)
		 (< low 13184))
	    (setq high (1- high)
		  low  (+ 65536 low)))
	(setq high (- high 481)
	      low  (- low 13184))
	(if (and (zerop (% yyyy 4))
		 (or (not (zerop (% yyyy 100)))
		     (zerop (% yyyy 400))))
	    (progn
	      (if (and (> high 0) 
		       (< low 20864))
		  (setq high (1- high)
			low  (+ 65536 low)))
	      (setq high (- high 1)
		    low (- low 20864))))
	(setq yyyy (1+ yyyy)))
      (setq dd 1)
      (while (or (> high 1)
		 (and (= high 1)
		      (>= low 20864)))
	(if (and (> high 0)
		 (< low 20864))
	    (setq high (1- high)
		  low  (+ 65536 low)))
	(setq high (- high 1)
	      low  (- low 20864)
	      dd (1+ dd)))
      (setq days dd)
      (if (= high 1)
	  (setq low (+ 65536 low)))
      (setq mm 0)
      (setq lyear (and (zerop (% yyyy 4))
		       (or (not (zerop (% yyyy 100)))
			   (zerop (% yyyy 400)))))
      (while (> (- dd (nth mm mdays)) 0)
	(if (and (= mm 1) lyear)
	    (setq dd (- dd 29))
	  (setq dd (- dd (nth mm mdays))))
	(setq mm (1+ mm)))
      (setq HH (/ low 3600)
	    low (% low 3600)
	    MM (/ low 60)
	    SS (% low 60))
      (format "%s %s %2d %02d:%02d:%02d %4d"
	      (nth (% (+ days
			 (- (+ (* (1- yyyy) 365) (/ (1- yyyy) 400) 
			       (/ (1- yyyy) 4)) (/ (1- yyyy) 100))) 7)
		   wnames)
	      (nth mm mnames)
	      dd HH MM SS yyyy))))

(defun current-time ()
  "Return the current time, as the number of seconds since 1970-01-01 00:00:00.
The time is returned as a list of three integers.  The first has the
most significant 16 bits of the seconds, while the second has the
least significant 16 bits.  The third integer gives the microsecond
count.

The microsecond count is zero on systems that do not provide
resolution finer than a second."
  (let* ((str (current-time-string))
	 (yyyy (string-to-int (substring str 20 24)))
	 (mm (length (member (substring str 4 7)
			     '("Dec" "Nov" "Oct" "Sep" "Aug" "Jul"
			       "Jun" "May" "Apr" "Mar" "Feb" "Jan"))))
	 (dd (string-to-int (substring str 8 10)))
	 (HH (string-to-int (substring str 11 13)))
	 (MM (string-to-int (substring str 14 16)))
	 (SS (string-to-int (substring str 17 19)))
	 dn ct1 ct2 i1 i2
	 year uru)
    (setq ct1 0 ct2 0 i1 0 i2 0)
    (setq year (- yyyy 1970))
    (while (> year 0)
      (setq year (1- year)
	    ct1 (+ ct1 481)
	    ct2 (+ ct2 13184))
      (while (> ct2 65535)
	(setq ct1 (1+ ct1)
	      ct2 (- ct2 65536))))
    (setq uru (- (+ (- (/ yyyy 4) (/ yyyy 100)) 
		    (/ yyyy 400)) 477))
    (while (> uru 0)
      (setq uru (1- uru)
	    i1 (1+ i1)
	    i2 (+ i2 20864))
      (if (> i2 65535)
	  (setq i1 (1+ i1)
		i2 (- i2 65536))))
    (setq ct1 (+ ct1 i1)
	  ct2 (+ ct2 i2))
    (while (> ct2 65535)
      (setq ct1 (1+ ct1)
	    ct2 (- ct2 65536)))
    (setq dn (+ dd (* 31 (1- mm))))
    (if (> mm 2)
	(setq dn (+ (- dn (/ (+ 23 (* 4 mm)) 10))
		    (if (and (zerop (% yyyy 4))
			     (or (not (zerop (% yyyy 100)))
				 (zerop (% yyyy 400))))
			1 0))))
    (setq dn (1- dn)
	  i1 0 
	  i2 0)
    (while (> dn 0)
      (setq dn (1- dn)
	    i1 (1+ i1)
	    i2 (+ i2 20864))
      (if (> i2 65535)
	  (setq i1 (1+ i1)
		i2 (- i2 65536))))
    (setq ct1 (+ (+ (+ ct1 i1) (/ ct2 65536)) 
		 (/ (+ (* HH 3600) (* MM 60) SS)
		    65536))
	  ct2 (+ (+ i2 (% ct2 65536))
		 (% (+ (* HH 3600) (* MM 60) SS)
		    65536)))
    (while (< (- ct2 32400) 0)
      (setq ct1 (1- ct1)
	    ct2 (+ ct2 65536)))
    (setq ct2 (- ct2 32400))
    (while (> ct2 65535)
      (setq ct1 (1+ ct1)
	    ct2 (- ct2 65536)))
    (list ct1 ct2 0)))

;;; @@ Floating point numbers.
;;;

(defalias 'numberp 'integerp)

(defun abs (arg)
  "Return the absolute value of ARG."
  (if (< arg 0) (- arg) arg))


;;; @ Basic lisp subroutines.
;;;

(defmacro lambda (&rest cdr)
  "Return a lambda expression.
A call of the form (lambda ARGS DOCSTRING INTERACTIVE BODY) is
self-quoting; the result of evaluating the lambda expression is the
expression itself.  The lambda expression may then be treated as a
function, i.e., stored as the function value of a symbol, passed to
funcall or mapcar, etc.

ARGS should take the same form as an argument list for a `defun'.
DOCSTRING is an optional documentation string.
 If present, it should describe how to call the function.
 But documentation strings are usually not useful in nameless functions.
INTERACTIVE should be a call to the function `interactive', which see.
It may also be omitted.
BODY should be a list of lisp expressions."
  ;; Note that this definition should not use backquotes; subr.el should not
  ;; depend on backquote.el.
  (list 'function (cons 'lambda cdr)))

(defun force-mode-line-update (&optional all)
  "Force the mode-line of the current buffer to be redisplayed.
With optional non-nil ALL, force redisplay of all mode-lines."
  (if all (save-excursion (set-buffer (other-buffer))))
  (set-buffer-modified-p (buffer-modified-p)))

;; (defalias 'save-match-data 'store-match-data)


;;; @ Basic editing commands.
;;;

;; 18.55 does not have this variable.
(defvar buffer-undo-list nil)

(defalias 'buffer-disable-undo 'buffer-flush-undo)

(defun generate-new-buffer-name (name &optional ignore)
  "Return a string that is the name of no existing buffer based on NAME.
If there is no live buffer named NAME, then return NAME.
Otherwise modify name by appending `<NUMBER>', incrementing NUMBER
until an unused name is found, and then return that name.
Optional second argument IGNORE specifies a name that is okay to use
\(if it is in the sequence to be tried\)
even if a buffer with that name exists."
  (if (get-buffer name)
      (let ((n 2) new)
	(while (get-buffer (setq new (format "%s<%d>" name n)))
	  (setq n (1+ n)))
	new)
    name))

(or (fboundp 'si:mark)
    (fset 'si:mark (symbol-function 'mark)))
(defun mark (&optional force)
  (si:mark))


;;; @@ Environment variables.
;;;

(autoload 'setenv "env"
  "Set the value of the environment variable named VARIABLE to VALUE.
VARIABLE should be a string.  VALUE is optional; if not provided or is
`nil', the environment variable VARIABLE will be removed.
This function works by modifying `process-environment'."
  t)


;;; @ File input and output commands.
;;;

(defvar data-directory exec-directory)

;; In 18.55, `call-process' does not return exit status.
(defun file-executable-p (filename)
  "Return t if FILENAME can be executed by you.
For a directory, this means you can access files in that directory."
  (if (file-exists-p filename)
      (let ((process (start-process "test" nil "test" "-x" filename)))
	(while (eq 'run (process-status process)))
	(zerop (process-exit-status process)))))

(defun make-directory-internal (dirname)
  "Create a directory. One argument, a file name string."
 (let ((dir (expand-file-name dirname)))
   (if (file-exists-p dir)
       (error "Creating directory: %s is already exist" dir)
     (call-process "mkdir" nil nil nil dir))))

(defun make-directory (dir &optional parents)
  "Create the directory DIR and any nonexistent parent dirs.
The second (optional) argument PARENTS says whether
to create parent directories if they don't exist."
  (let ((len (length dir))
	(p 0) p1 path)
    (catch 'tag
      (while (and (< p len) (string-match "[^/]*/?" dir p))
	(setq p1 (match-end 0))
	(if (= p1 len)
	    (throw 'tag nil))
	(setq path (substring dir 0 p1))
	(if (not (file-directory-p path))
	    (cond ((file-exists-p path)
		   (error "Creating directory: %s is not directory" path))
		  ((null parents)
		   (error "Creating directory: %s is not exist" path))
		  (t
		   (make-directory-internal path))))
	(setq p p1)))
    (make-directory-internal dir)))

(defun parse-colon-path (cd-path)
  "Explode a colon-separated list of paths into a string list."
  (and cd-path
       (let (cd-prefix cd-list (cd-start 0) cd-colon)
	 (setq cd-path (concat cd-path path-separator))
	 (while (setq cd-colon (string-match path-separator cd-path cd-start))
	   (setq cd-list
		 (nconc cd-list
			(list (if (= cd-start cd-colon)
				  nil
				(substitute-in-file-name
				 (file-name-as-directory
				  (substring cd-path cd-start cd-colon)))))))
	   (setq cd-start (+ cd-colon 1)))
	 cd-list)))

(defun file-relative-name (filename &optional directory)
  "Convert FILENAME to be relative to DIRECTORY (default: default-directory)."
  (setq filename (expand-file-name filename)
	directory (file-name-as-directory (expand-file-name
					   (or directory default-directory))))
  (let ((ancestor ""))
    (while (not (string-match (concat "^" (regexp-quote directory)) filename))
      (setq directory (file-name-directory (substring directory 0 -1))
	    ancestor (concat "../" ancestor)))
    (concat ancestor (substring filename (match-end 0)))))

(or (fboundp 'si:directory-files)
    (fset 'si:directory-files (symbol-function 'directory-files)))
(defun directory-files (directory &optional full match nosort)
  "Return a list of names of files in DIRECTORY.
There are three optional arguments:
If FULL is non-nil, return absolute file names.  Otherwise return names
 that are relative to the specified directory.
If MATCH is non-nil, mention only file names that match the regexp MATCH.
If NOSORT is dummy for compatibility."
  (si:directory-files directory full match))


;;; @ Text property.
;;;

;; In Emacs 20.4, these functions are defined in src/textprop.c.
(defun text-properties-at (position &optional object))
(defun get-text-property (position prop &optional object))
(defun get-char-property (position prop &optional object))
(defun next-property-change (position &optional object limit))
(defun next-single-property-change (position prop &optional object limit))
(defun previous-property-change (position &optional object limit))
(defun previous-single-property-change (position prop &optional object limit))
(defun add-text-properties (start end properties &optional object))
(defun put-text-properties (start end property &optional object))
(defun set-text-properties (start end properties &optional object))
(defun remove-text-properties (start end properties &optional object))
(defun text-property-any (start end property value &optional object))
(defun text-property-not-all (start end property value &optional object))
;; the following two functions are new in v20.
(defun next-char-property-change (position &optional object))
(defun previous-char-property-change (position &optional object))
;; the following two functions are obsolete.
;; (defun erase-text-properties (start end &optional object)
;; (defun copy-text-properties (start end src pos dest &optional prop)


;;; @ Overlay.
;;;

(cond
 ((boundp 'NEMACS)
  (defvar emu:available-face-attribute-alist
    '(
      ;;(bold      . inversed-region)
      (italic    . underlined-region)
      (underline . underlined-region)))

  ;; by YAMATE Keiichirou 1994/10/28
  (defun attribute-add-narrow-attribute (attr from to)
    (or (consp (symbol-value attr))
	(set attr (list 1)))
    (let* ((attr-value (symbol-value attr))
	   (len (car attr-value))
	   (posfrom 1)
	   posto)
      (while (and (< posfrom len)
		  (> from (nth posfrom attr-value)))
	(setq posfrom (1+ posfrom)))
      (setq posto posfrom)
      (while (and (< posto len)
		  (> to (nth posto attr-value)))
	(setq posto (1+ posto)))
      (if  (= posto posfrom)
	  (if (= (% posto 2) 1)
	      (if (and (< to len)
		       (= to (nth posto attr-value)))
		  (set-marker (nth posto attr-value) from)
		(setcdr (nthcdr (1- posfrom) attr-value)
			(cons (set-marker-type (set-marker (make-marker)
							   from)
					       'point-type)
			      (cons (set-marker-type
				     (set-marker (make-marker)
						 to)
				     nil)
				    (nthcdr posto attr-value))))
		(setcar attr-value (+ len 2))))
	(if (= (% posfrom 2) 0)
	    (setq posfrom (1- posfrom))
	  (set-marker (nth posfrom attr-value) from))
	(if (= (% posto 2) 0)
	    nil
	  (setq posto (1- posto))
	  (set-marker (nth posto attr-value) to))
	(setcdr (nthcdr posfrom attr-value)
		(nthcdr posto attr-value)))))

  (defalias 'make-overlay 'cons)

  (defun overlay-put (overlay prop value)
    (let ((ret (and (eq prop 'face)
		    (assq value emu:available-face-attribute-alist))))
      (if ret
	  (attribute-add-narrow-attribute (cdr ret)
					  (car overlay)(cdr overlay))))))
 (t
  (defun make-overlay (beg end &optional buffer type))
  (defun overlay-put (overlay prop value))))

(defun overlay-buffer (overlay))


;;; @ End.
;;;

(provide 'poe-18)

;;; poe-18.el ends here
