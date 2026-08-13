# Contribuir a TalentFlash

## Flujo

1. Rama desde `main` → PR → CI verde (formato, analyze, tests, gitleaks) → merge.
2. Hook local obligatorio: `git config core.hooksPath .githooks` (rechaza
   commits con formato o análisis roto — T-002).
3. Una feature por vez; el proyecto siempre debe compilar y arrancar.

## Definition of Done (ROADMAP.md §4 + T-086)

Una tarea está terminada solo si:

1. `flutter analyze` limpio y `dart format` sin cambios pendientes.
2. Tests: unit + widget de lo tocado en verde; integration si aplica.
3. Toda tabla nueva/modificada tiene policy RLS **y** test pgTAP (T-007).
4. Ningún secreto en código, assets ni historial (gitleaks verde).
5. Docs actualizados si cambió arquitectura, esquema o flujo (docs/*.md).
6. Impacto económico registrado en docs/COST_DECISIONS.md si se agregó un
   servicio o costo (y el Excel de `../02_business_e_costi/` tras aprobación).
7. Strings SIEMPRE por ARB (`lib/core/localization/arb/`) — nunca hardcodeados.
8. Estados de carga/vacío/error definidos (UX_FLOWS.md §19).
9. **Pasada de accesibilidad WCAG AA** (checklist abajo).

## Checklist WCAG AA por pantalla (UX_FLOWS.md §20 — T-086)

- [ ] Contraste AA verificado (analizador de contraste) en claro y oscuro.
- [ ] Objetivos táctiles ≥ 48 dp.
- [ ] `Semantics` completo: la pantalla es operable con TalkBack/VoiceOver
      (labels programáticos, encabezados marcados, estados anunciados).
- [ ] Navegación por teclado en Web: orden lógico de foco y foco visible.
- [ ] Texto escalable al 200 % sin pérdida de contenido.
- [ ] `MediaQuery.disableAnimations` respetado (reducción de animaciones).
- [ ] El color nunca es el único portador de significado.
- [ ] Mensajes de error comprensibles y asociados a su campo.
- [ ] Video: nunca obligatorio; subtítulos y transcripción cuando aplique.

## Convenciones de código

- Feature-first (`lib/features/<feature>/presentation|domain|data`).
- Estado con Riverpod; navegación **solo** por nombre de ruta (`RouteNames`).
- Comentarios: qué restricción cumple el código, no qué hace la línea.
- Commits: mensaje imperativo corto + cuerpo con el porqué si no es obvio.
