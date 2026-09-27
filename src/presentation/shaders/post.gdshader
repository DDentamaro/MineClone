// Post-processing del render target a bassa risoluzione: porting di blitFS
// (contorni e spigoli dalla profondita', raggi, nebbia in prospettiva, notte,
// color grading) e di skyFS per i pixel di cielo (HTML ~5214 e ~5640).
// Quad a tutto schermo figlio della camera, disegnato per ultimo. Salta i
// pixel dell'erba (stencil 2), che passano da post_grass.gdshader.
shader_type spatial;
render_mode unshaded, depth_test_disabled, depth_draw_never, cull_disabled, fog_disabled, shadows_disabled;
stencil_mode read, compare_not_equal, 2;

#include "res://src/presentation/shaders/post_body.gdshaderinc"
