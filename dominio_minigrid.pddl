;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; DOMINIO: MiniGrid-Lava
;;; Asignatura: Planificación Automática (MIARFID - UPV)
;;; Práctica 1 - Apartado a)
;;; Formulación: STRIPS puro afirmativo con :typing
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(define (domain minigrid-lava)
  (:requirements :strips :typing)

  (:types
    agent cell direction color - object
  )

  (:predicates
    ;; Ubicación y orientación de los agentes
    (at-agent ?a - agent ?c - cell)
    (facing ?a - agent ?d - direction)

    ;; Mano del agente (máximo 1 llave sostenida a la vez)
    (agent-holding ?a - agent ?col - color)
    (agent-hand-empty ?a - agent)

    ;; Estado de ocupación y transitabilidad de las celdas
    (clear ?c - cell)      ;; La celda no tiene ningún agente dentro (está libre)
    (passable ?c - cell)   ;; La celda es físicamente transitable (no pared, no lava, no llave en el suelo)

    ;; Topología estática del grid (conectividad dirigida)
    (next-cell ?from - cell ?to - cell ?dir - direction)

    ;; Matriz de giros válidos de 90 grados
    (can-turn ?d1 - direction ?d2 - direction)

    ;; Gestión afirmativa de llaves en el suelo
    (key-at ?c - cell ?col - color)

    ;; Gestión afirmativa de puertas
    (door-at ?c - cell ?col - color)
    (door-open ?c - cell)
    (door-closed ?c - cell)
    (door-locked ?c - cell)
  )

  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  ;; 1. Giro del Agente (Cambio de Orientación en 90 grados)
  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  (:action turn
    :parameters (?a - agent ?d_from - direction ?d_to - direction)
    :precondition (and
      (facing ?a ?d_from)
      (can-turn ?d_from ?d_to)
    )
    :effect (and
      (not (facing ?a ?d_from))
      (facing ?a ?d_to)
    )
  )

  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  ;; 2. Movimiento del Agente (Avance en la dirección encarada)
  ;; Requiere que la celda destino sea transitable (passable) y libre de agentes (clear).
  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  (:action move
    :parameters (?a - agent ?from - cell ?to - cell ?dir - direction)
    :precondition (and
      (at-agent ?a ?from)
      (facing ?a ?dir)
      (next-cell ?from ?to ?dir)
      (passable ?to)
      (clear ?to)
    )
    :effect (and
      (not (at-agent ?a ?from))
      (at-agent ?a ?to)
      (clear ?from)
      (not (clear ?to))
    )
  )

  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  ;; 3. Recoger Llave (Pick-up)
  ;; El agente está en una casilla adyacente encarando la llave y con mano vacía.
  ;; Al recoger la llave, dicha celda pasa a ser transitable (passable).
  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  (:action pick-key
    :parameters (?a - agent ?from - cell ?key-cell - cell ?dir - direction ?col - color)
    :precondition (and
      (at-agent ?a ?from)
      (facing ?a ?dir)
      (next-cell ?from ?key-cell ?dir)
      (key-at ?key-cell ?col)
      (agent-hand-empty ?a)
    )
    :effect (and
      (not (key-at ?key-cell ?col))
      (not (agent-hand-empty ?a))
      (agent-holding ?a ?col)
      (passable ?key-cell)
    )
  )

  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  ;; 4. Soltar Llave (Drop)
  ;; El agente deposita la llave en una casilla transitable frente a él.
  ;; La casilla vuelve a quedar obstruida por la llave (deja de ser passable).
  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  (:action drop-key
    :parameters (?a - agent ?from - cell ?target-cell - cell ?dir - direction ?col - color)
    :precondition (and
      (at-agent ?a ?from)
      (facing ?a ?dir)
      (next-cell ?from ?target-cell ?dir)
      (agent-holding ?a ?col)
      (passable ?target-cell)
    )
    :effect (and
      (not (agent-holding ?a ?col))
      (agent-hand-empty ?a)
      (key-at ?target-cell ?col)
      (not (passable ?target-cell))
    )
  )

  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  ;; 5. Desbloquear y Abrir Puerta con Llave (Unlock & Open)
  ;; El agente encara la puerta bloqueada (door-locked) y tiene la llave del mismo color.
  ;; La puerta pasa a estar abierta (door-open) y la celda se vuelve transitable (passable).
  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  (:action unlock-door
    :parameters (?a - agent ?from - cell ?door-cell - cell ?dir - direction ?col - color)
    :precondition (and
      (at-agent ?a ?from)
      (facing ?a ?dir)
      (next-cell ?from ?door-cell ?dir)
      (door-at ?door-cell ?col)
      (door-locked ?door-cell)
      (agent-holding ?a ?col)
    )
    :effect (and
      (not (door-locked ?door-cell))
      (door-open ?door-cell)
      (passable ?door-cell)
    )
  )

  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  ;; 6. Abrir Puerta sin Cerrojo (Open Door)
  ;; Pasa de estar cerrada (door-closed) a abierta (door-open) y transitable (passable).
  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  (:action open-door
    :parameters (?a - agent ?from - cell ?door-cell - cell ?dir - direction ?col - color)
    :precondition (and
      (at-agent ?a ?from)
      (facing ?a ?dir)
      (next-cell ?from ?door-cell ?dir)
      (door-at ?door-cell ?col)
      (door-closed ?door-cell)
    )
    :effect (and
      (not (door-closed ?door-cell))
      (door-open ?door-cell)
      (passable ?door-cell)
    )
  )

  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  ;; 7. Cerrar Puerta sin Llave (Close Door)
  ;; Pasa de open a closed (deja de ser passable). Requiere que la celda esté libre de agentes (clear).
  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  (:action close-door
    :parameters (?a - agent ?from - cell ?door-cell - cell ?dir - direction ?col - color)
    :precondition (and
      (at-agent ?a ?from)
      (facing ?a ?dir)
      (next-cell ?from ?door-cell ?dir)
      (door-at ?door-cell ?col)
      (door-open ?door-cell)
      (clear ?door-cell)
    )
    :effect (and
      (not (door-open ?door-cell))
      (door-closed ?door-cell)
      (not (passable ?door-cell))
    )
  )

  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  ;; 8. Cerrar Puerta con Llave (Lock Door)
  ;; Pasa de closed a locked. Requiere tener la llave y que la celda esté libre de agentes (clear).
  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  (:action lock-door
    :parameters (?a - agent ?from - cell ?door-cell - cell ?dir - direction ?col - color)
    :precondition (and
      (at-agent ?a ?from)
      (facing ?a ?dir)
      (next-cell ?from ?door-cell ?dir)
      (door-at ?door-cell ?col)
      (door-closed ?door-cell)
      (agent-holding ?a ?col)
      (clear ?door-cell)
    )
    :effect (and
      (not (door-closed ?door-cell))
      (door-locked ?door-cell)
    )
  )
)
