# Práctica 1: Modelado del Dominio y Problema "MiniGrid-Lava" en PDDL

**Asignatura:** Planificación Automática  
**Máster Universitario en Inteligencia Artificial, Reconocimiento de Formas e Imagen Digital (MIARFID) — UPV**  
**Autores:** Oliver Belando  
**Archivos implementados:**
- Dominio: [`dominio_minigrid.pddl`](./dominio_minigrid.pddl)
- Problema (Instancia base): [`problema_minigrid.pddl`](./problema_minigrid.pddl)

---

## 1. Apartado a) — Definición y Diseño del Dominio PDDL

En este apartado se ha formalizado el dominio **MiniGrid-Lava** en el archivo `dominio_minigrid.pddl`. El objetivo principal del diseño ha sido adherirse estrictamente al estándar **STRIPS clásico con tipado (`:strips :typing`)** enseñado en la asignatura, evitando extensiones innecesarias como `:negative-preconditions` o constructos que degraden el rendimiento de los planificadores (`Metric-FF`, `LPG`, `OPTIC`).

### 1.1. Jerarquía de Tipos (`:types`)
Se definen cuatro tipos principales que heredan del tipo raíz `object`:
* `agent`: Entidades móviles que ejecutan las acciones en el grid (`a1`, `a2`).
* `cell`: Coordenadas o casillas discretas de la cuadrícula (`c_0_0` .. `c_6_6`).
* `direction`: Orientaciones discretas en las que puede encarar un agente (`north`, `south`, `east`, `west`).
* `color`: Identificadores de color para relacionar unívocamente puertas y llaves (`red`, `blue`).

### 1.2. Predicados y Justificación Teórica (`:predicates`)
En lugar de codificar estados mediante variables de función o argumentos adicionales (como un tipo `door-status`), se ha optado por **predicados afirmativos específicos**:
1. **Posición y orientación:**
   - `(at-agent ?a - agent ?c - cell)`: Posición del agente `?a` en la casilla `?c`.
   - `(facing ?a - agent ?d - direction)`: Orientación actual del agente.
2. **Capacidad de carga:**
   - `(agent-holding ?a - agent ?col - color)`: El agente sostiene la llave de color `?col`.
   - `(agent-hand-empty ?a - agent)`: Mano libre. Modela de forma natural la restricción de que un agente sólo puede portar una llave simultáneamente.
3. **Control afirmativo de celdas:**
   - `(clear ?c - cell)`: Indica que la celda **no tiene un agente dentro**. Se emplea exactamente igual que en *Blocks-World* (`(clear ?b)`) o *Hanoi* (`(clear ?peg)`). Para que un agente entre a una celda, ésta debe ser `(clear ?to)`. Al entrar, la celda deja de ser `clear`, evitando colisiones entre agentes sin requerir precondiciones negativas como `(not (occupied ?to))`.
   - `(passable ?c - cell)`: Modela la transitabilidad física. Según el enunciado:
     - Una celda con pared o con lava **nunca es transitable**.
     - Una celda con llave o con puerta cerrada/bloqueada **tampoco es transitable**, pero puede volverse transitable de forma dinámica.
     - En consecuencia, en el estado inicial solo se marcan como `passable` aquellas celdas que están despejadas.
4. **Topología y relaciones estáticas:**
   - `(next-cell ?from - cell ?to - cell ?dir - direction)`: Relación orientada de vecindad ortogonal.
   - `(can-turn ?d1 - direction ?d2 - direction)`: Matriz que define los giros permitidos de 90° (Norte $\leftrightarrow$ Este/Oeste, Sur $\leftrightarrow$ Este/Oeste).
5. **Puertas y llaves:**
   - `(key-at ?c - cell ?col - color)`: Presencia de una llave en el suelo de una casilla.
   - `(door-at ?c - cell ?col - color)`: Asociación entre una celda y el color de su puerta.
   - `(door-open ?c - cell)`, `(door-closed ?c - cell)`, `(door-locked ?c - cell)`: Predicados unarios mutuamente excluyentes que representan el estado exacto de la puerta, simplificando los efectos de apertura/cierre.

### 1.3. Operadores Diseñados (`:action`)
Se han modelado 8 operadores para cubrir todo el comportamiento del enunciado:
1. **`turn`:**  
   - *Precondición:* El agente está en `?d_from` y existe la regla de giro `(can-turn ?d_from ?d_to)`.  
   - *Efecto:* Cambia la orientación a `?d_to` mediante `(facing ?a ?d_to)` y `(not (facing ?a ?d_from))`.
2. **`move`:**  
   - *Precondición:* El agente está en `?from`, encarado hacia `?dir`, `?to` es la casilla adyacente en esa dirección, `?to` es transitable `(passable ?to)` y no está ocupada por otro agente `(clear ?to)`.  
   - *Efecto:* Desplaza al agente a `?to`, libera la casilla origen `(clear ?from)` y ocupa la casilla destino `(not (clear ?to))`.
3. **`pick-key`:**  
   - *Precondición:* El agente se encuentra en una celda adyacente mirando hacia `?key-cell`, hay una llave `(key-at ?key-cell ?col)` y el agente tiene la mano vacía `(agent-hand-empty ?a)`.  
   - *Efecto:* El agente pasa a sostener la llave, deja de estar vacía su mano, la llave desaparece del suelo y, **fundamental según el enunciado**, la celda pasa a ser transitable `(passable ?key-cell)` al haberse retirado el obstáculo.
4. **`drop-key`:**  
   - *Precondición:* El agente sostiene la llave y mira hacia una celda transitable `?target-cell`.  
   - *Efecto:* Suelta la llave en el suelo `(key-at ?target-cell ?col)`, libera su mano `(agent-hand-empty ?a)` y la celda destino deja de ser transitable `(not (passable ?target-cell))`.
5. **`unlock-door`:**  
   - *Precondición:* El agente encara la celda de la puerta, la puerta tiene cerrojo `(door-locked ?door-cell)` y el agente sostiene la llave del color exacto `(agent-holding ?a ?col)`.  
   - *Efecto:* Elimina el cerrojo, abre la puerta `(door-open ?door-cell)` y convierte la casilla en transitable `(passable ?door-cell)`.
6. **`open-door`:**  
   - *Precondición:* El agente encara una puerta que está cerrada pero sin cerrojo `(door-closed ?door-cell)`.  
   - *Efecto:* La puerta pasa a estar abierta `(door-open ?door-cell)` y transitable `(passable ?door-cell)`.
7. **`close-door`:**  
   - *Precondición:* El agente encara una puerta abierta `(door-open ?door-cell)` y en dicha casilla no hay ningún agente dentro `(clear ?door-cell)`.  
   - *Efecto:* La puerta pasa a `(door-closed ?door-cell)` y deja de ser transitable `(not (passable ?door-cell))`.
8. **`lock-door`:**  
   - *Precondición:* El agente encara una puerta cerrada, tiene la llave del mismo color y la casilla está libre de agentes `(clear ?door-cell)`.  
   - *Efecto:* La puerta pasa a estar bloqueada con llave `(door-locked ?door-cell)`.

---