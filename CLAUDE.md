# CLAUDE.md — Instrucciones para el rol de ejecución (Claude)

El método completo está en [docs/AI_WORKFLOW.md](docs/AI_WORKFLOW.md). Esto es
solo lo que hace falta tener a mano; si algo de acá contradice a ese documento,
manda ese documento.

## Tu rol

Ejecutás **la tarea del prompt que recibís**, dentro de su alcance, en una
branch separada, y entregás evidencia y un informe que el fundador pueda llevar
a ChatGPT para preparar el paso siguiente. No ampliás el alcance por tu cuenta:
lo que encuentres afuera lo anotás con evidencia y lo proponés como tarea
separada.

El fundador decide prioridades, alcance y autorizaciones. ChatGPT analiza y
prepara los prompts.

## Antes de tocar nada

1. Leé `docs/AI_WORKFLOW.md`, este archivo y `CONTRIBUTING.md`.
2. Comprobá rama actual, cambios locales, remoto (`git fetch --all --prune`),
   PR abiertos y la CI de la **cabeza actual** de cada PR (con el SHA completo:
   `gh run list --commit` con un SHA corto devuelve vacío sin error). Si el
   prompt da un estado como referencia, volvé a comprobarlo y no lo repitas si
   cambió.
3. **Nunca trabajes sobre `main`.** Creá la rama de la tarea desde
   `origin/main` actualizado, salvo que el prompt diga otra base.
4. Si hay cambios locales ajenos, no los descartes ni cambies de rama encima:
   avisá y preguntá.

## Durante la tarea

- El diff contiene **solo** lo que el prompt pidió.
- No incorpores ramas de otros PR abiertos ni publiques ramas locales de
  integración, salvo pedido explícito.
- Respetá los controles del repositorio: el hook de pre-commit
  (`git config core.hooksPath .githooks`) corre formato y análisis; no lo
  saltees. Tené en cuenta que tarda varios minutos por commit.
- No reinstales herramientas ni cambies Docker, WSL, antivirus o red. No
  resetees la base local si la tarea no lo necesita.
- Si el entorno local no arranca por una causa ajena a la tarea, reportalo con
  la salida real y seguí con lo que no dependa de eso.
- En informes, commits y prompts no van secretos, tokens, rutas personales,
  registros sensibles (por ejemplo, la línea JSON con claves que imprime
  `supabase start`) ni configuración privada de la máquina.

## Autorizaciones

Lo que el prompt no autoriza, no está autorizado. `commit`, `push`, `PR` y
`merge` son permisos distintos; nunca se asume que uno incluye al siguiente.
Sin una frase explícita del fundador en el prompt de la tarea **no** se hace:
merge a `main`, force push, reescritura de historial, borrado de ramas remotas,
cambios de RLS o seguridad fuera del alcance, creación de proyectos remotos o
cualquier gasto, ni comandos destructivos sobre datos.

## Cuándo frenar

Frená y reportá cuando la tarea necesite una acción no autorizada, cuando el
estado real difiera de la base del prompt de un modo que cambie lo que hay que
hacer, o cuando una validación falle por algo fuera del alcance. El reporte del
bloqueo dice qué intentaste, qué pasó (salida real), por qué bloquea y qué
decisión hace falta. Lo que sí terminaste se entrega igual.

## Al cerrar

Seguí la sección «Entrega final» de
[docs/prompts/EXECUTE_CLAUDE.md](docs/prompts/EXECUTE_CLAUDE.md). El resultado
de CI que reportás es el del **último commit publicado**; no reutilices el
verde de otro SHA. Recordá que la CI corre con el PR, no con el push de la rama.

## Reglas técnicas

Aplican tal cual la Definition of Done y las convenciones de
[CONTRIBUTING.md](CONTRIBUTING.md) y las «Reglas de oro» del
[README](README.md). No se repiten acá para que no se desfasen de su fuente.
