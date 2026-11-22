
struct UT {
    float2 res; float cell; float time;
    float streams; float speed; float bright; float glow;
    float nGlyph; float gap; float imgMix; float imgT;
    float imgColor; float imgLod; float glitch; float imgAsp;
    float mirror; float camera; float p1; float p2;
    float scan; float mask; float roll; float grain;
    float cell0; float wet; float ghostK; float wave;
    float depth; float noise; float dissolve; float audio;
    float4 tintDark; float4 tintBright;
};
cbuffer CB : register(b0) { UT u; };
struct VO { float4 pos : SV_Position; float2 uv : TEXCOORD0; };
Texture2D atlasT : register(t0); Texture2D imgAT : register(t1); Texture2D imgBT : register(t2); Texture2D histT : register(t3); Texture2D scnT : register(t4);
SamplerState smp : register(s0);

VO vs(uint vid : SV_VertexID) {
    float2 p = float2((vid << 1) & 2, vid & 2);
    VO o;
    o.pos = float4(p * 2.0 - 1.0, 0.0, 1.0);
    o.uv = float2(p.x, 1.0 - p.y);
    return o;
}

float hash(float2 p) {
    float3 p3 = frac(p.xyx * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return frac((p3.x + p3.y) * p3.z);
}

float4 layerColor(VO inp, float cs, float seed, float blur, float dim) {
    float cell = u.cell * cs;
    float cell0 = u.cell0 * cs;
    float2 gc = float2(ceil(u.res.x / cell0), ceil(u.res.y / cell0)) * 0.5;
    float2 g = (inp.uv * u.res - 0.5 * u.res) / cell + gc;
    float2 id = floor(g);
    float2 f = frac(g);
    float2 idS = id + float2(seed * 97.0, seed * 53.0);
    float cols = ceil(u.res.x / cell0);
    float rows = ceil(u.res.y / cell0);
    float b = 0.0;
    float head = 0.0;
    float neck = 0.0;
    float dep = 1.0;
    for (int i = 0; i < 4; i++) {
        float act = clamp(u.streams - float(i), 0.0, 1.0);
        if (hash(float2(idS.x, float(i) * 11.0 + 3.0)) >= act) continue;
        float h1 = hash(float2(idS.x, float(i) * 7.0 + 1.0));
        float h2 = hash(float2(idS.x, float(i) * 13.0 + 2.0));
        float h3 = hash(float2(idS.x, float(i) * 5.0 + 8.0));
        float len = lerp(8.0, 36.0, h1);
        float spd = lerp(7.0, 22.0, h2) * u.speed;
        float cyc = rows + len + u.gap * rows * h3 * 2.0;
        float pos = floor(fmod(u.time * spd + h3 * cyc * 7.0, cyc));
        float d = pos - id.y;
        if (d >= 0.0 && d < len) {
            float t = 1.0 - d / len;
            float sd = lerp(0.4, 1.0, hash(float2(idS.x, float(i) * 17.0 + 4.0)));
            float sb = pow(t, 1.6) * lerp(0.45, 1.0, sd);
            if (sb > b) { b = sb; dep = sd; }
            if (d < 1.0) head = max(head, sd);
            else if (d < 3.0) neck = max(neck, (3.0 - d) / 2.0 * sd);
        }
    }

    // obraz (zdjęcie / zegar) składany z kodu
    float L = 0.0;
    float dissBoost = 0.0;
    float3 pic = float3(0.0);
    if (u.imgMix > 0.001) {
        float2 suv = clamp((0.5 * u.res + (id + 0.5 - gc) * cell) / u.res, 0.0, 1.0);
        float sa = u.res.x / u.res.y;
        float ia = u.imgAsp;
        float2 iuv = sa > ia ? float2(suv.x, 0.5 + (suv.y - 0.5) * ia / sa)
                             : float2(0.5 + (suv.x - 0.5) * sa / ia, suv.y);
        if (u.mirror > 0.5 && u.camera > 0.5) iuv.x = 1.0 - iuv.x;
        float3 pa = imgAT.SampleLevel(smp, iuv, u.imgLod).rgb;
        float3 pb = imgBT.SampleLevel(smp, iuv, u.imgLod).rgb;
        float thr = hash(idS * 2.3 + 5.0) * 0.4 + clamp(id.y / rows, 0.0, 1.0) * 0.6;
        float sw = u.dissolve > 0.5 ? step(thr, u.imgT) : u.imgT;
        pic = lerp(pa, pb, sw);
        if (u.dissolve > 0.5 && u.imgT > 0.001 && u.imgT < 0.999) dissBoost = exp(-pow((u.imgT - thr) * 12.0, 2.0));
        L = clamp((dot(pic, float3(0.299, 0.587, 0.114)) - lerp(0.15, 0.05, u.camera)) * lerp(1.6, 2.0, u.camera), 0.0, 1.0);
    }
    float rate = lerp(0.3, 3.0, hash(idS + 7.7));
    float tick = floor(u.time * rate + hash(idS + 1.1) * 50.0);
    float rnd = hash(idS * 1.37 + tick * 0.731);
    float amb = step(0.5, hash(idS + 9.1)) * 0.08 * (0.5 + 0.5 * hash(idS + tick)) * (1.0 - step(0.001, u.imgMix));
    float bRain = max(b, amb) * lerp(1.0, 0.25 + 0.9 * L, u.imgMix);
    head *= lerp(1.0, 0.4 + 0.7 * L, u.imgMix);
    if (u.wave > 0.001) {
        float cn = floor(u.time / 16.0);
        float ph = frac(u.time / 16.0);
        float horiz = fmod(cn, 2.0) < 0.5 ? 0.0 : 1.0;
        float span = horiz < 0.5 ? rows + 60.0 : cols + 60.0;
        float coord = horiz < 0.5 ? id.y : id.x;
        float wp = clamp(ph / 0.6, 0.0, 1.0) * span - 30.0;
        float wv = u.wave * exp(-pow((coord - wp) / 5.0, 2.0)) * step(ph, 0.6);
        bRain = max(bRain, wv * 0.55) * (1.0 + wv * 1.2);
    }
    bRain *= 1.0 + u.audio * 0.9;
    float bSteady = pow(L, 1.7) * u.imgMix + dissBoost * 0.8;
    float bAll = max(bRain, bSteady);
    if (bAll <= 0.001) return float4(0.0, 0.0, 0.0, 1.0);
    float fl = 0.75 + 0.25 * hash(idS + tick * 1.9);
    bRain *= fl;
    bSteady *= (0.88 + 0.12 * hash(idS + tick * 1.9));

    float gi = floor(rnd * u.nGlyph);
    float flip = hash(idS + 3.3) > 0.5 ? 1.0 : 0.0;
    float fx = lerp(f.x, 1.0 - f.x, flip);
    float2 cellXY = float2(fmod(gi, 8.0), floor(gi / 8.0));
    float2 uv = (cellXY + 0.5 + (float2(fx, f.y) - 0.5) * 0.74) / 8.0;
    float gl = atlasT.SampleLevel(smp, uv, max(0.0, log2(94.72 / cell)) + (1.0 - dep) * 2.0 + blur).r;
    float2 e = smoothstep(0.0, 0.05, f) * smoothstep(0.0, 0.05, 1.0 - f);
    gl *= e.x * e.y;

    float3 pal = lerp(u.tintDark.rgb, u.tintBright.rgb, clamp(bRain * 1.15, 0.0, 1.0));
    float3 cRain = pal * bRain * u.bright;
    float3 scol = u.tintBright.rgb;
    if (u.imgColor > 0.5) scol = lerp(float3(1.0), pic / max(max(max(pic.r, pic.g), pic.b), 0.05), 0.9);
    float3 cSteady = scol * bSteady * u.bright * 0.95;
    float3 c = max(cRain, cSteady);
    c = lerp(c, u.tintBright.rgb * 0.9, neck * 0.5);
    c = lerp(c, lerp(u.tintBright.rgb, float3(1.0), 0.8) * 1.7, head);
    return float4(c * gl * dim, 1.0);
}

float4 sceneColor(VO inp) {
    float4 c = layerColor(inp, 1.0, 0.0, 0.0, 1.0);
    if (u.depth > 0.001) {
        c.rgb += layerColor(inp, 0.55, 1.7, 0.0, 0.45 * u.depth).rgb;
        c.rgb += layerColor(inp, 2.1, 3.3, 2.2, 0.55 * u.depth).rgb;
    }
    return c;
}

float4 scene(VO inp) : SV_Target {
    float3 c = sceneColor(inp).rgb;
    if (u.ghostK > 0.001) c = max(c, histT.Load(int3(int2(inp.pos.xy), 0)).rgb * u.ghostK);
    return float4(c, 1.0);
}

float3 wetFx(float2 uv, float t, float asp) {
    float2 off = float2(0.0);
    float hl = 0.0;
    for (int L = 0; L < 2; L++) {
        float sc = L == 0 ? 7.0 : 13.0;
        float2 p = float2(uv.x * asp, uv.y) * sc;
        p.y += float(L) * 3.7;
        float2 id = floor(p);
        float h = hash(id + float(L) * 17.0);
        float h2 = hash(id * 1.7 + 3.1);
        if (h < 0.45) continue;
        float spd = lerp(0.05, 0.16, h2);
        float cy = frac(t * spd + h * 3.0);
        float2 center = float2(0.2 + 0.6 * h2, cy);
        float2 d = frac(p) - center;
        float r = lerp(0.09, 0.2, h);
        float dist = length(d * float2(1.0, 0.8));
        float drop = smoothstep(r, r * 0.4, dist);
        float tr = smoothstep(0.035, 0.0, abs(d.x)) * step(d.y, 0.0) * smoothstep(-0.7, 0.0, d.y);
        off += -(d / r) * drop * 0.012 + float2(d.x, 0.0) * tr * 0.004;
        hl += drop * smoothstep(0.0, 0.5, -d.y / r + 0.5) * 0.06 + tr * 0.01;
    }
    return float3(off, hl);
}

float4 comp(VO inp) : SV_Target {
    float curve = u.p1;
    float vg = u.p2;
    float2 q0 = inp.uv - 0.5;
    float kb = 0.2 * curve;
    float2 cuv = 0.5 + q0 * (1.0 + kb * dot(q0, q0) * 4.0) / (1.0 + kb * 2.0);
    float2 uv = cuv;
    float gt = floor(u.time * 7.0);
    float row = floor(uv.y * 28.0);
    float gon = step(1.0 - u.glitch * 0.35, hash(float2(gt, 3.0)));
    float band = step(0.82, hash(float2(gt * 1.7 + row, 5.0)));
    float gb = gon * band;
    uv.x += gb * (hash(float2(gt, row)) - 0.5) * 0.12;
    float3 wf = u.wet > 0.001 ? wetFx(cuv, u.time, u.res.x / u.res.y) : float3(0.0);
    uv += wf.xy * u.wet;
    float gn = floor(u.time * 2.0);
    float tn = frac(u.time * 2.0);
    float ev = step(1.0 - u.noise * 0.18, hash(float2(gn, 9.0)));
    if (ev > 0.5) {
        uv.y = frac(uv.y + 0.3 * (1.0 - tn) * (1.0 - tn) * hash(float2(gn, 4.0)));
        uv.x += (hash(float2(floor(uv.y * 40.0), gn)) - 0.5) * 0.04 * (1.0 - tn);
    }
    float2 q = cuv - 0.5;
    float2 off = q * 0.0035 * (1.0 + curve);
    float3 base = float3(scnT.SampleLevel(smp, uv + off, 0).r,
                         scnT.SampleLevel(smp, uv, 0).g,
                         scnT.SampleLevel(smp, uv - off, 0).b);
    float3 bl = scnT.SampleLevel(smp, uv, 1).rgb * 0.35
              + scnT.SampleLevel(smp, uv, 2).rgb * 0.55
              + scnT.SampleLevel(smp, uv, 3).rgb * 0.75
              + scnT.SampleLevel(smp, uv, 4).rgb * 0.9
              + scnT.SampleLevel(smp, uv, 5).rgb * 0.8
              + scnT.SampleLevel(smp, uv, 6).rgb * 0.6;
    float3 tint = normalize(u.tintBright.rgb + 0.15);
    float3 c = base + bl * (0.35 + 0.65 * tint / max(max(tint.r, tint.g), tint.b)) * u.glow * (1.0 + u.audio * 1.6);
    c *= 1.0 + gb * 0.6;
    c += (u.tintBright.rgb * 0.8 + 0.1) * wf.z * u.wet;
    c += ev * step(0.985, hash(float2(floor(cuv.y * 300.0), gn + floor(u.time * 30.0)))) * u.tintBright.rgb * 0.7;

    // CRT: linie skanowania, maska luminoforu, pasmo odświeżania
    float sl = 0.5 + 0.5 * sin(inp.pos.y * 2.0943951);
    c *= 1.0 - u.scan * 0.45 * sl;
    float ph = fmod(inp.pos.x, 3.0);
    float3 mask = float3(ph < 1.0 ? 1.0 : 0.70, (ph >= 1.0 && ph < 2.0) ? 1.0 : 0.70, ph >= 2.0 ? 1.0 : 0.70);
    c *= lerp(float3(1.0), mask * 1.15, u.mask * 0.8);
    float bd = cuv.y - frac(u.time * 0.07);
    bd -= round(bd);
    c *= 1.0 + u.roll * 0.6 * exp(-bd * bd * 160.0);
    c *= 1.0 + u.roll * 0.05 * sin(u.time * 90.0);

    // winieta i zaokrąglony kształt ekranu
    c *= clamp(1.0 - dot(q, q) * (0.3 + 2.2 * vg), 0.0, 1.0);
    c *= 1.0 - curve * 0.5 * smoothstep(0.30, 0.52, max(abs(q0.x), abs(q0.y)) * 1.0 + dot(q0, q0) * 0.25);

    float flick = 1.0 + 0.012 * sin(u.time * 41.0) + 0.008 * sin(u.time * 7.3);
    float grain = (hash(inp.uv * u.res + frac(u.time) * 91.0) - 0.5) * 0.07 * u.grain;
    c = c * flick + grain * (0.3 + c.g);
    c = c / (1.0 + c * 0.35);
    c = max(c, 0.0);
    return float4(c, 1.0);
}
