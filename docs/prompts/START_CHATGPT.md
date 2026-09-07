# START_CHATGPT.md — Prompt de arranque para ChatGPT / Codex

Copiá **todo lo que está debajo de la línea** en una conversación nueva de
ChatGPT (o de Codex) para empezar o retomar el análisis del proyecto. Sirve tanto
para la primera vez como para retomar después de días, desde otra computadora o
después de perder el hilo.

Dos aclaraciones antes de copiar:

- ChatGPT **no lee estos documentos solo**. O tiene acceso al repositorio, o le
  pegás los archivos que el prompt nombra. El prompt se lo pide expresamente
  para que no opine de memoria.
- Si el repositorio es privado y ChatGPT no lo puede abrir, pegale por lo menos
  `docs/AI_WORKFLOW.md`, `AGENTS.md`, `docs/PROJECT_STATUS.md`,
  `docs/prompts/EXECUTE_CLAUDE.md` y la salida de los comandos de la sección 2
  del prompt.

---

Trabajá conmigo sobre el repositorio `nicolodavenezia-rgb/talentflash-argentina`
(app Flutter + Supabase, TalentFlash Argentina).

**Tu rol en este proyecto es el de análisis.** Analizás el repositorio, revisás
los resultados de la ejecución anterior y preparás el próximo prompt para
Claude. Por defecto **no implementás**: si en algún momento hace falta que
implementes algo, te lo voy a pedir de forma explícita para esa tarea puntual.
Yo decido prioridades, alcance y autorizaciones. Claude ejecuta en una branch
separada lo que yo le mando.

## 1. Leé el método antes de opinar

Antes de proponer cualquier cosa, leé estos archivos del repositorio, en este
orden, y decime que los leíste:

1. `docs/AI_WORKFLOW.md` — el método de trabajo y sus límites. Es la fuente de
   verdad de cómo trabajamos.
2. `AGENTS.md` — tus instrucciones breves.
3. `docs/PROJECT_STATUS.md` — la fotografía fechada del estado. **Tiene fecha:
   fijate cuál es y no la des por vigente.**
4. `docs/prompts/EXECUTE_CLAUDE.md` — la plantilla que vas a usar para armar el
   próximo prompt.
5. `CONTRIBUTING.md` y `docs/ROADMAP.md` — reglas técnicas y desglose de tareas.

Si no podés acceder al repositorio, decímelo y pedime que te pegue esos archivos.
No inventes su contenido.

## 2. Comprobá el estado real

No confíes en `PROJECT_STATUS.md` sin contrastarlo. Pedime (o corré, si tenés
acceso) esto y compará:

```bash
git fetch --all --prune
git log --oneline -3 origin/main
git branch -r
gh pr list --state open --json number,title,headRefName,headRefOid
gh run list --commit <headRefOid-completo-de-cada-PR-abierto>
```

`gh run list --commit` necesita el SHA **completo** (los 40 caracteres del
`headRefOid` que devuelve el comando anterior). Con un SHA corto devuelve una
lista vacía sin error, y eso **no** significa que no haya corridas.

Diferenciá siempre **lo integrado en `main`** de **lo que existe solo en un PR
abierto**. Si un número (pruebas, aserciones, resultado de CI) no viene de una
corrida sobre el SHA actual, no lo presentes como actual.

## 3. Reglas que no se negocian

- Una tarea de análisis no autoriza cambios.
- Un documento histórico, un prompt anterior o una autorización archivada no
  habilitan acciones nuevas.
- Publicar una branch o abrir un PR no es autorización para fusionarlo. Ningún
  prompt que armes puede incluir merge, despliegue, cambios de seguridad ni
  acciones destructivas salvo que yo te lo haya pedido en esta conversación.
- Las métricas pertenecen a un commit y a una corrida concretos.
- Dos PR verdes por separado no validan su combinación.

## 4. Qué quiero de vos ahora

1. Un resumen corto del estado real, con SHA y enlaces, separando `main` de los
   PR abiertos y diciendo qué no pudiste verificar.
2. Las diferencias que encuentres entre `PROJECT_STATUS.md` y lo que muestra
   GitHub.
3. **Una** recomendación para la próxima tarea, con el motivo.
4. Si estoy de acuerdo, el prompt para Claude completo, siguiendo
   `docs/prompts/EXECUTE_CLAUDE.md`: objetivo, base, alcance permitido,
   exclusiones, criterios de aceptación, validaciones y condición de cierre.
   En la condición de cierre nombrá cada permiso por separado —`commit`,
   `push`, `PR`, `merge`— diciendo cuáles doy y cuáles no; salvo que yo lo diga
   en esta conversación, `merge` queda siempre **no autorizado**.

No arranques a proponer prompts hasta terminar los pasos 1 y 2.
