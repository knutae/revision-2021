#version 450
in vec2 C;
out vec3 F;
layout (location=0) uniform float W;
layout (location=1) uniform float H;

// Shader minifier does not (currently) minimize structs, so use short names.
// Using a one-letter name for the struct itself seems to trigger a bug, so use two.
struct ma {
    float A; // ambient
    float D; // diffuse
    float P; // specular
    float S; // shininess
    float R; // reflection
    vec3 C; // RGB color
};

float DRAW_DISTANCE = 20.0;
float PI = atan(1)*4;

float origin_sphere(vec3 p, float radius) {
    return length(p) - radius;
}

float horizontal_plane(vec3 p, float height) {
    return p.y - height;
}

float origin_box(vec3 p, vec3 dimensions, float corner_radius) {
    vec3 a = abs(p);
    return length(max(abs(p) - dimensions, 0.0)) - corner_radius;
}

float box(vec3 p, vec3 dimensions) {
    vec3 q = abs(p) - dimensions;
    return length(max(q,0)) + min(max(q.x,max(q.y,q.z)),0);
}

void closest_material(inout float dist, inout ma mat, float new_dist, ma new_mat) {
    if (new_dist < dist) {
        dist = new_dist;
        mat = new_mat;
    }
}

float repeated_boxes_xz(vec3 p, vec3 dimensions, float corner_radius, float modulo) {
    p.xz = mod(p.xz - 0.5 * modulo, modulo) - 0.5 * modulo;
    return origin_box(p, dimensions, corner_radius);
}

float ground(vec3 p) {
    return p.y + 0.8;
}

float round_cone(vec3 p, float r1, float r2, float h) {
  vec2 q = vec2(length(p.xz), p.y);
  float b = (r1-r2)/h;
  float a = sqrt(1.0-b*b);
  float k = dot(q,vec2(-b,a));
  if(k < 0) return length(q) - r1;
  if(k > a*h) return length(q-vec2(0.0,h))-r2;
  return dot(q, vec2(a,b)) - r1;
}

mat2 rotate(float a) {
    float r = a * PI / 180;
    return mat2(cos(r), -sin(r), sin(r), cos(r));
}

float smooth_union(float a, float b, float k) {
    float h = clamp(0.5 + 0.5*(b-a)/k, 0, 1);
    return mix(b, a, h) - k*h*(1-h);
}

float smooth_intersection(float a, float b, float k) {
    float h = clamp(0.5 - 0.5*(b-a)/k, 0, 1);
    return mix(b, a, h) + k*h*(1-h);
}

float lagomorph_legs(vec3 p) {
    vec3 q = p;
    q.z -= 0.2;
    q.y -= 0.5;
    q.x = abs(q.x) - 0.5;
    // upper legs
    q.xy *= rotate(160);
    q.yz *= rotate(-10);
    q.y += 0.9;
    float dist = round_cone(q, 0.13, 0.18, 0.8);
    // lower legs
    q.y -= 0.8;
    q.yz *= rotate(10);
    q.xy *= rotate(20);
    dist = min(dist, round_cone(q, 0.18, 0.2, 0.4));
    // feet
    q.y -= 0.4;
    q.yz *= rotate(-80);
    q.xy *= rotate(-30);
    q.xz *= rotate(-20);
    dist = smooth_union(dist, round_cone(q, 0.1, 0.3, 0.7), 0.1);
    dist = smooth_intersection(dist, 0.1 - p.y, 0.1);
    return dist;
}

float finger(vec3 p, float offset, float len, float angle1, float angle2) {
    p.xy *= rotate(angle1);
    p.x += offset;
    p.yz *= rotate(angle2);
    return round_cone(p, 0.05, 0.1, len);
}

float lagomorph_arms(vec3 p) {
    p.y -= 2;
    p.x = abs(p.x) - 0.2;
    p.xy *= rotate(115);
    float dist = round_cone(p, 0.1, 0.1, 0.6);
    p.y -= 0.6;
    p.xy *= rotate(20);
    dist = min(dist, round_cone(p, 0.1, 0.12, 0.4));
    p.y -= 0.4;
    p.xz *= rotate(-60);
    p.yz *= rotate(-40);
    dist = smooth_union(dist, origin_sphere(p, 0.22), 0.1);
    p.z -= 0.1;
    dist = smooth_union(dist, finger(p, 0.08, 0.35, -30, 10), 0.02);
    dist = smooth_union(dist, finger(p, -0.1, 0.4, 80, 30), 0.02);
    p.z -= 0.04;
    dist = smooth_union(dist, finger(p, 0.07, 0.5, -10, 40), 0.02);
    dist = smooth_union(dist, finger(p, -0.07, 0.5, 0, 40), 0.02);
    return dist;
}

float lagomorph_head(vec3 p) {
    p.y -= 2.6;
    p.x /= 1.5;
    return origin_sphere(p, 0.48);
}

float lagomorph_ears(vec3 p) {
    p.y -= 3.5;
    p.x = abs(p.x) - 0.5;
    p.xy *= rotate(10);
    p.yz *= rotate(5);
    p.y /= 6;
    p.x /= 2.5;
    float dist = origin_sphere(p, 0.1);
    dist = smooth_intersection(dist, p.z - 0.04, 0.05);
    dist = smooth_intersection(dist, -0.06 - p.x, 0.05);
    return dist;
}

float lagomorph(vec3 p) {
    p.y -= 0.5;
    float dist = round_cone(p, 0.4, 0.2, 1);
    p.y += 1.3;
    dist = smooth_union(dist, lagomorph_legs(p), 0.05);
    dist = smooth_union(dist, lagomorph_arms(p), 0.05);
    dist = smooth_union(dist, lagomorph_head(p), 0.05);
    dist = smooth_union(dist, lagomorph_ears(p), 0.05);
    return dist;
}

float blind(vec3 p) {
    p.yz *= rotate(45);
    return box(p, vec3(2.4, 0.02, 0.05));
}

float blinds(vec3 p) {
    vec3 q = p;
    q.x = abs(q.x) - 2;
    float dist = length(q.xz) - 0.02;
    float modulo = 0.2;
    p.y = mod(p.y - 0.5 * modulo, modulo) - 0.5 * modulo;
    return min(dist, blind(p));
}

float room(vec3 p) {
    p.z += 9;
    float dist = max(box(p, vec3(10)), -box(p, vec3(9.8)));
    p.y -= 2.7;
    p.z -= 9.9;
    dist = max(dist, -box(p, vec3(2.5, 2, 1))); // window
    dist = min(dist, blinds(p));
    return dist;
}

float scene(vec3 p, out ma mat) {
    //float dist = origin_sphere(p, 1);
    float dist = lagomorph(p);
    //float dist = 1000;
    mat = ma(0.1, 0.9, 0, 10, 0, vec3(1));
    closest_material(dist, mat, ground(p), ma(0.1, 0.9, 0.9, 4, 0.0, vec3(0.8)));
    closest_material(dist, mat, room(p), ma(0.1, 0.9, 0, 10, 0.0, vec3(0.8)));
    return dist;
}

bool ray_march(inout vec3 p, vec3 direction, out ma material) {
    float total_dist = 0.0;
    for (int i = 0; i < 4096; i++) {
        float dist = scene(p, material);
        if (dist < 0.001) {
            return true;
        }
        total_dist += dist;
        if (total_dist > DRAW_DISTANCE) {
            return false;
        }
        p += direction * dist;
    }
    return false;
}

vec3 estimate_normal(vec3 p) {
    float epsilon = 0.001;
    ma m;
    return normalize(vec3(
        scene(vec3(p.x + epsilon, p.y, p.z), m) - scene(vec3(p.x - epsilon, p.y, p.z), m),
        scene(vec3(p.x, p.y + epsilon, p.z), m) - scene(vec3(p.x, p.y - epsilon, p.z), m),
        scene(vec3(p.x, p.y, p.z + epsilon), m) - scene(vec3(p.x, p.y, p.z - epsilon), m)
    ));
}

vec3 ray_reflection(vec3 direction, vec3 normal) {
    return 2.0 * dot(-direction, normal) * normal + direction;
}

float sharp_shadow(vec3 p, vec3 light_direction) {
    ma m;
    p += light_direction * 0.1;
    float total_dist = 0.1;
    for (int i = 0; i < 200; i++) {
        float dist = scene(p, m);
        if (dist < 0.01) {
            return 0.0;
        }
        total_dist += dist;
        if (total_dist > DRAW_DISTANCE) {
            break;
        }
        p += light_direction * dist;
    }
    return 1.0;
}

const vec3 background_color = vec3(0.9, 0.95, 1.0);

vec3 apply_fog(vec3 color, float total_distance) {
    return mix(color, background_color, 1.0 - exp(-0.06 * total_distance));
}

vec3 phong_lighting(vec3 p, ma mat, vec3 ray_direction) {
    vec3 normal = estimate_normal(p);
    vec3 light_direction = normalize(vec3(0.05, -0.17, -0.5));
    float shadow = sharp_shadow(p, -light_direction);
    float diffuse = max(0.0, mat.D * dot(normal, -light_direction)) * shadow;
    vec3 reflection = ray_reflection(ray_direction, normal);
    float specular = pow(max(0.0, mat.P * dot(reflection, -light_direction)), mat.S) * shadow;
    return min(mat.C * (diffuse + mat.A) + vec3(specular), vec3(1.0));
}

vec3 apply_reflections(vec3 color, ma mat, vec3 p, vec3 direction) {
    float reflection = mat.R;
    for (int i = 0; i < 3; i++) {
        if (reflection <= 0.01) {
            break;
        }
        vec3 reflection_color = background_color;
        direction = ray_reflection(direction, estimate_normal(p));
        vec3 start_pos = p;
        p += 0.05 * direction;
        if (ray_march(p, direction, mat)) {
            reflection_color = phong_lighting(p, mat, direction);
            reflection_color = apply_fog(reflection_color, length(p - start_pos));
            color = mix(color, reflection_color, reflection);
            reflection *= mat.R;
        } else {
            color = mix(color, reflection_color, reflection);
            break;
        }
    }
    return color;
}

vec3 render_from(float u, float v, vec3 eye_position, vec3 look_at) {
    vec3 forward = normalize(look_at - eye_position);
    vec3 up = vec3(0.0, 1.0, 0.0);
    vec3 right = normalize(cross(up, forward));
    up = cross(-right, forward);
    float focal_length = 1.0;
    vec3 start_pos = eye_position + forward * focal_length + right * u + up * v;
    vec3 direction = normalize(start_pos - eye_position);
    vec3 p = start_pos;
    vec3 color = background_color;
    ma mat;
    if (ray_march(p, direction, mat)) {
        color = phong_lighting(p, mat, direction);
        color = apply_reflections(color, mat, p, direction);
        color = apply_fog(color, length(p - start_pos));
    }
    return color;
}


vec3 render_far(float u, float v) {
    return render_from(u, v, vec3(0.5, 2, -14), vec3(1, -4, 0));
}

vec3 render_close(float u, float v) {
    return render_from(u, v, vec3(-4, 0.5, -1), vec3(0, 2, 1));
}

vec3 render(float u, float v) {
    if (u > 0) {
        return render_far(u-0.5, v);
    } else {
        return render_close(u+0.5, v);
    }
}

vec3 render_aa(float u, float v) {
    // Antialiasing: render and blend 2x2 points per pixel.
    // That means the distance between points is 1/2 pixel,
    // and the distance from the center (du, dv) is 1/4 pixel.
    // Each pixel size is (2.0 / W, 2.0 / H) since the full area is -1 to 1.
    float du = 2.0 / W / 4.0;
    float dv = 2.0 / H / 4.0;
    vec3 sum =
        render(u - du, v - dv) +
        render(u - du, v + dv) +
        render(u + du, v - dv) +
        render(u + du, v + dv);
    return sum / 4;
}

void main() {
    float u = C.x - 1.0;
    float v = (C.y - 1.0) * H / W;
//#if defined(DEBUG)
    F = render(u, v);
//#else
//    F = render_aa(u, v);
//#endif
    // vignette
    float edge = abs(C.x - 1) + abs(C.y - 1);
    F = mix(F, vec3(0), min(1, max(0, edge*0.3 - 0.2)));
}
