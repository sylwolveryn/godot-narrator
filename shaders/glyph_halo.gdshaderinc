// Soft glow shape shared by the halo shaders (glyph_halo.gdshader, glyph_actor.gdshader), task-033.
// q: position in the glow quad, screen right/up, 1 = the glow radius. pool_y: screen offset (in q units) of the floor
// point below the glow centre. squash: height / width of a floor circle seen from the camera. pool: 0 = round bloom,
// 1 = the glow pools on the floor (an ellipse around the floor point). The result falls to zero at r = 1.
// A tight bright core plus a long soft tail (and a faint streak across the pool) keeps it from reading as a flat orb.
float halo_shape(vec2 q, float pool_y, float squash, float pool) {
	float r2 = dot(q, q);
	float r = sqrt(r2);
	float bloom = 0.85 * exp(-r2 * 9.0) + 0.38 * exp(-r * 3.4);
	vec2 p = vec2(q.x, (q.y - pool_y) / max(squash, 0.2));
	float p2 = dot(p, p);
	float ground = 0.75 * exp(-p2 * 3.2) + 0.3 * exp(-sqrt(p2) * 2.6);
	float g = mix(bloom, ground + 0.45 * bloom, pool);
	return g * (1.0 - smoothstep(0.45, 1.0, r));
}
