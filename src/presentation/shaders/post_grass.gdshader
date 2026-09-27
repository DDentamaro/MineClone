// Post sui soli pixel dell'erba (stencil 2): come post.gdshader ma senza
// contorni ne' spigoli, come i fili del prototipo che scrivono alfa 0.
shader_type spatial;
render_mode unshaded, depth_test_disabled, depth_draw_never, cull_disabled, fog_disabled, shadows_disabled;
stencil_mode read, compare_equal, 2;

#include "res://src/presentation/shaders/post_body.gdshaderinc"
