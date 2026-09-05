# EXECUTE_CLAUDE.md — Plantilla para pedirle una tarea a Claude

Esta plantilla se completa **por tarea**. La arma ChatGPT (o el fundador), la
revisa y autoriza el fundador, y la ejecuta Claude. Cada sección existe porque
su ausencia ya produjo, en algún momento, trabajo que hubo que tirar: si una no
aplica, se escribe «no aplica» y por qué; no se borra.

La explicación de cada sección está en
[../AI_WORKFLOW.md §6](../AI_WORKFLOW.md#6-qué-tiene-que-decir-un-buen-prompt).

Cómo se usa: copiá lo que está debajo de la línea, reemplazá cada bloque
`> _Completar: …_` por el contenido real y **borrá esas notas en cursiva** antes
de enviarlo. Los ejemplos de las notas son ilustrativos: no son tareas
autorizadas ni describen el estado actual del proyecto.

---

Trabajá sobre el repositorio `nicolodavenezia-rgb/talentflash-argentina`.

Tu rol es el de **ejecución**: hacés la tarea de este prompt, dentro de su
alcance, en una branch separada, y al final entregás evidencia y un informe.
Leé `CLAUDE.md` y `docs/AI_WORKFLOW.md` antes de tocar nada. Yo decido
prioridades, alcance y autorizaciones; lo que este prompt no autoriza, no está
autorizado.

## Objetivo

> _Completar: qué tiene que ser verdad cuando termines, en una o dos frases
> observables. Ejemplo de forma: «La Edge Function `avatar` acepta WebP y lo
> re-encodea a JPEG, con la misma política de tamaño y sin EXIF»._

## Base

> _Completar: desde dónde se parte y qué hay que comprobar antes. Ejemplo de
> forma: «Creá la rama `fix/<nombre>` desde `origin/main` actualizado. Comprobá
> primero rama, cambios locales, remoto, PR abiertos y CI de sus cabezas. Como
> referencia, la última revisión vio `main` en `<sha>`; volvé a comprobarlo y no
> lo presentes como actual si cambió»._

## Alcance permitido

> _Completar: archivos, carpetas o capas que se pueden tocar. Ejemplo de forma:
> «Solo `supabase/functions/avatar/` y sus pruebas en
> `supabase/functions/avatar/lib/*_test.ts`»._

## Exclusiones

> _Completar: qué NO se toca aunque parezca razonable, incluidas las trampas
> conocidas. Ejemplo de forma: «No incorpores ramas de otros PR abiertos. No
> toques migraciones. No modifiques `.github/workflows/`. No reinstales
> herramientas ni cambies Docker, WSL, antivirus o red. No resetees la base si
> la tarea no lo necesita»._

## Criterios de aceptación

> _Completar: cómo se comprueba que está bien; si no se puede comprobar, no es
> criterio. Ejemplo de forma: «Un test nuevo sube un WebP válido y recibe 200
> con JPEG; un WebP malformado recibe 415 `invalid_image`; el resto de la suite
> sigue igual»._

## Validaciones a correr

> _Completar: comandos exactos y qué hacer si fallan por causas ajenas a la
> tarea. Ejemplo de forma: «`dart format --output=none --set-exit-if-changed .`,
> `flutter analyze`, `flutter test`, `npm run functions:test`. Si el stack local
> no levanta por un problema del entorno, reportalo con la salida real y seguí
> con lo que no dependa de eso; no lo arregles tocando el proyecto»._

## Condición de cierre y autorizaciones

> _Completar nombrando cada permiso por separado; lo que no está escrito, no
> está dado. Ejemplo de forma: «Autorizo: commit en la rama, push de ESA rama y
> apertura de un PR contra `main`. NO autorizo: merge, cambios en otras ramas,
> publicar ramas locales de integración, force push». Recordá que la CI de este
> repositorio corre con el PR, no con el push de la rama: si no autorizás el PR,
> no va a haber corrida de CI que reportar._

## Entrega final

Respondé en español con:

- rama, commit y enlace al PR (si lo autoricé);
- archivos creados o modificados;
- qué quedó publicado y qué sigue pendiente de integración, por separado;
- verificaciones realizadas y las que no pudiste hacer, con el motivo;
- resultado de CI sobre el **último commit publicado** (no reutilices el verde
  de otro SHA; si CI no corrió porque no hubo PR, decilo);
- hallazgos fuera de alcance, con evidencia, propuestos como tareas separadas
  y **sin ejecutarlos**;
- una única recomendación para la próxima tarea, sin ejecutarla.

Si te bloqueás por falta de autorización o por un estado distinto del esperado,
frená y reportá: qué intentaste, qué pasó (salida real), por qué bloquea y qué
decisión necesitás de mí. Entregá igual lo que sí pudiste terminar.
