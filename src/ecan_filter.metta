; ECAN Lightweight Cognitive Filter for MeTTaClaw
; Filters atomspace so MeTTaClaw's LLM only sees what's important.
; Uses direct &af space ops instead of full setSti/updateAf chain
; which segfaults under PeTTa's SWI-Prolog runtime.

!(bind! &af (new-space))

(= (initEcanFilter)
   (progn
     (change-state! &ecanDecay 0.7)
     (change-state! &ecanMaxAF 30)
     (println! "ECAN Cognitive Filter Initialized.")))

!(new-state &ecanDecay 0.7)
!(new-state &ecanMaxAF 30)

; Add a word to attentional focus with a score, or boost if already present
(= (stimulateAtom $word $boost)
   (let $existing (collapse (match &af ((Concept $word) $oldSti) $oldSti))
        (if (== $existing ())
            (add-atom &af ((Concept $word) $boost))
            (let* (($oldSti (car-atom $existing))
                   ($newSti (+ $oldSti $boost))
                   ($_ (remove-atom &af ((Concept $word) $oldSti))))
                  (add-atom &af ((Concept $word) $newSti))))))

; Process user message: tokenize, stimulate each word, and log
(= (processSensoryInput $msg)
   (let* (($tokens (py-call (helper.tokenize_text $msg)))
          ($_ (if (== $tokens ()) ()
                  (collapse (let $tok (superpose $tokens)
                                 (stimulateAtom $tok 500.0)))))
          ($afState (getWorkingMemory)))
         (py-call (helper.log_ecan_sensory $msg $tokens $afState))))

; Decay all AF entries (simple rent collection)
(= (decayAF)
   (let* (($entries (collapse (match &af ($atom $sti) ($atom $sti))))
          ($decay (get-state &ecanDecay)))
         (collapse (let $entry (superpose $entries)
                       (let* (($atom (car-atom $entry))
                              ($sti (car-atom (cdr-atom $entry)))
                              ($newSti (* $sti $decay))
                              ($_ (remove-atom &af ($atom $sti))))
                             (if (> $newSti 1.0)
                                 (add-atom &af ($atom $newSti))
                                 ()))))))

; Run one filter cycle: log decay transition
(= (runEcanFilterCycle)
   (catch (let* (($before (getWorkingMemory))
                 ($_ (decayAF))
                 ($after (getWorkingMemory)))
                (if (not (and (== $before "none") (== $after "none")))
                    (py-call (helper.log_ecan_decay $before $after))
                    ())) _ ()))

; Get current working memory: atoms in AF sorted by importance
(= (getWorkingMemory)
   (let $atoms (collapse (match &af ($atom $sti) ($atom $sti)))
        (if (== $atoms ())
            "none"
            (repr $atoms))))

; No-op for now — Hebbian needs full ECAN space ops
(= (runHebbianLearning) ())
