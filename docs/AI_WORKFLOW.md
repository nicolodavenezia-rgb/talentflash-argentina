# AI_WORKFLOW.md — Cómo trabajamos con ChatGPT y Claude

Este documento es la **fuente de verdad del método de trabajo**. Describe quién
decide, quién analiza, quién ejecuta y —sobre todo— dónde termina la
autorización de cada uno. Es un documento de reglas permanentes: no cuenta en
qué estado está el proyecto. Para eso está
[PROJECT_STATUS.md](PROJECT_STATUS.md), que es una fotografía fechada y se
vuelve vieja sola.

El método existe por un motivo concreto: el trabajo del proyecto se reparte
entre dos asistentes que **no comparten memoria** y entre computadoras que
tampoco. Lo único que sobrevive a una conversación cerrada, a un asistente
distinto o a una máquina nueva es lo que está versionado y publicado en el
repositorio. Por eso el método vive acá adentro y no en el historial de un chat.

---

## 1. Roles

### El fundador (la persona)

Decide **prioridades, alcance y autorizaciones**. Ninguna de las tres se delega.
En particular, son suyas y solo suyas las decisiones de:

- qué se hace ahora y qué se posterga;
- qué entra en una tarea y qué queda afuera;
- fusionar un PR, desplegar, cambiar reglas de seguridad, gastar dinero
  (servicios pagos, cuentas de stores, proyectos remotos);
- resolver las decisiones abiertas de producto y de negocio que el código deja
  marcadas como pendientes.

### ChatGPT / Codex — el rol de análisis

Analiza el repositorio, revisa los resultados de la ejecución anterior y
**prepara el próximo prompt**. Por defecto **no implementa**: mira, contrasta y
escribe la instrucción siguiente para que la ejecute Claude.

Puede implementar solamente cuando el fundador se lo pide de forma explícita
para esa tarea puntual. Que tenga acceso de escritura no es una autorización; la
autorización es una frase del fundador en el prompt de esa tarea.

### Claude — el rol de ejecución

Ejecuta **la tarea que recibe en el prompt**, dentro del alcance de ese prompt,
en una **branch separada**. Al terminar entrega evidencia y un informe que el
fundador pueda llevar a una conversación de ChatGPT para que prepare el paso
siguiente.

Claude no amplía el alcance por iniciativa propia. Si encuentra un problema
fuera de alcance, lo anota con evidencia y lo **propone como tarea separada**.

---

## 2. Los límites de autorización

Estas cuatro reglas son las que evitan que el método se degrade con el tiempo.
Valen para los dos asistentes.

1. **Una tarea de análisis no autoriza cambios.** «Revisá X» significa leer y
   reportar. Si de la revisión sale que hay que tocar algo, eso es la tarea
   siguiente, con su propio prompt.

2. **Un documento histórico, un prompt anterior o una autorización archivada no
   habilitan acciones nuevas.** Que el prompt de la semana pasada dijera «podés
   pushear» no autoriza el push de hoy. La autorización es del prompt en el que
   está escrita y muere con la tarea.

3. **Publicar una branch o abrir un PR no significa tener autorización para
   fusionarlo.** Son tres permisos distintos: `push`, `PR` y `merge`. Un prompt
   puede dar los dos primeros y no el tercero, y ese es el caso normal. El
   «→ merge» del flujo de [CONTRIBUTING.md](../CONTRIBUTING.md) describe el
   orden técnico de los pasos, no una autorización: la decisión de fusionar
   sigue siendo del fundador, PR por PR.

4. **Ante la duda, se frena y se pregunta.** Detenerse con la mitad hecha y una
   pregunta clara es un resultado aceptable. Inventar la autorización que falta
   no lo es.

Las acciones que **nunca** se hacen sin una frase explícita del fundador en el
prompt de la tarea: fusionar a `main`, forzar un push, reescribir historial,
borrar ramas remotas, tocar reglas de RLS o de seguridad por fuera del alcance
declarado, crear proyectos remotos o cualquier cosa que cueste plata, y
cualquier comando destructivo sobre datos. Resetear la base local
(`npm run db:reset`) es una operación normal de desarrollo cuando la tarea la
necesita; lo que no se hace es correrla «para probar» algo ajeno a la tarea o
para validar documentación, porque borra el estado local sin que el prompt lo
haya pedido.

---

## 3. El ciclo de una tarea

```
fundador  →  ChatGPT/Codex  →  fundador  →   Claude   →  fundador  →  ChatGPT/Codex
 decide       analiza el       revisa y      ejecuta      lee el       revisa y prepara
 qué sigue    repo y arma      autoriza      en branch    informe      el próximo prompt
              el prompt        el prompt     aparte
```

El fundador está en el medio de cada paso a propósito. No hay ningún tramo en el
que un asistente le pase trabajo directamente al otro sin que él lo lea.

---

## 4. Cómo se empieza una sesión

Vale para las dos puntas. Antes de proponer nada y antes de tocar nada:

1. **Leer las instrucciones vigentes.** Este documento, más
   [AGENTS.md](../AGENTS.md) o [CLAUDE.md](../CLAUDE.md) según el rol, más
   [CONTRIBUTING.md](../CONTRIBUTING.md).
2. **Comprobar en qué rama se está** y si es la correcta para la tarea.
3. **Comprobar si hay cambios locales sin commitear.** Si los hay y no son de
   esta tarea, no se descartan, no se commitean y no se cambia de rama encima:
   se avisa y se pregunta.
4. **Actualizar la vista del remoto** y mirar qué ramas existen en `origin`.
5. **Mirar los PR abiertos y su estado**, y **la corrida de CI del commit que
   hoy es la cabeza de cada PR**.
6. **Contrastar lo que dice la documentación con lo que muestra el
   repositorio.** PROJECT_STATUS.md tiene fecha: si la fecha es vieja, se
   verifica antes de repetirlo.

Comandos de referencia:

```bash
git status
git fetch --all --prune
git branch -vv
git log --oneline -5 origin/main
gh pr list --state open --json number,title,headRefName,headRefOid
gh run list --commit <headRefOid-completo-de-la-cabeza-del-PR>
```

Una trampa conocida: `gh run list --commit` **necesita el SHA completo** (los 40
caracteres del `headRefOid` que devuelve el comando anterior, o
`git rev-parse origin/<rama>`). Con un SHA corto devuelve una lista vacía y
termina sin error, y eso se parece demasiado a «no hay corridas» sin serlo.

Si no se puede acceder a GitHub, se dice **qué quedó sin verificar** y se trabaja
con lo que haya, marcándolo como no verificado. No se inventan estados.

---

## 5. Una branch por tarea

Cada tarea vive en su propia rama, creada desde `origin/main` actualizado, y el
alcance de la rama es el alcance del prompt. El prefijo describe la intención:

| Prefijo | Para qué |
|---|---|
| `feat/` | funcionalidad nueva |
| `fix/` | corrección de algo que está mal |
| `ci/` | integración continua y automatizaciones del repo |
| `chore/` | tareas de mantenimiento |
| `docs/` o `codex/` | documentación y método de trabajo |
| `test/` | ramas de integración o validación, normalmente **locales y temporales** |

Reglas que sostienen la separación de alcance:

- **Nunca se trabaja sobre `main`.** `main` solo cambia por merge de un PR.
- **Una rama no incorpora otra rama de trabajo** salvo que el prompt lo pida.
  Mezclar dos PR abiertos en una rama arruina la revisión de los dos.
- **Las ramas de integración local no se publican.** Sirven para probar la
  combinación de dos PR en la propia máquina; publicarlas confunde el estado del
  remoto.
- El diff de la rama contiene **solo** lo que la tarea pedía. Un archivo tocado
  «de paso» es motivo suficiente para rehacer el commit.

---

## 6. Qué tiene que decir un buen prompt

Un prompt que no dice estas siete cosas produce trabajo que hay que tirar. El
orden importa poco; lo que importa es que ninguna falte.

1. **Objetivo.** Qué tiene que ser verdad cuando la tarea termine, en una o dos
   frases y en términos observables.
2. **Base.** Desde dónde se parte: rama base, commit, PR de referencia. Si la
   base es un estado que hay que comprobar, se dice que hay que comprobarlo.
3. **Alcance permitido.** Qué archivos, carpetas o capas se pueden tocar.
4. **Exclusiones explícitas.** Qué **no** se toca, aunque parezca razonable
   tocarlo. Acá van las trampas conocidas: no mezclar PR abiertos, no tocar
   ramas ajenas, no reinstalar herramientas, no resetear la base si la tarea no
   lo necesita.
5. **Criterios de aceptación.** Cómo se comprueba que está bien. Si un criterio
   no se puede comprobar, no es un criterio: es un deseo.
6. **Validaciones a correr.** Qué comandos hay que ejecutar y qué se hace si
   fallan por una causa ajena a la tarea (por ejemplo, un problema del entorno
   local).
7. **Condición de cierre.** Qué se entrega y hasta dónde llega la autorización:
   ¿commit local?, ¿push?, ¿PR?, ¿merge? Se nombran una por una; no se asume que
   una incluye a la siguiente.

La plantilla lista para completar está en
[prompts/EXECUTE_CLAUDE.md](prompts/EXECUTE_CLAUDE.md).

---

## 7. Cuándo hay que detenerse

Se detiene la ejecución cuando aparece cualquiera de estas cosas:

- la tarea necesita una acción que el prompt no autorizó;
- hay trabajo local ajeno que habría que pisar para avanzar;
- el estado real del repositorio no coincide con la base que el prompt daba por
  cierta, y la diferencia cambia lo que hay que hacer;
- una validación falla por una causa que la tarea no puede arreglar dentro de su
  alcance;
- para cumplir el criterio de aceptación habría que cambiar una regla de
  seguridad, de datos o de negocio que el prompt no puso en discusión.

**Cómo se comunica el bloqueo.** No alcanza con decir «no pude». Un bloqueo bien
comunicado tiene cuatro partes: (a) **qué** se intentó, con el comando o el
archivo exacto; (b) **qué pasó**, con la salida real y no con un resumen; (c)
**por qué eso bloquea** la tarea; (d) **qué haría falta** para desbloquearla,
como una decisión concreta que el fundador pueda tomar con un sí o un no.

Y una cosa más: lo que **sí** se pudo terminar se entrega igual. Un bloqueo en
una parte no justifica devolver la tarea entera sin hacer.

---

## 8. Cómo se cierra una tarea

El cierre no es «terminé»: es dejar armado el contexto de la tarea siguiente,
que la va a preparar otra conversación sin memoria de esta.

Un cierre completo entrega:

- **rama, commit y enlace al PR** (si el prompt autorizó abrirlo);
- **lista de archivos creados o modificados**;
- **qué quedó publicado y qué sigue pendiente de integración** — son cosas
  distintas y hay que decirlas por separado;
- **qué se verificó y qué no se pudo verificar**, con el motivo;
- **el resultado de CI sobre el último commit publicado**, no sobre otro;
- **los hallazgos fuera de alcance**, con evidencia, propuestos como tareas
  separadas;
- **una recomendación única para el paso siguiente**, sin ejecutarla.

---

## 9. Dos reglas sobre la verdad de los documentos

### Las reglas permanentes y el estado temporal son documentos distintos

Este documento, AGENTS.md, CLAUDE.md y CONTRIBUTING.md dicen **cómo se trabaja**
y cambian poco. PROJECT_STATUS.md dice **cómo está el proyecto hoy** y envejece
solo. Mezclarlos hace que el método parezca falso cuando en realidad lo que
caducó fue el estado; o peor, que un estado viejo se lea como si fuera una
regla.

Por eso PROJECT_STATUS.md lleva fecha y SHA arriba de todo, y por eso no se
repite sin volver a comprobarlo contra GitHub.

### Las métricas pertenecen a un commit y a una corrida

«439 pruebas Flutter en verde» no es una propiedad del proyecto: es lo que pasó
en **una corrida de CI concreta sobre un SHA concreto**. En cuanto la rama
avanza un commit, ese número deja de estar verificado hasta que corra de nuevo.

De ahí salen tres reglas prácticas:

- Toda métrica se escribe junto al SHA y al enlace de la corrida que la produjo.
- **No se reutiliza el verde de otro SHA.** Si se publicó un commit nuevo, el
  estado de CI es el de ese commit, aunque el anterior estuviera impecable.
- **Dos PR verdes por separado no prueban que su combinación funcione.** Cada
  corrida validó su rama contra `main`, no contra la otra rama. Afirmar que
  juntos andan requiere una validación propia de la combinación.

Y una distinción que se pierde fácil: **prueba local**, **CI** y **despliegue
remoto** no son lo mismo. Que algo pase en la máquina del fundador no dice que
pase en el runner de CI; que pase en CI no dice nada sobre un entorno remoto,
que en este proyecto **todavía no existe**. Y la CI de este repositorio corre
con `push` a `main`/`develop` y con `pull_request`: **pushear una rama no
dispara CI**; la corrida arranca cuando se abre el PR.

---

## 10. Continuidad entre computadoras y entre conversaciones

### El principio

**GitHub conserva lo que está versionado y publicado. No conserva las
conversaciones, ni las ramas que quedaron solo en una computadora, ni el entorno
de trabajo de esa computadora.** Si algo tiene que sobrevivir, tiene que estar en
un commit pusheado.

De eso se desprende que:

- Un hallazgo que solo está en un chat se pierde. Va a un documento o a un
  comentario del código.
- Una rama que nunca se pusheó no existe para la máquina siguiente.
- Clonar el repositorio **no** deja el entorno listo: Flutter, Docker, la CLI de
  Supabase y las dependencias se instalan aparte, en la máquina.
- ChatGPT no lee estos documentos por su cuenta. O tiene acceso al repositorio, o
  el fundador le pasa los archivos. Por eso el prompt de arranque
  ([prompts/START_CHATGPT.md](prompts/START_CHATGPT.md)) **le pide expresamente**
  que los lea antes de opinar.
- Lo que se publica sobrevive, y por eso lo que **no** debe sobrevivir no se
  publica: ni en el repositorio ni en los prompts van secretos, tokens, rutas
  personales de una máquina, registros sensibles (salidas de comandos o logs con
  credenciales o datos personales; `supabase start`, por ejemplo, imprime las
  claves locales en una línea JSON que no hay que pegar en ningún informe) ni
  configuración privada de la computadora. El motivo es simple: un dato así en
  un commit queda copiado a la máquina y a la conversación siguientes, y
  sacarlo del historial exige reescribirlo, que es una de las acciones
  prohibidas de la §2.

### El procedimiento para retomar desde otra computadora

El objetivo es que alguien con una máquina limpia pueda seguir el trabajo sin
depender de ninguna conversación anterior. Qué rama corresponde retomar **hoy**
lo dice [PROJECT_STATUS.md](PROJECT_STATUS.md); los pasos son siempre estos.

**Paso 1 — Clonar con historial.**

```bash
git clone https://github.com/nicolodavenezia-rgb/talentflash-argentina.git
cd talentflash-argentina
```

**No descargues el ZIP** de GitHub. El ZIP no trae `.git`: te quedás sin
historial, sin ramas, sin poder comparar contra `main` y sin poder pushear.
Recuperar eso después es incómodo y evitable.

**Paso 2 — Autenticarse en la máquina nueva.** El repositorio es **privado**,
así que hace falta autenticación propia de esa computadora.

```bash
gh auth login --web
gh auth status
```

**Nunca copies tokens ni credenciales de una computadora a otra**, ni los pegues
en un chat, ni los guardes en el repositorio. El inicio de sesión por navegador
crea una credencial nueva en la máquina nueva, que es exactamente lo que
corresponde. Si el push de cambios dentro de `.github/` da error de permisos, el
motivo suele ser que a la credencial le falta el alcance `workflow`: se resuelve
volviendo a autenticarse pidiéndolo, no bajando controles del repositorio.

**Paso 3 — Elegir y bajar la rama correcta.**

```bash
git fetch --all --prune
git branch -r
git switch <rama>
```

Si vas a retomar el trabajo de un PR abierto, la rama correcta es la del PR
(mirala con `gh pr list --state open`). Si vas a empezar una tarea nueva, se
crea una rama nueva desde `origin/main` actualizado (§5).

**Paso 4 — Ver qué herramientas hacen falta antes de instalar nada.** La tabla
**«Requisitos»** del [README](../README.md) fija las versiones de Flutter, del
Android SDK, de la CLI de Supabase (que se instala con `npm install`, así que
Node tiene que estar) y de Docker Desktop; Deno tiene que ser 2.x para las
pruebas de la Edge Function, según la sección «Verificación» del mismo README,
y `gh` solo tiene que estar instalado y autenticado. Comprobá qué tenés antes de
bajar nada:

```bash
flutter --version
node --version
docker --version
deno --version
gh --version
```

Recién después instalá lo que falte, y seguí el bloque **«Setup (clon nuevo)»**
del README (`flutter pub get`, `npm install`, `flutter gen-l10n` y activar el
hook de pre-commit).

Cosas que **no** se hacen para «dejar el entorno andando»: reinstalar
herramientas que ya funcionan, tocar la configuración del antivirus, de Docker,
de WSL o de la red, ni resetear la base de datos. Si el entorno local no
arranca, eso se reporta como bloqueo con la salida real del error (§7); no se
arregla cambiando el proyecto.

**Paso 5 — Contrastar el estado documentado con GitHub.** Leé
[PROJECT_STATUS.md](PROJECT_STATUS.md) y después corré los comandos de la §4 de
este documento. Si la fecha de esa fotografía está vieja, mandan los comandos.

**Paso 6 — Abrir la conversación nueva.** Copiá el contenido de
[prompts/START_CHATGPT.md](prompts/START_CHATGPT.md) en una conversación nueva
de ChatGPT. Ese prompt le pide expresamente que lea los documentos del método:
**no los va a leer solo**. Si ChatGPT no tiene acceso al repositorio, pegale los
archivos que el prompt nombra.

---

## 11. Lo que este método NO es

Para que no crezca solo:

- No es un sistema de agentes. Son dos asistentes y una persona que decide.
- No hay automatizaciones que disparen tareas por su cuenta.
- No hay más plantillas que las dos de `docs/prompts/`.
- No se agrega una regla nueva porque suene prolija: se agrega cuando algo salió
  mal por no tenerla, y se escribe junto con el motivo.

---

## 12. Índice de los documentos del método

| Documento | Qué es |
|---|---|
| [docs/AI_WORKFLOW.md](AI_WORKFLOW.md) | este documento: el método, sus límites y el procedimiento de continuidad |
| [docs/PROJECT_STATUS.md](PROJECT_STATUS.md) | fotografía fechada del estado real |
| [docs/prompts/START_CHATGPT.md](prompts/START_CHATGPT.md) | prompt para arrancar o retomar el análisis |
| [docs/prompts/EXECUTE_CLAUDE.md](prompts/EXECUTE_CLAUDE.md) | plantilla para pedirle una ejecución a Claude |
| [AGENTS.md](../AGENTS.md) | instrucciones breves para el rol de análisis |
| [CLAUDE.md](../CLAUDE.md) | instrucciones breves para el rol de ejecución |
| [CONTRIBUTING.md](../CONTRIBUTING.md) | reglas técnicas del código y Definition of Done |
