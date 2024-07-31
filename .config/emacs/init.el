;; -*- mode: elisp -*-
;;
;; ~/.config/emacs/init.el
;;
;; created on : 2024.07.30.
;; last update: 2024.07.31.


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;; global configurations
;;

;; encodings
(set-language-environment "UTF-8")
(setopt selection-coding-system 'utf-8)
(prefer-coding-system 'utf-8)
(set-default-coding-systems 'utf-8)
(set-terminal-coding-system 'utf-8)
(set-keyboard-coding-system 'utf-8)

;; title and menu bar
(column-number-mode t)
(global-display-line-numbers-mode t)
(size-indication-mode t)
(setq inhibit-startup-screen t)
(setq frame-title-format
      '((:eval (if (buffer-file-name)
                 (abbreviate-file-name (buffer-file-name))
                 "%b"))))
(setq scroll-margin 0
      scroll-conservatively 100000
      scroll-preserve-screen-position 1)
(tool-bar-mode 0)
(menu-bar-mode 0)

;; column and line numbers
(column-number-mode t)
(global-display-line-numbers-mode t)

;; tab width
(setq-default tab-width 4)

;; clean up whitespaces before saving
(add-hook 'before-save-hook 'whitespace-cleanup)

;; custom file location
(setq custom-file (expand-file-name "custom.el" user-emacs-directory))
(when (file-exists-p custom-file)
  (load custom-file))

;; highlight the current line
(global-hl-line-mode)

;; yes/no => y/n
(setopt use-short-answers t)

;; keep buffers up-to-date automatically
(global-auto-revert-mode t)

;; replace symbols with pretty ones
(global-prettify-symbols-mode t)

;; use tree-sitter
(require 'treesit)

;;
;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;; configurations for packages
;;

(require 'package)
(setq package-archives '(("melpa" . "https://melpa.org/packages/")
                         ("org" . "https://orgmode.org/elpa/")
                         ("elpa" . "https://elpa.gnu.org/packages/")))
(package-initialize)
(unless package-archive-contents
  (package-refresh-contents))

;; https://github.com/jwiegley/use-package
(unless (package-installed-p 'use-package)
  (package-install 'use-package))
(require 'use-package)
(setq use-package-always-ensure t)


;;;;;;;;;;;;;;;;
;; packages

;; https://github.com/rranelli/auto-package-update.el
(use-package auto-package-update
  :custom
  (auto-package-update-interval 7)
  (auto-package-update-prompt-before-update t)
  (auto-package-update-hide-results t)
  :config
  (auto-package-update-maybe)
  (auto-package-update-at-time "09:00"))

;; https://github.com/emacs-evil/evil
(use-package evil
  :demand t
  :bind (("<escape>" . keyboard-escape-quit))
  :init
  ;; allows for using cgn
  ;; (setq evil-search-module 'evil-search)
  (setq evil-want-keybinding nil)
  :config
  (evil-mode 1))

;; https://github.com/emacs-evil/evil-collection
(use-package evil-collection
  :after evil
  :config
  (setq evil-want-integration t)
  (evil-collection-init))

;; https://github.com/emacs-evil/evil-surround
(use-package evil-surround
  :config
  (global-evil-surround-mode 1))

;; https://github.com/emacscollective/no-littering
(use-package no-littering)

;; https://github.com/justbur/emacs-which-key
(use-package which-key
  :defer 0
  :diminish which-key-mode
  :config
  (which-key-mode)
  (setq which-key-idle-delay 1))

;; https://github.com/magit/magit
(use-package magit
  :commands magit-status
  :custom
  (magit-display-buffer-function #'magit-display-buffer-same-window-except-diff-v1))

;; https://github.com/dgutov/diff-hl
(use-package diff-hl
  :init
  (add-hook 'magit-pre-refresh-hook 'diff-hl-magit-pre-refresh)
  (add-hook 'magit-post-refresh-hook 'diff-hl-magit-post-refresh)
  :config
  (global-diff-hl-mode)
  (unless (window-system) ;; fringe not supported in terminals
	(diff-hl-margin-mode)))

;; https://github.com/Fuco1/smartparens
(use-package smartparens
  :ensure t
  :diminish smartparens-mode
  :config (progn
            (require 'smartparens-config)
            (smartparens-global-mode 1)
            (show-paren-mode t)))

;; https://github.com/joaotavora/yasnippet
(use-package yasnippet
  :ensure t)

;; https://github.com/emacs-lsp/lsp-mode
(use-package lsp-mode
  :ensure t
  :init
  (setq lsp-keymap-prefix "C-c l")  ;; Or 'C-l', 's-l'
  :commands (lsp lsp-deferred)
  :hook ( ;; NOTE: add `(XXX-mode . lsp-deferred)`s below
          (clojure-mode . lsp-deferred)
          (go-mode . lsp-deferred)
          (ruby-mode . lsp-deferred)

          ;; which-key integration
          (lsp-mode . lsp-enable-which-key-integration)))

;; https://github.com/emacs-lsp/lsp-ui
(use-package lsp-ui
  :ensure t
  :hook (lsp-mode . lsp-ui-mode)
  :custom
  (lsp-ui-doc-position 'bottom))

;; https://github.com/emacs-lsp/dap-mode
(use-package dap-mode)

;; https://github.com/company-mode/company-mode
(use-package company
  :ensure t
  :config (progn
            ;; don't add any dely before trying to complete thing being typed
            ;; the call/response to gopls is asynchronous so this should have little
            ;; to no affect on edit latency
            (setq company-idle-delay 0)
            ;; start completing after a single character instead of 3
            (setq company-minimum-prefix-length 1)
            ;; align fields in completions
            (setq company-tooltip-align-annotations t)))

;;
;;;;;;;;;;;;;;;;


;;;;;;;;;;;;;;;;
;; LSP/DAP packages

;; (clojure)

;; https://github.com/clojure-emacs/clojure-mode
(use-package clojure-mode
  :defer t
  :mode ("\\.\\(clj\\|cljc\\)\\'" . clojure-mode))

;; (golang)
;;
;; https://github.com/golang/tools/blob/master/gopls/doc/emacs.md

;; https://github.com/dominikh/go-mode.el
(use-package go-mode
  :defer t
  :ensure t
  :mode ("\\.go\\'" . go-mode)
  :after dap-mode
  :bind (
         ;; If you want to switch existing go-mode bindings to use lsp-mode/gopls instead
         ;; uncomment the following lines
         ;; ("C-c C-j" . lsp-find-definition)
         ;; ("C-c C-d" . lsp-describe-thing-at-point)
         )
  :hook ((go-mode . lsp-deferred)
         (before-save . lsp-format-buffer)
         (before-save . lsp-organize-imports))
  :config (progn
            (lsp-register-custom-settings
              '(("gopls.completeUnimported" t t)
                ("gopls.staticcheck" t t)))

            (setq lsp-gopls-staticcheck t)
            (setq lsp-eldoc-render-all t)
            (setq lsp-gopls-complete-unimported t)

            ;; https://emacs-lsp.github.io/dap-mode/page/configuration/#go
            (require 'dap-dlv-go)))

;; (ruby)

;; https://github.com/ruby/elisp
(use-package ruby-mode
  :defer t
  :mode ("\\.\\(?:cap\\|gemspec\\|irbrc\\|gemrc\\|rake\\|rb\\|ru\\|thor\\)\\'" . ruby-mode)
  :config (progn
			;; https://emacs-lsp.github.io/dap-mode/page/configuration/#ruby
			(require 'dap-ruby)))

;;
;;;;;;;;;;;;;;;;


;;
;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;; themes (https://emacsthemes.com/popular/index.html)
;;

;; https://github.com/n3mo/cyberpunk-theme.el
(use-package cyberpunk-theme)
(load-theme 'cyberpunk t)

;;
;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

