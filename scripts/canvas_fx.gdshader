// 画面氛围叠加特效（叠加型：只盖一层半透明色，不采样画布，无延迟/无反馈）
// 挂在画布滚动区上的一个全屏 ColorRect（CanvasFx），mouse_filter=IGNORE 不挡操作
// 各 uniform 为强度 0~1，0 = 关闭；可任意组合叠加
shader_type canvas_item;
render_mode unshaded;

uniform float vignette : hint_range(0.0, 1.0) = 0.0;    // 暗角（四角渐暗，聚焦中心）
uniform float scanlines : hint_range(0.0, 1.0) = 0.0;   // 复古扫描线（CRT 横纹）
uniform float grain : hint_range(0.0, 1.0) = 0.0;       // 胶片颗粒（动态噪点）
uniform float light_leak : hint_range(0.0, 1.0) = 0.0;  // 暖色漏光（顶部边缘暖橙，手账氛围）

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 uv = UV;
	vec3 overlay = vec3(0.0); // 叠加色（黑=变暗，亮=提亮/染色）
	float a = 0.0;            // 叠加强度

	// 暗角：四角渐暗
	if (vignette > 0.0) {
		vec2 d = uv - 0.5;
		float v = smoothstep(0.22, 0.70, dot(d, d));
		overlay = mix(overlay, vec3(0.0), v * vignette);
		a = max(a, v * vignette);
	}
	// 扫描线：CRT 横纹（每隔一行压暗）
	if (scanlines > 0.0) {
		float sl = step(0.5, fract(uv.y * 380.0));
		overlay = mix(overlay, vec3(0.0), sl);
		a = max(a, sl * scanlines * 0.55);
	}
	// 暖色漏光：顶部边缘暖橙渐变
	if (light_leak > 0.0) {
		float top = smoothstep(0.45, 0.0, uv.y);
		float side = smoothstep(0.55, 0.0, abs(uv.x - 0.5));
		float lk = top * side * light_leak;
		overlay += vec3(1.0, 0.55, 0.25) * lk * 1.4;
		a = max(a, lk * 0.7);
	}
	// 胶片颗粒：动态亮暗噪点
	if (grain > 0.0) {
		float g = hash21(uv * vec2(320.0, 180.0) + fract(TIME) * 130.0);
		overlay += (g - 0.5) * grain;
		a = max(a, grain * 0.45);
	}

	COLOR = vec4(overlay, clamp(a, 0.0, 1.0));
}
