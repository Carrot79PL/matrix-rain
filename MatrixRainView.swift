import ScreenSaver
import Metal
import QuartzCore
import CoreText
import AppKit
import ImageIO
import UniformTypeIdentifiers
import AVFoundation
import os
import CoreMedia
import CoreVideo

private let shaderSrc = """
#include <metal_stdlib>
using namespace metal;

struct U {
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
struct VO { float4 pos [[position]]; float2 uv; };

vertex VO vs(uint vid [[vertex_id]]) {
    float2 p = float2((vid << 1) & 2, vid & 2);
    VO o;
    o.pos = float4(p * 2.0 - 1.0, 0.0, 1.0);
    o.uv = float2(p.x, 1.0 - p.y);
    return o;
}

float hash(float2 p) {
    float3 p3 = fract(float3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

float4 layerColor(VO in, constant U& u, texture2d<float> atlas, texture2d<float> imgA, texture2d<float> imgB,
                  float cs, float seed, float blur, float dim) {
    constexpr sampler s(filter::linear, mip_filter::linear, address::clamp_to_edge);
    float cell = u.cell * cs;
    float cell0 = u.cell0 * cs;
    float2 gc = float2(ceil(u.res.x / cell0), ceil(u.res.y / cell0)) * 0.5;
    float2 g = (in.uv * u.res - 0.5 * u.res) / cell + gc;
    float2 id = floor(g);
    float2 f = fract(g);
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
        float len = mix(8.0, 36.0, h1);
        float spd = mix(7.0, 22.0, h2) * u.speed;
        float cyc = rows + len + u.gap * rows * h3 * 2.0;
        float pos = floor(fmod(u.time * spd + h3 * cyc * 7.0, cyc));
        float d = pos - id.y;
        if (d >= 0.0 && d < len) {
            float t = 1.0 - d / len;
            float sd = mix(0.4, 1.0, hash(float2(idS.x, float(i) * 17.0 + 4.0)));
            float sb = pow(t, 1.6) * mix(0.45, 1.0, sd);
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
        float3 pa = imgA.sample(s, iuv, level(u.imgLod)).rgb;
        float3 pb = imgB.sample(s, iuv, level(u.imgLod)).rgb;
        float thr = hash(idS * 2.3 + 5.0) * 0.4 + clamp(id.y / rows, 0.0, 1.0) * 0.6;
        float sw = u.dissolve > 0.5 ? step(thr, u.imgT) : u.imgT;
        pic = mix(pa, pb, sw);
        if (u.dissolve > 0.5 && u.imgT > 0.001 && u.imgT < 0.999) dissBoost = exp(-pow((u.imgT - thr) * 12.0, 2.0));
        L = clamp((dot(pic, float3(0.299, 0.587, 0.114)) - mix(0.15, 0.05, u.camera)) * mix(1.6, 2.0, u.camera), 0.0, 1.0);
    }
    float rate = mix(0.3, 3.0, hash(idS + 7.7));
    float tick = floor(u.time * rate + hash(idS + 1.1) * 50.0);
    float rnd = hash(idS * 1.37 + tick * 0.731);
    float amb = step(0.5, hash(idS + 9.1)) * 0.08 * (0.5 + 0.5 * hash(idS + tick)) * (1.0 - step(0.001, u.imgMix));
    float bRain = max(b, amb) * mix(1.0, 0.25 + 0.9 * L, u.imgMix);
    head *= mix(1.0, 0.4 + 0.7 * L, u.imgMix);
    if (u.wave > 0.001) {
        float cn = floor(u.time / 16.0);
        float ph = fract(u.time / 16.0);
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
    float fx = mix(f.x, 1.0 - f.x, flip);
    float2 cellXY = float2(fmod(gi, 8.0), floor(gi / 8.0));
    float2 uv = (cellXY + 0.5 + (float2(fx, f.y) - 0.5) * 0.74) / 8.0;
    float gl = atlas.sample(s, uv, bias((1.0 - dep) * 2.0 + blur)).r;
    float2 e = smoothstep(0.0, 0.05, f) * smoothstep(0.0, 0.05, 1.0 - f);
    gl *= e.x * e.y;

    float3 pal = mix(u.tintDark.rgb, u.tintBright.rgb, clamp(bRain * 1.15, 0.0, 1.0));
    float3 cRain = pal * bRain * u.bright;
    float3 scol = u.tintBright.rgb;
    if (u.imgColor > 0.5) scol = mix(float3(1.0), pic / max(max(max(pic.r, pic.g), pic.b), 0.05), 0.9);
    float3 cSteady = scol * bSteady * u.bright * 0.95;
    float3 c = max(cRain, cSteady);
    c = mix(c, u.tintBright.rgb * 0.9, neck * 0.5);
    c = mix(c, mix(u.tintBright.rgb, float3(1.0), 0.8) * 1.7, head);
    return float4(c * gl * dim, 1.0);
}

float4 sceneColor(VO in, constant U& u, texture2d<float> atlas, texture2d<float> imgA, texture2d<float> imgB) {
    float4 c = layerColor(in, u, atlas, imgA, imgB, 1.0, 0.0, 0.0, 1.0);
    if (u.depth > 0.001) {
        c.rgb += layerColor(in, u, atlas, imgA, imgB, 0.55, 1.7, 0.0, 0.45 * u.depth).rgb;
        c.rgb += layerColor(in, u, atlas, imgA, imgB, 2.1, 3.3, 2.2, 0.55 * u.depth).rgb;
    }
    return c;
}

fragment float4 scene(VO in [[stage_in]], constant U& u [[buffer(0)]],
                      texture2d<float> atlas [[texture(0)]],
                      texture2d<float> imgA [[texture(1)]],
                      texture2d<float> imgB [[texture(2)]],
                      texture2d<float> hist [[texture(3)]]) {
    float3 c = sceneColor(in, u, atlas, imgA, imgB).rgb;
    if (u.ghostK > 0.001) c = max(c, hist.read(uint2(in.pos.xy)).rgb * u.ghostK);
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
        float spd = mix(0.05, 0.16, h2);
        float cy = fract(t * spd + h * 3.0);
        float2 center = float2(0.2 + 0.6 * h2, cy);
        float2 d = fract(p) - center;
        float r = mix(0.09, 0.2, h);
        float dist = length(d * float2(1.0, 0.8));
        float drop = smoothstep(r, r * 0.4, dist);
        float tr = smoothstep(0.035, 0.0, abs(d.x)) * step(d.y, 0.0) * smoothstep(-0.7, 0.0, d.y);
        off += -(d / r) * drop * 0.012 + float2(d.x, 0.0) * tr * 0.004;
        hl += drop * smoothstep(0.0, 0.5, -d.y / r + 0.5) * 0.06 + tr * 0.01;
    }
    return float3(off, hl);
}

fragment float4 comp(VO in [[stage_in]], constant U& u [[buffer(0)]], texture2d<float> scn [[texture(0)]]) {
    constexpr sampler s(filter::linear, mip_filter::linear, address::clamp_to_edge);
    float curve = u.p1;
    float vg = u.p2;
    float2 q0 = in.uv - 0.5;
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
    float tn = fract(u.time * 2.0);
    float ev = step(1.0 - u.noise * 0.18, hash(float2(gn, 9.0)));
    if (ev > 0.5) {
        uv.y = fract(uv.y + 0.3 * (1.0 - tn) * (1.0 - tn) * hash(float2(gn, 4.0)));
        uv.x += (hash(float2(floor(uv.y * 40.0), gn)) - 0.5) * 0.04 * (1.0 - tn);
    }
    float2 q = cuv - 0.5;
    float2 off = q * 0.0035 * (1.0 + curve);
    float3 base = float3(scn.sample(s, uv + off, level(0)).r,
                         scn.sample(s, uv, level(0)).g,
                         scn.sample(s, uv - off, level(0)).b);
    float3 bl = scn.sample(s, uv, level(1)).rgb * 0.35
              + scn.sample(s, uv, level(2)).rgb * 0.55
              + scn.sample(s, uv, level(3)).rgb * 0.75
              + scn.sample(s, uv, level(4)).rgb * 0.9
              + scn.sample(s, uv, level(5)).rgb * 0.8
              + scn.sample(s, uv, level(6)).rgb * 0.6;
    float3 tint = normalize(u.tintBright.rgb + 0.15);
    float3 c = base + bl * (0.35 + 0.65 * tint / max(max(tint.r, tint.g), tint.b)) * u.glow * (1.0 + u.audio * 1.6);
    c *= 1.0 + gb * 0.6;
    c += (u.tintBright.rgb * 0.8 + 0.1) * wf.z * u.wet;
    c += ev * step(0.985, hash(float2(floor(cuv.y * 300.0), gn + floor(u.time * 30.0)))) * u.tintBright.rgb * 0.7;

    // CRT: linie skanowania, maska luminoforu, pasmo odświeżania
    float sl = 0.5 + 0.5 * sin(in.pos.y * 2.0943951);
    c *= 1.0 - u.scan * 0.45 * sl;
    float ph = fmod(in.pos.x, 3.0);
    float3 mask = float3(ph < 1.0 ? 1.0 : 0.70, (ph >= 1.0 && ph < 2.0) ? 1.0 : 0.70, ph >= 2.0 ? 1.0 : 0.70);
    c *= mix(float3(1.0), mask * 1.15, u.mask * 0.8);
    float bd = cuv.y - fract(u.time * 0.07);
    bd -= round(bd);
    c *= 1.0 + u.roll * 0.6 * exp(-bd * bd * 160.0);
    c *= 1.0 + u.roll * 0.05 * sin(u.time * 90.0);

    // winieta i zaokrąglony kształt ekranu
    c *= clamp(1.0 - dot(q, q) * (0.3 + 2.2 * vg), 0.0, 1.0);
    c *= 1.0 - curve * 0.5 * smoothstep(0.30, 0.52, max(abs(q0.x), abs(q0.y)) * 1.0 + dot(q0, q0) * 0.25);

    float flick = 1.0 + 0.012 * sin(u.time * 41.0) + 0.008 * sin(u.time * 7.3);
    float grain = (hash(in.uv * u.res + fract(u.time) * 91.0) - 0.5) * 0.07 * u.grain;
    c = c * flick + grain * (0.3 + c.g);
    c = c / (1.0 + c * 0.35);
    c = max(c, 0.0);
    return float4(c, 1.0);
}
"""

private struct Uniforms {
    var res: SIMD2<Float>
    var cell: Float
    var time: Float
    var streams: Float
    var speed: Float
    var bright: Float
    var glow: Float
    var nGlyph: Float
    var gap: Float
    var imgMix: Float
    var imgT: Float
    var imgColor: Float
    var imgLod: Float
    var glitch: Float
    var imgAsp: Float
    var mirror: Float
    var camera: Float
    var p1: Float
    var p2: Float
    var scan: Float
    var mask: Float
    var roll: Float
    var grain: Float
    var cell0: Float
    var wet: Float
    var ghostK: Float
    var wave: Float
    var depth: Float
    var noise: Float
    var dissolve: Float
    var audio: Float
    var tintDark: SIMD4<Float>
    var tintBright: SIMD4<Float>
}

private let themes: [(String, String, SIMD4<Float>, SIMD4<Float>)] = [
    ("Zielony klasyczny", "Classic green", SIMD4(0.00, 0.22, 0.05, 1), SIMD4(0.10, 1.00, 0.30, 1)),
    ("Czerwona pigułka", "Red pill", SIMD4(0.28, 0.02, 0.02, 1), SIMD4(1.00, 0.12, 0.10, 1)),
    ("Niebieska pigułka", "Blue pill", SIMD4(0.00, 0.12, 0.28, 1), SIMD4(0.15, 0.65, 1.00, 1)),
    ("Złoto", "Gold", SIMD4(0.26, 0.15, 0.00, 1), SIMD4(1.00, 0.74, 0.15, 1)),
    ("Fiolet", "Violet", SIMD4(0.15, 0.02, 0.25, 1), SIMD4(0.75, 0.30, 1.00, 1)),
    ("Biały / mono", "White / mono", SIMD4(0.14, 0.15, 0.17, 1), SIMD4(0.88, 0.95, 1.00, 1)),
]

private var assocTargets: UInt8 = 0
private var assocOwner: UInt8 = 0

private let plog = Logger(subsystem: "com.bluerootstudio.MatrixRain", category: "prefs")

private struct Preset { let pl: String; let en: String; let theme: Int; let v: [String: Float] }

private let presets: [Preset] = [
    Preset(pl: "Film", en: "Movie", theme: 0, v: ["streams": 3.4, "speed": 1, "size": 18, "glow": 1, "bright": 1, "glitch": 0.1, "curve": 0.2, "scan": 0.2, "mask": 0.2, "roll": 0.2, "grain": 0.5, "vignette": 0.6, "wet": 0, "ghost": 0.3, "wave": 0, "depth": 0, "noise": 0, "zoom": 0]),
    Preset(pl: "Retro CRT", en: "Retro CRT", theme: 0, v: ["size": 20, "glow": 1.3, "glitch": 0.2, "curve": 0.8, "scan": 0.7, "mask": 0.6, "roll": 0.6, "grain": 0.8, "vignette": 0.8, "ghost": 0.5, "noise": 0.3, "wet": 0, "wave": 0, "depth": 0, "zoom": 0]),
    Preset(pl: "Czerwona pigułka", en: "Red pill", theme: 1, v: ["glow": 1.2, "glitch": 0.3, "wave": 0.6, "depth": 0.4, "ghost": 0.3, "wet": 0, "noise": 0, "zoom": 0]),
    Preset(pl: "Deszczowa noc", en: "Rainy night", theme: 2, v: ["wet": 1, "ghost": 0.4, "depth": 0.5, "glow": 1.4, "size": 22, "speed": 0.8, "wave": 0, "noise": 0, "zoom": 0, "glitch": 0.1]),
    Preset(pl: "Głębia", en: "Deep dive", theme: 0, v: ["depth": 1, "zoom": 0.6, "speed": 1.3, "size": 14, "glow": 1.1, "wet": 0, "ghost": 0.3, "wave": 0, "noise": 0, "glitch": 0.1]),
    Preset(pl: "Złoty cyber", en: "Gold cyber", theme: 3, v: ["scan": 0.4, "glow": 1.3, "wave": 0.5, "ghost": 0.4, "wet": 0, "depth": 0.3, "noise": 0, "zoom": 0, "glitch": 0.2]),
    Preset(pl: "Burza glitchy", en: "Glitch storm", theme: 4, v: ["glitch": 0.9, "noise": 0.8, "wave": 0.8, "speed": 1.5, "grain": 1, "wet": 0, "ghost": 0.3, "depth": 0, "zoom": 0]),
    Preset(pl: "Minimalizm", en: "Minimal mono", theme: 5, v: ["glow": 0.6, "curve": 0, "scan": 0, "mask": 0, "roll": 0, "grain": 0.2, "vignette": 0.4, "size": 16, "wet": 0, "ghost": 0, "wave": 0, "depth": 0, "noise": 0, "zoom": 0, "glitch": 0]),
]

private final class PrefTarget: NSObject {
    let key: String
    let onChange: () -> Void
    weak var defaults: ScreenSaverDefaults?
    init(key: String, defaults: ScreenSaverDefaults?, onChange: @escaping () -> Void) {
        self.key = key; self.defaults = defaults; self.onChange = onChange
    }
    @objc func sliderChanged(_ sender: NSSlider) {
        plog.notice("slider \(self.key, privacy: .public)=\(sender.doubleValue, privacy: .public)")
        defaults?.set(sender.doubleValue, forKey: key)
        defaults?.synchronize()
        onChange()
    }
    @objc func popChanged(_ sender: NSPopUpButton) {
        plog.notice("popup \(self.key, privacy: .public)=\(sender.indexOfSelectedItem, privacy: .public)")
        defaults?.set(Double(sender.indexOfSelectedItem), forKey: key)
        defaults?.synchronize()
        onChange()
    }
}

@objc(MatrixRainView)
public class MatrixRainView: ScreenSaverView {
    private var device: MTLDevice!
    private var queue: MTLCommandQueue!
    private var scenePSO: MTLRenderPipelineState!
    private var compPSO: MTLRenderPipelineState!
    private var atlas: MTLTexture!
    private var dummy: MTLTexture!
    private var scenes: [MTLTexture] = []
    private var sceneIdx = 0
    private var histValid = false
    private var nGlyph: Float = 1
    private let metalLayer = CAMetalLayer()
    private let t0 = CACurrentMediaTime()
    private var defaults: ScreenSaverDefaults?
    private var sheet: NSWindow?
    private var targets: [PrefTarget] = []
    private var photoLabel: NSTextField?

    private var streams: Float = 3.4
    private var speed: Float = 1.0
    private var sizePts: Float = 18
    private var glow: Float = 1.0
    private var bright: Float = 1.0
    private var glitch: Float = 0.2
    private var imgMix: Float = 0.9
    private var period: Float = 25
    private var mode = 0
    private var theme = 0
    private var photoColor = 0
    private var mirror: Float = 1
    private var curve: Float = 0.35
    private var scanV: Float = 0.35
    private var maskV: Float = 0.35
    private var rollV: Float = 0.35
    private var zoomAmt: Float = 0
    private var zoomPeriod: Float = 40
    private var wetV: Float = 0
    private var ghostV: Float = 0
    private var waveV: Float = 0
    private var depthV: Float = 0
    private var noiseV: Float = 0
    private var dissolveV: Float = 0
    private var alarmMode = 0
    private var grainV: Float = 0.5
    private var vign: Float = 0.5
    private var camera: CameraSource?
    private var video: VideoSource?
    private var audioMeter: AudioLevel?
    private var audioSens: Float = 0
    private var presetSel = 0
    private var autoMin = 0
    private var presetOrder: [Int] = []
    private var curVals: [String: Float] = [:]
    private var lastEffTime: Float = 0
    private var videoLabel: NSTextField?

    private var photoTextures: [MTLTexture] = []
    private var photoVersion: Double = -1
    private var clockTex: MTLTexture?
    private var clockStamp = ""
    private var lastPrefsLoad: CFTimeInterval = 0
    private var lastSig = ""

    public override init?(frame: NSRect, isPreview: Bool) {
        super.init(frame: frame, isPreview: isPreview)
        setup()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        animationTimeInterval = 1.0 / 60.0
        let id = Bundle(for: MatrixRainView.self).bundleIdentifier ?? "com.bluerootstudio.MatrixRain"
        defaults = ScreenSaverDefaults(forModuleWithName: id)
        defaults?.register(defaults: ["streams": 3.4, "speed": 1.0, "size": 18.0, "glow": 1.0, "bright": 1.0,
                                      "glitch": 0.2, "imgMix": 0.9, "period": 25.0,
                                      "lang": (Locale.preferredLanguages.first?.hasPrefix("pl") ?? false) ? 0.0 : 1.0, "mode": 0.0, "theme": 0.0, "photoColor": 0.0, "mirror": 1.0, "curve": 0.35, "scan": 0.35, "mask": 0.35, "roll": 0.35, "grain": 0.5, "vignette": 0.5, "zoom": 0.0, "zoomPeriod": 40.0,
                                      "wet": 0.0, "ghost": 0.0, "wave": 0.0, "depth": 0.0, "noise": 0.0,
                                      "alarm": 0.0, "dissolve": 0.0, "audio": 0.0, "preset": 0.0, "autoPreset": 0.0, "videoFile": ""])

        guard let dev = MTLCreateSystemDefaultDevice() else { return }
        device = dev
        queue = dev.makeCommandQueue()
        metalLayer.device = dev
        metalLayer.pixelFormat = .bgra8Unorm
        metalLayer.framebufferOnly = true
        metalLayer.isOpaque = true
        self.layer = metalLayer
        self.wantsLayer = true

        do {
            let lib = try dev.makeLibrary(source: shaderSrc, options: nil)
            func pso(_ frag: String, _ fmt: MTLPixelFormat) throws -> MTLRenderPipelineState {
                let d = MTLRenderPipelineDescriptor()
                d.vertexFunction = lib.makeFunction(name: "vs")
                d.fragmentFunction = lib.makeFunction(name: frag)
                d.colorAttachments[0].pixelFormat = fmt
                return try dev.makeRenderPipelineState(descriptor: d)
            }
            scenePSO = try pso("scene", .rgba16Float)
            compPSO = try pso("comp", .bgra8Unorm)
        } catch {
            NSLog("MatrixRain shader error: \(error)")
            return
        }
        let dd = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba8Unorm, width: 1, height: 1, mipmapped: false)
        dummy = dev.makeTexture(descriptor: dd)
        buildAtlas()
        loadPrefs()
    }

    private func loadPrefs() {
        guard let d = defaults else { return }
        d.synchronize()
        lastPrefsLoad = CACurrentMediaTime()
        streams = Float(d.double(forKey: "streams"))
        speed = Float(d.double(forKey: "speed"))
        sizePts = Float(d.double(forKey: "size"))
        glow = Float(d.double(forKey: "glow"))
        bright = Float(d.double(forKey: "bright"))
        glitch = Float(d.double(forKey: "glitch"))
        imgMix = Float(d.double(forKey: "imgMix"))
        period = max(3, Float(d.double(forKey: "period")))
        mode = Int(d.double(forKey: "mode"))
        theme = min(max(Int(d.double(forKey: "theme")), 0), themes.count - 1)
        photoColor = Int(d.double(forKey: "photoColor"))
        mirror = Float(d.double(forKey: "mirror"))
        curve = Float(d.double(forKey: "curve"))
        scanV = Float(d.double(forKey: "scan"))
        maskV = Float(d.double(forKey: "mask"))
        rollV = Float(d.double(forKey: "roll"))
        grainV = Float(d.double(forKey: "grain"))
        zoomAmt = Float(d.double(forKey: "zoom"))
        zoomPeriod = max(5, Float(d.double(forKey: "zoomPeriod")))
        wetV = Float(d.double(forKey: "wet"))
        ghostV = Float(d.double(forKey: "ghost"))
        waveV = Float(d.double(forKey: "wave"))
        depthV = Float(d.double(forKey: "depth"))
        noiseV = Float(d.double(forKey: "noise"))
        dissolveV = Float(d.double(forKey: "dissolve"))
        alarmMode = Int(d.double(forKey: "alarm"))
        audioSens = Float(d.double(forKey: "audio"))
        presetSel = Int(d.double(forKey: "preset"))
        autoMin = [0, 1, 3, 5, 10][min(max(Int(d.double(forKey: "autoPreset")), 0), 4)]
        vign = Float(d.double(forKey: "vignette"))
        let sig = "\(mode) \(theme) \(sizePts) \(streams) \(glow) \(glitch) \(curve) \(scanV) \(maskV) \(rollV) \(grainV) \(vign) \(lang)"
        if sig != lastSig { lastSig = sig; plog.notice("prefs changed: \(sig, privacy: .public)") }
        let ver = d.double(forKey: "imagesVersion")
        if device != nil && ver != photoVersion {
            photoVersion = ver
            rebuildPhotos()
        }
    }

    // MARK: Tekstury

    private func texture(from ctx: CGContext, w: Int, h: Int) -> MTLTexture? {
        let td = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba8Unorm, width: w, height: h, mipmapped: true)
        guard let tex = device.makeTexture(descriptor: td), let data = ctx.data else { return nil }
        tex.replace(region: MTLRegionMake2D(0, 0, w, h), mipmapLevel: 0, withBytes: data, bytesPerRow: ctx.bytesPerRow)
        if let cmd = queue.makeCommandBuffer(), let blit = cmd.makeBlitCommandEncoder() {
            blit.generateMipmaps(for: tex)
            blit.endEncoding()
            cmd.commit()
            cmd.waitUntilCompleted()
        }
        return tex
    }

    private func makeCtx(_ w: Int, _ h: Int) -> CGContext? {
        CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                  space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
    }

    private func rebuildPhotos() {
        photoTextures = []
        guard let arr = defaults?.array(forKey: "images") as? [Data] else { return }
        for data in arr {
            guard let src = CGImageSourceCreateWithData(data as CFData, nil),
                  let img = CGImageSourceCreateImageAtIndex(src, 0, nil),
                  let ctx = makeCtx(640, 400) else { continue }
            ctx.draw(img, in: CGRect(x: 0, y: 0, width: 640, height: 400))
            if let t = texture(from: ctx, w: 640, h: 400) { photoTextures.append(t) }
        }
    }

    private func updateClock() {
        let c = Calendar.current.dateComponents([.hour, .minute], from: Date())
        let stamp = String(format: "%02d:%02d", c.hour ?? 0, c.minute ?? 0)
        if stamp == clockStamp && clockTex != nil { return }
        clockStamp = stamp
        guard let ctx = makeCtx(640, 400) else { return }
        ctx.setFillColor(gray: 0, alpha: 1)
        ctx.fill(CGRect(x: 0, y: 0, width: 640, height: 400))
        func line(_ size: CGFloat) -> CTLine {
            let attrs: [CFString: Any] = [kCTFontAttributeName: CTFontCreateWithName("HelveticaNeue-Bold" as CFString, size, nil),
                                          kCTForegroundColorAttributeName: CGColor(gray: 1, alpha: 1)]
            return CTLineCreateWithAttributedString(NSAttributedString(string: stamp, attributes: attrs as [NSAttributedString.Key: Any]))
        }
        var l = line(260)
        let w0 = CTLineGetBoundsWithOptions(l, []).width
        if w0 > 560 { l = line(260 * 560 / w0) }
        let r = CTLineGetBoundsWithOptions(l, [])
        ctx.textPosition = CGPoint(x: 320 - r.midX, y: 200 - r.midY)
        CTLineDraw(l, ctx)
        clockTex = texture(from: ctx, w: 640, h: 400)
    }

    private func imageItems() -> [MTLTexture] {
        if mode != 6, let c = camera { c.stop(); camera = nil }
        if mode != 4, let v = video { v.stop(); video = nil }
        switch mode {
        case 4:
            let path = defaults?.string(forKey: "videoFile") ?? ""
            if video != nil && video!.path != path { video!.stop(); video = nil }
            if video == nil, !path.isEmpty, FileManager.default.fileExists(atPath: path) { video = VideoSource(path: path, device: device) }
            return video?.current.map { [$0] } ?? []
        case 6:
            if camera == nil { let c = CameraSource(device: device); camera = c; c.start() }
            return camera?.current.map { [$0] } ?? []
        case 1: return photoTextures
        case 2: updateClock(); return clockTex.map { [$0] } ?? []
        case 3:
            updateClock()
            return photoTextures + (clockTex.map { [$0] } ?? [])
        default: return []
        }
    }

    // MARK: Atlas

    private func makeFont() -> CTFont {
        if let url = Bundle(for: MatrixRainView.self).url(forResource: "Matrix-Code", withExtension: "ttf") {
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
            if let descs = CTFontManagerCreateFontDescriptorsFromURL(url as CFURL) as? [CTFontDescriptor],
               let first = descs.first {
                return CTFontCreateWithFontDescriptor(first, 80, nil)
            }
        }
        return CTFontCreateWithName("Hiragino Sans" as CFString, 80, nil)
    }

    private func buildAtlas() {
        let font = makeFont()
        var scalars: [UInt32] = Array(0x30A0...0x30FF)
        scalars += Array(0x30...0x39)
        scalars += [0x22, 0x2A, 0x2B, 0x3A, 0x3C, 0x3E, 0x7C, 0xA6, 0x254C, 0x25AA, 0x7A]
        var glyphs: [CGGlyph] = []
        for s in scalars {
            var ch = UniChar(s)
            var g = CGGlyph(0)
            if CTFontGetGlyphsForCharacters(font, &ch, &g, 1), g != 0 { glyphs.append(g) }
            if glyphs.count == 64 { break }
        }
        if glyphs.isEmpty { glyphs = [CGGlyph(1)] }
        nGlyph = Float(glyphs.count)

        let size = 1024, cell = 128
        guard let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: size,
                                  space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue) else { return }
        ctx.setFillColor(gray: 0, alpha: 1)
        ctx.fill(CGRect(x: 0, y: 0, width: size, height: size))
        ctx.setFillColor(gray: 1, alpha: 1)
        ctx.setAllowsFontSmoothing(false)
        for (i, g0) in glyphs.enumerated() {
            var g = g0
            var r = CGRect.zero
            CTFontGetBoundingRectsForGlyphs(font, .horizontal, &g, &r, 1)
            let col = i % 8, row = i / 8
            let cx = CGFloat(col * cell) + CGFloat(cell) / 2
            let cy = CGFloat((7 - row) * cell) + CGFloat(cell) / 2
            var pos = CGPoint(x: cx - r.midX, y: cy - r.midY)
            CTFontDrawGlyphs(font, &g, &pos, 1, ctx)
        }
        let td = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .r8Unorm, width: size, height: size, mipmapped: true)
        guard let tex = device.makeTexture(descriptor: td), let data = ctx.data else { return }
        tex.replace(region: MTLRegionMake2D(0, 0, size, size), mipmapLevel: 0, withBytes: data, bytesPerRow: size)
        if let cmd = queue.makeCommandBuffer(), let blit = cmd.makeBlitCommandEncoder() {
            blit.generateMipmaps(for: tex)
            blit.endEncoding()
            cmd.commit()
            cmd.waitUntilCompleted()
        }
        atlas = tex
    }

    // MARK: Render

    private struct Eff { var v: [String: Float]; var theme: Int }

    private func effective(_ t: Float) -> Eff {
        let base: [String: Float] = ["streams": streams, "speed": speed, "size": sizePts, "glow": glow, "bright": bright,
                                     "glitch": glitch, "curve": curve, "scan": scanV, "mask": maskV, "roll": rollV,
                                     "grain": grainV, "vignette": vign, "wet": wetV, "ghost": ghostV, "wave": waveV,
                                     "depth": depthV, "noise": noiseV, "zoom": zoomAmt]
        var target = base
        var th = theme
        var idx = presetSel
        if autoMin > 0 {
            if presetOrder.isEmpty { presetOrder = Array(0..<presets.count).shuffled() }
            let slot = max(0, Int(t / (Float(autoMin) * 60)))
            idx = presetOrder[slot % presets.count] + 1
        }
        if idx > 0 && idx <= presets.count {
            let p = presets[idx - 1]
            for (k, x) in p.v { target[k] = x }
            th = p.theme
        }
        let dt = max(0, min(0.2, t - lastEffTime))
        lastEffTime = t
        if curVals.isEmpty { curVals = target }
        let a = 1 - exp(-dt / 1.2)
        for (k, x) in target { let c = curVals[k] ?? x; curVals[k] = c + (x - c) * a }
        return Eff(v: curVals, theme: th)
    }

    private func render(target: MTLTexture, drawable: CAMetalDrawable?, time: Float, scale: Float) {
        guard let atlas = atlas, scenePSO != nil, let cmd = queue.makeCommandBuffer() else { return }
        let w = target.width, h = target.height
        let eff = effective(time)
        func e(_ k: String) -> Float { eff.v[k] ?? 0 }
        let streams = e("streams"), speed = e("speed"), sizePts = e("size"), glow = e("glow"), bright = e("bright")
        let glitch = e("glitch"), curve = e("curve"), scanV = e("scan"), maskV = e("mask"), rollV = e("roll")
        let grainV = e("grain"), vign = e("vignette"), wetV = e("wet"), ghostV = e("ghost"), waveV = e("wave")
        let depthV = e("depth"), noiseV = e("noise"), zoomAmt = e("zoom")
        let theme = eff.theme
        if audioSens > 0.001 {
            if audioMeter == nil { let a = AudioLevel(); audioMeter = a; a.start() }
        } else if let a = audioMeter { a.stop(); audioMeter = nil }
        let audioK: Float = audioSens > 0.001 ? min(1, (audioMeter?.level ?? 0) * audioSens * 1.5) : 0
        if scenes.count != 2 || scenes[0].width != w || scenes[0].height != h {
            let d = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba16Float, width: w, height: h, mipmapped: true)
            d.usage = [.renderTarget, .shaderRead]
            d.storageMode = .private
            scenes = [device.makeTexture(descriptor: d), device.makeTexture(descriptor: d)].compactMap { $0 }
            histValid = false
        }
        guard scenes.count == 2 else { return }
        let scene = scenes[sceneIdx]
        let histTex: MTLTexture = (ghostV > 0.001 && histValid) ? scenes[1 - sceneIdx] : dummy

        // obraz: wybór bieżącego i następnego z fade
        let items = imageItems()
        var texA: MTLTexture = dummy, texB: MTLTexture = dummy
        var imgT: Float = 0
        var mix: Float = 0
        if !items.isEmpty {
            let x = time / period
            let slot = Int(floor(x))
            texA = items[slot % items.count]
            texB = items[(slot + 1) % items.count]
            if items.count > 1 {
                let ph = x - Float(slot)
                let k = min(max((ph - 0.85) / 0.15, 0), 1)
                imgT = k * k * (3 - 2 * k)
            } else { texB = texA }
            mix = imgMix
        }
        let cell0 = max(5, sizePts * scale)
        let zf: Float = zoomAmt > 0.001 ? pow(2, zoomAmt * 1.3 * sin(2 * .pi * time / zoomPeriod)) : 1
        let cell = max(4, cell0 * zf)
        let cols = Float(w) / cell
        let lod = max(0, log2(Float(texA.width) / max(cols, 1)))
        let asp = items.isEmpty ? Float(1.6) : Float(texA.width) / Float(texA.height)
        let isCam: Float = ((mode == 6 || mode == 4) && !items.isEmpty) ? 1 : 0
        let th = themes[theme]
        var tDark = th.2, tBright = th.3
        if alarmMode > 0 {
            let interval = [60, 60, 15, 5][min(alarmMode, 3)]
            let dc = Calendar.current.dateComponents([.minute, .second], from: Date())
            let secs = Double(((dc.minute ?? 0) % interval) * 60 + (dc.second ?? 0))
            if secs < 12 {
                let k = Float(sin(Double.pi * secs / 12))
                tDark += (SIMD4<Float>(0.28, 0.02, 0.02, 1) - tDark) * k
                tBright += (SIMD4<Float>(1.0, 0.12, 0.10, 1) - tBright) * k
            }
        }
        var u = Uniforms(res: SIMD2(Float(w), Float(h)), cell: cell, time: time,
                         streams: streams, speed: speed, bright: bright, glow: glow,
                         nGlyph: nGlyph, gap: max(0, 1 - streams / 4) * 0.8,
                         imgMix: mix, imgT: imgT, imgColor: photoColor == 1 ? 1 : 0, imgLod: lod,
                         glitch: glitch, imgAsp: asp, mirror: mode == 6 ? mirror : 0, camera: isCam, p1: curve, p2: vign, scan: scanV, mask: maskV, roll: rollV, grain: grainV, cell0: cell0, wet: wetV, ghostK: ghostV > 0.001 ? 0.80 + 0.17 * ghostV : 0, wave: waveV, depth: depthV, noise: noiseV, dissolve: dissolveV, audio: audioK, tintDark: tDark, tintBright: tBright)

        if isCam > 0.5, let blit = cmd.makeBlitCommandEncoder() {
            blit.generateMipmaps(for: texA)
            blit.endEncoding()
        }
        let p1 = MTLRenderPassDescriptor()
        p1.colorAttachments[0].texture = scene
        p1.colorAttachments[0].loadAction = .dontCare
        p1.colorAttachments[0].storeAction = .store
        if let e = cmd.makeRenderCommandEncoder(descriptor: p1) {
            e.setRenderPipelineState(scenePSO)
            e.setFragmentBytes(&u, length: MemoryLayout<Uniforms>.stride, index: 0)
            e.setFragmentTexture(atlas, index: 0)
            e.setFragmentTexture(texA, index: 1)
            e.setFragmentTexture(texB, index: 2)
            e.setFragmentTexture(histTex, index: 3)
            e.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
            e.endEncoding()
        }
        if let blit = cmd.makeBlitCommandEncoder() {
            blit.generateMipmaps(for: scene)
            blit.endEncoding()
        }
        let p2 = MTLRenderPassDescriptor()
        p2.colorAttachments[0].texture = target
        p2.colorAttachments[0].loadAction = .dontCare
        p2.colorAttachments[0].storeAction = .store
        if let e = cmd.makeRenderCommandEncoder(descriptor: p2) {
            e.setRenderPipelineState(compPSO)
            e.setFragmentBytes(&u, length: MemoryLayout<Uniforms>.stride, index: 0)
            e.setFragmentTexture(scene, index: 0)
            e.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
            e.endEncoding()
        }
        sceneIdx = 1 - sceneIdx
        histValid = true
        if let drawable = drawable { cmd.present(drawable) }
        cmd.commit()
        if drawable == nil { cmd.waitUntilCompleted() }
    }

    public override func startAnimation() {
        loadPrefs()
        super.startAnimation()
    }

    public override func animateOneFrame() {
        guard device != nil else { return }
        if CACurrentMediaTime() - lastPrefsLoad > 0.5 { loadPrefs() }
        let scale = Float(window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2)
        let pw = max(1, Int(bounds.width * CGFloat(scale))), ph = max(1, Int(bounds.height * CGFloat(scale)))
        metalLayer.contentsScale = CGFloat(scale)
        metalLayer.drawableSize = CGSize(width: pw, height: ph)
        guard let drawable = metalLayer.nextDrawable() else { return }
        let saved = sizePts
        if isPreview { sizePts *= 0.5 }
        render(target: drawable.texture, drawable: drawable, time: Float(CACurrentMediaTime() - t0), scale: scale)
        sizePts = saved
    }

    public override func draw(_ rect: NSRect) {
        NSColor.black.setFill()
        rect.fill()
    }

    // MARK: API dla aplikacji Matrix Rain Cam

    @objc public func prepare() { loadPrefs() }

    @objc public var cameraStatus: String {
        switch camera?.state ?? 3 {
        case 0: return tr("Uruchamianie kamery…", "Starting camera…")
        case 1: return tr("Brak dostępu do kamery. Zezwól w Ustawienia systemu → Prywatność i ochrona → Kamera.",
                          "No camera access. Allow it in System Settings → Privacy & Security → Camera.")
        case 2: return tr("Nie znaleziono kamery.", "No camera found.")
        default: return ""
        }
    }

    @objc public func setOption(_ key: NSString, _ value: NSNumber) {
        defaults?.set(value.doubleValue, forKey: key as String)
        defaults?.synchronize()
        loadPrefs()
    }

    /// Pomocnik testowy / import: zapisuje miniatury zdjęć do ustawień.
    @objc public func importImagePaths(_ paths: NSArray) {
        var out: [Data] = []
        for case let p as String in paths {
            if out.count >= 12 { break }
            guard let src = CGImageSourceCreateWithURL(URL(fileURLWithPath: p) as CFURL, nil) else { continue }
            let opts: [CFString: Any] = [kCGImageSourceCreateThumbnailFromImageAlways: true,
                                         kCGImageSourceCreateThumbnailWithTransform: true,
                                         kCGImageSourceThumbnailMaxPixelSize: 1400]
            guard let th = CGImageSourceCreateThumbnailAtIndex(src, 0, opts as CFDictionary),
                  let ctx = makeCtx(640, 400) else { continue }
            let tw = CGFloat(th.width), thh = CGFloat(th.height)
            let sc = max(640 / tw, 400 / thh)
            ctx.interpolationQuality = .high
            ctx.draw(th, in: CGRect(x: (640 - tw * sc) / 2, y: (400 - thh * sc) / 2, width: tw * sc, height: thh * sc))
            guard let img = ctx.makeImage() else { continue }
            let rep = NSBitmapImageRep(cgImage: img)
            if let d = rep.representation(using: .jpeg, properties: [.compressionFactor: 0.8]) { out.append(d) }
        }
        defaults?.set(out, forKey: "images")
        defaults?.set(Date().timeIntervalSince1970, forKey: "imagesVersion")
        defaults?.synchronize()
        loadPrefs()
    }

    /// Pomocnik testowy: renderuje jedną klatkę do PNG.
    @objc public func snapshot(_ path: NSString) {
        guard device != nil else { return }
        loadPrefs()
        let w = 1440, h = 900
        let d = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: w, height: h, mipmapped: false)
        d.usage = [.renderTarget, .shaderRead]
        d.storageMode = .shared
        guard let tex = device.makeTexture(descriptor: d) else { return }
        render(target: tex, drawable: nil, time: Float(ProcessInfo.processInfo.environment["MATRIXRAIN_T"] ?? "") ?? 8.0, scale: 1)
        var bytes = [UInt8](repeating: 0, count: w * h * 4)
        tex.getBytes(&bytes, bytesPerRow: w * 4, from: MTLRegionMake2D(0, 0, w, h), mipmapLevel: 0)
        for i in stride(from: 0, to: bytes.count, by: 4) { bytes.swapAt(i, i + 2) }
        guard let ctx = CGContext(data: &bytes, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                                  space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue),
              let img = ctx.makeImage() else { return }
        let rep = NSBitmapImageRep(cgImage: img)
        if let png = rep.representation(using: .png, properties: [:]) {
            try? png.write(to: URL(fileURLWithPath: path as String))
        }
    }

    // MARK: Ustawienia

    private var lang: Int { Int(defaults?.double(forKey: "lang") ?? 0) }
    private func tr(_ pl: String, _ en: String) -> String { lang == 1 ? en : pl }
    private let author = "Tomasz Marchewka"
    private let version = "1.1"
    private let repoURL = "github.com/Carrot79PL/matrix-rain"

    public override var hasConfigureSheet: Bool { true }

    public override var configureSheet: NSWindow? {
        if let s = sheet { return s }
        let win = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 480, height: 560),
                           styleMask: [.titled], backing: .buffered, defer: false)
        win.title = "Matrix Rain"
        sheet = win
        plog.notice("configureSheet built v1.1 pid=\(ProcessInfo.processInfo.processIdentifier, privacy: .public)")
        buildSheet()
        return win
    }

    private func rebuildSheet() {
        DispatchQueue.main.async { [weak self] in self?.buildSheet() }
    }

    private func addSlider(_ v: NSView, _ y: inout CGFloat, _ text: String, _ key: String, _ lo: Double, _ hi: Double) {
        let l = NSTextField(labelWithString: text)
        l.frame = NSRect(x: 16, y: y, width: 170, height: 20)
        v.addSubview(l)
        let s = NSSlider(value: defaults?.double(forKey: key) ?? lo, minValue: lo, maxValue: hi, target: nil, action: nil)
        s.frame = NSRect(x: 190, y: y, width: 220, height: 20)
        let t = PrefTarget(key: key, defaults: defaults) { [weak self] in self?.loadPrefs() }
        s.target = t
        s.action = #selector(PrefTarget.sliderChanged(_:))
        targets.append(t)
        v.addSubview(s)
        y -= 36
    }

    private func addPopup(_ v: NSView, _ y: inout CGFloat, _ text: String, _ key: String, _ items: [String]) {
        let l = NSTextField(labelWithString: text)
        l.frame = NSRect(x: 16, y: y, width: 170, height: 20)
        v.addSubview(l)
        let p = NSPopUpButton(frame: NSRect(x: 186, y: y - 3, width: 228, height: 26), pullsDown: false)
        p.addItems(withTitles: items)
        p.selectItem(at: Int(defaults?.double(forKey: key) ?? 0))
        let t = PrefTarget(key: key, defaults: defaults) { [weak self] in self?.loadPrefs() }
        p.target = t
        p.action = #selector(PrefTarget.popChanged(_:))
        targets.append(t)
        v.addSubview(p)
        y -= 40
    }

    private func buildSheet() {
        guard let win = sheet else { return }
        let W: CGFloat = 480, H: CGFloat = 560
        let content = NSView(frame: NSRect(x: 0, y: 0, width: W, height: H))
        win.contentView = content
        targets = []

        let title = NSTextField(labelWithString: "Matrix Rain")
        title.font = NSFont.boldSystemFont(ofSize: 20)
        title.frame = NSRect(x: 20, y: H - 46, width: 260, height: 26)
        content.addSubview(title)
        let sub = NSTextField(labelWithString: tr("Autor: \(author) · wersja \(version)", "By \(author) · version \(version)"))
        sub.font = NSFont.systemFont(ofSize: 11)
        sub.textColor = .secondaryLabelColor
        sub.frame = NSRect(x: 20, y: H - 66, width: 300, height: 16)
        content.addSubview(sub)

        let lp = NSPopUpButton(frame: NSRect(x: W - 150, y: H - 50, width: 130, height: 26), pullsDown: false)
        lp.addItems(withTitles: ["Polski", "English"])
        lp.selectItem(at: lang)
        let lt = PrefTarget(key: "lang", defaults: defaults) { [weak self] in
            self?.loadPrefs()
            self?.rebuildSheet()
        }
        lp.target = lt
        lp.action = #selector(PrefTarget.popChanged(_:))
        targets.append(lt)
        content.addSubview(lp)

        let tabs = NSTabView(frame: NSRect(x: 12, y: 56, width: W - 24, height: H - 130))
        content.addSubview(tabs)
        func tab(_ name: String, _ build: (NSView, inout CGFloat) -> Void) {
            let item = NSTabViewItem(identifier: name)
            item.label = name
            let v = NSView(frame: NSRect(x: 0, y: 0, width: W - 44, height: H - 180))
            var y: CGFloat = 320
            build(v, &y)
            item.view = v
            tabs.addTabViewItem(item)
        }

        tab(tr("Wygląd", "Look")) { v, y in
            addPopup(v, &y, tr("Preset", "Preset"), "preset", [tr("Własne ustawienia", "Custom settings")] + presets.map { lang == 1 ? $0.en : $0.pl })
            addPopup(v, &y, tr("Auto-zmiana presetów", "Auto-switch presets"), "autoPreset",
                     [tr("Wyłączona", "Off"), tr("Co 1 min", "Every 1 min"), tr("Co 3 min", "Every 3 min"), tr("Co 5 min", "Every 5 min"), tr("Co 10 min", "Every 10 min")])
            addPopup(v, &y, tr("Motyw kolorów", "Color theme"), "theme", themes.map { lang == 1 ? $0.1 : $0.0 })
            addSlider(v, &y, tr("Rozmiar znaków", "Glyph size"), "size", 10, 40)
            addSlider(v, &y, tr("Jasność", "Brightness"), "bright", 0.4, 1.6)
            addSlider(v, &y, tr("Poświata", "Glow"), "glow", 0, 2)
            addSlider(v, &y, tr("Winieta", "Vignette"), "vignette", 0, 1)
        }
        tab(tr("Ruch", "Motion")) { v, y in
            addSlider(v, &y, tr("Gęstość", "Density"), "streams", 1, 4)
            addSlider(v, &y, tr("Prędkość", "Speed"), "speed", 0.3, 2.5)
            addSlider(v, &y, tr("Glitch", "Glitch"), "glitch", 0, 1)
            addSlider(v, &y, tr("Auto-zoom znaków", "Auto-zoom of glyphs"), "zoom", 0, 1)
            addSlider(v, &y, tr("Cykl zoomu (s)", "Zoom cycle (s)"), "zoomPeriod", 10, 120)
        }
        tab(tr("Efekty", "Effects")) { v, y in
            addSlider(v, &y, tr("Mokra szyba", "Wet glass"), "wet", 0, 1)
            addSlider(v, &y, tr("Duchy znaków", "Ghost trails"), "ghost", 0, 1)
            addSlider(v, &y, tr("Fala jasności", "Brightness wave"), "wave", 0, 1)
            addSlider(v, &y, tr("Głębia 3D", "3D depth"), "depth", 0, 1)
            addSlider(v, &y, tr("Zakłócenia sygnału", "Signal noise"), "noise", 0, 1)
            addSlider(v, &y, tr("Reakcja na dźwięk", "Sound reaction"), "audio", 0, 1)
            addPopup(v, &y, tr("Czerwony alarm", "Red alert"), "alarm",
                     [tr("Wyłączony", "Off"), tr("Co godzinę", "Every hour"), tr("Co 15 min", "Every 15 min"), tr("Co 5 min", "Every 5 min")])
        }
        tab(tr("Ekran CRT", "CRT")) { v, y in
            addSlider(v, &y, tr("Wygięcie ekranu", "Screen curvature"), "curve", 0, 1)
            addSlider(v, &y, tr("Linie skanowania", "Scanlines"), "scan", 0, 1)
            addSlider(v, &y, tr("Maska RGB", "RGB mask"), "mask", 0, 1)
            addSlider(v, &y, tr("Pasmo odświeżania", "Refresh band"), "roll", 0, 1)
            addSlider(v, &y, tr("Ziarno", "Film grain"), "grain", 0, 1)
        }
        tab(tr("Obraz", "Image")) { v, y in
            addPopup(v, &y, tr("Obraz z kodu", "Image from code"), "mode",
                     [tr("Tylko deszcz", "Rain only"), tr("Zdjęcia", "Photos"), tr("Zegar", "Clock"), tr("Zdjęcia i zegar", "Photos & clock"), tr("Wideo", "Video")])
            addPopup(v, &y, tr("Kolor obrazu", "Image color"), "photoColor",
                     [tr("Kolor motywu", "Theme color"), tr("Kolory zdjęcia", "Photo colors")])
            addPopup(v, &y, tr("Przejście obrazu", "Image transition"), "dissolve",
                     [tr("Płynne", "Fade"), tr("Rozpad na znaki", "Dissolve into glyphs")])
            addSlider(v, &y, tr("Widoczność obrazu", "Image strength"), "imgMix", 0.2, 1)
            addSlider(v, &y, tr("Zmiana obrazu (s)", "Image change (s)"), "period", 5, 60)
            let choose = NSButton(title: tr("Wybierz zdjęcia…", "Choose photos…"), target: self, action: #selector(choosePhotos(_:)))
            choose.frame = NSRect(x: 16, y: y - 4, width: 150, height: 28)
            v.addSubview(choose)
            let clear = NSButton(title: tr("Wyczyść", "Clear"), target: self, action: #selector(clearPhotos(_:)))
            clear.frame = NSRect(x: 172, y: y - 4, width: 90, height: 28)
            v.addSubview(clear)
            let pl = NSTextField(labelWithString: "")
            pl.frame = NSRect(x: 272, y: y, width: 150, height: 20)
            v.addSubview(pl)
            photoLabel = pl
            updatePhotoLabel()
            y -= 40
            let vb = NSButton(title: tr("Wybierz wideo…", "Choose video…"), target: self, action: #selector(chooseVideo(_:)))
            vb.frame = NSRect(x: 16, y: y - 4, width: 150, height: 28)
            v.addSubview(vb)
            let vl = NSTextField(labelWithString: "")
            vl.frame = NSRect(x: 176, y: y, width: 240, height: 20)
            v.addSubview(vl)
            videoLabel = vl
            updateVideoLabel()
        }
        tab(tr("Info", "About")) { v, _ in
            let text = tr(
                "Matrix Rain \(version)\n\nAutor: \(author)\nLicencja: MIT\nKod: \(repoURL)\n\nWygaszacz ekranu w Swift + Metal. Aplikacja Matrix Rain Cam pokazuje obraz z kamery jako kod.\n\nNieoficjalny projekt fanowski, niezwiązany z filmem „Matrix” ani jego właścicielami.",
                "Matrix Rain \(version)\n\nBy \(author)\nLicense: MIT\nSource: \(repoURL)\n\nScreen saver written in Swift + Metal. The Matrix Rain Cam app renders your camera as code.\n\nUnofficial fan project, not affiliated with the film “The Matrix” or its owners.")
            let l = NSTextField(wrappingLabelWithString: text)
            l.frame = NSRect(x: 16, y: 120, width: W - 76, height: 200)
            v.addSubview(l)
        }

        let ok = NSButton(title: "OK", target: self, action: #selector(closeSheet(_:)))
        ok.frame = NSRect(x: W - 90, y: 14, width: 70, height: 28)
        ok.keyEquivalent = "\r"
        content.addSubview(ok)
        // Okno trzyma cele akcji i widok przy życiu (kontrolki mają tylko słabe referencje do celu)
        objc_setAssociatedObject(win, &assocTargets, targets as NSArray, .OBJC_ASSOCIATION_RETAIN)
        objc_setAssociatedObject(win, &assocOwner, self, .OBJC_ASSOCIATION_RETAIN)
    }

    private func updateVideoLabel() {
        let path = defaults?.string(forKey: "videoFile") ?? ""
        let ok = !path.isEmpty && FileManager.default.fileExists(atPath: path)
        videoLabel?.stringValue = ok ? tr("wideo wybrane", "video selected") : tr("brak wideo", "no video")
    }

    @objc private func chooseVideo(_ sender: Any?) {
        let p = NSOpenPanel()
        p.allowsMultipleSelection = false
        p.canChooseDirectories = false
        p.allowedContentTypes = [.movie]
        p.message = tr("Wybierz plik wideo (do 400 MB)", "Choose a video file (up to 400 MB)")
        p.directoryURL = FileManager.default.urls(for: .moviesDirectory, in: .userDomainMask).first
        let handler: (NSApplication.ModalResponse) -> Void = { [weak self] r in
            guard r == .OK, let u = p.url else { return }
            self?.importVideoPath(u.path as NSString)
            self?.updateVideoLabel()
        }
        if let w = sheet { p.beginSheetModal(for: w, completionHandler: handler) }
        else { p.begin(completionHandler: handler) }
    }

    /// Kopiuje wideo do katalogu aplikacji (piaskownica wygaszacza nie zachowuje dostępu do oryginału).
    @objc public func importVideoPath(_ path: NSString) {
        let src = URL(fileURLWithPath: path as String)
        if let size = (try? FileManager.default.attributesOfItem(atPath: src.path))?[.size] as? NSNumber, size.intValue > 400_000_000 { return }
        guard let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("MatrixRain", isDirectory: true) else { return }
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let dst = dir.appendingPathComponent("video-\(Int(Date().timeIntervalSince1970))." + (src.pathExtension.isEmpty ? "mov" : src.pathExtension))
        if let old = defaults?.string(forKey: "videoFile"), !old.isEmpty { try? FileManager.default.removeItem(atPath: old) }
        do { try FileManager.default.copyItem(at: src, to: dst) } catch { return }
        defaults?.set(dst.path, forKey: "videoFile")
        defaults?.synchronize()
    }

    private func updatePhotoLabel() {
        let n = (defaults?.array(forKey: "images") as? [Data])?.count ?? 0
        photoLabel?.stringValue = n == 0 ? tr("brak zdjęć", "no photos") : tr("wybrano: \(n)", "selected: \(n)")
    }

    @objc private func choosePhotos(_ sender: Any?) {
        let p = NSOpenPanel()
        p.allowsMultipleSelection = true
        p.canChooseDirectories = false
        p.allowedContentTypes = [.image]
        p.message = tr("Wybierz do 12 zdjęć", "Choose up to 12 photos")
        p.directoryURL = FileManager.default.urls(for: .picturesDirectory, in: .userDomainMask).first
        let handler: (NSApplication.ModalResponse) -> Void = { [weak self] r in
            guard r == .OK else { return }
            self?.importImagePaths(p.urls.map { $0.path } as NSArray)
            self?.updatePhotoLabel()
        }
        if let w = sheet { p.beginSheetModal(for: w, completionHandler: handler) }
        else { p.begin(completionHandler: handler) }
    }

    @objc private func clearPhotos(_ sender: Any?) {
        importImagePaths([])
        updatePhotoLabel()
    }

    @objc private func closeSheet(_ sender: Any?) {
        loadPrefs()
        guard let s = sheet else { return }
        if let parent = s.sheetParent { parent.endSheet(s) } else { s.orderOut(nil) }
        plog.notice("sheet closed")
        objc_setAssociatedObject(s, &assocOwner, nil, .OBJC_ASSOCIATION_RETAIN)
        sheet = nil
    }
}

// MARK: Kamera

private final class CameraSource: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    private let session = AVCaptureSession()
    private let q = DispatchQueue(label: "matrixrain.camera")
    private let device: MTLDevice
    private var textures: [MTLTexture] = []
    private var readyIndex = -1
    private let lock = NSLock()
    var state = 0

    init(device: MTLDevice) { self.device = device }

    var current: MTLTexture? {
        lock.lock(); defer { lock.unlock() }
        return readyIndex >= 0 ? textures[readyIndex] : nil
    }

    func start() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: configure()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { ok in
                DispatchQueue.main.async { if ok { self.configure() } else { self.state = 1 } }
            }
        default: state = 1
        }
    }

    func stop() {
        q.async { self.session.stopRunning() }
    }

    private func configure() {
        session.beginConfiguration()
        session.sessionPreset = session.canSetSessionPreset(.hd1280x720) ? .hd1280x720 : .high
        guard let cam = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: cam), session.canAddInput(input) else {
            session.commitConfiguration()
            state = 2
            return
        }
        session.addInput(input)
        let out = AVCaptureVideoDataOutput()
        out.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        out.alwaysDiscardsLateVideoFrames = true
        out.setSampleBufferDelegate(self, queue: q)
        if session.canAddOutput(out) { session.addOutput(out) }
        session.commitConfiguration()
        state = 3
        q.async { self.session.startRunning() }
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pb = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        CVPixelBufferLockBaseAddress(pb, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pb, .readOnly) }
        guard let base = CVPixelBufferGetBaseAddress(pb) else { return }
        let w = CVPixelBufferGetWidth(pb), h = CVPixelBufferGetHeight(pb)
        lock.lock()
        if textures.isEmpty || textures[0].width != w || textures[0].height != h {
            textures = (0..<2).compactMap { _ in
                let d = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: w, height: h, mipmapped: true)
                return device.makeTexture(descriptor: d)
            }
            readyIndex = -1
        }
        let idx = (readyIndex + 1) % max(textures.count, 1)
        let tex = textures.isEmpty ? nil : textures[idx]
        lock.unlock()
        guard let t = tex else { return }
        t.replace(region: MTLRegionMake2D(0, 0, w, h), mipmapLevel: 0, withBytes: base, bytesPerRow: CVPixelBufferGetBytesPerRow(pb))
        lock.lock(); readyIndex = idx; lock.unlock()
    }
}


// MARK: Wideo i dźwięk

private final class VideoSource {
    let path: String
    private let player: AVPlayer
    private let output: AVPlayerItemVideoOutput
    private let device: MTLDevice
    private var tex: MTLTexture?
    private var endObserver: NSObjectProtocol?

    init?(path: String, device: MTLDevice) {
        self.path = path
        self.device = device
        let url = URL(fileURLWithPath: path)
        let asset = AVURLAsset(url: url)
        var aspect = 16.0 / 9.0
        if let size = asset.tracks(withMediaType: .video).first?.naturalSize, size.height > 0 {
            aspect = Double(abs(size.width) / abs(size.height))
        }
        let w = 960, h = max(2, Int(Double(w) / aspect))
        output = AVPlayerItemVideoOutput(pixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: w, kCVPixelBufferHeightKey as String: h])
        let item = AVPlayerItem(asset: asset)
        item.add(output)
        player = AVPlayer(playerItem: item)
        player.isMuted = true
        endObserver = NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main) { [weak self] _ in
            self?.player.seek(to: .zero)
            self?.player.play()
        }
        player.play()
    }

    var current: MTLTexture? {
        let t = output.itemTime(forHostTime: CACurrentMediaTime())
        if output.hasNewPixelBuffer(forItemTime: t), let pb = output.copyPixelBuffer(forItemTime: t, itemTimeForDisplay: nil) {
            CVPixelBufferLockBaseAddress(pb, .readOnly)
            defer { CVPixelBufferUnlockBaseAddress(pb, .readOnly) }
            let w = CVPixelBufferGetWidth(pb), h = CVPixelBufferGetHeight(pb)
            if tex == nil || tex!.width != w || tex!.height != h {
                let d = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: w, height: h, mipmapped: true)
                tex = device.makeTexture(descriptor: d)
            }
            if let base = CVPixelBufferGetBaseAddress(pb) {
                tex?.replace(region: MTLRegionMake2D(0, 0, w, h), mipmapLevel: 0, withBytes: base, bytesPerRow: CVPixelBufferGetBytesPerRow(pb))
            }
        }
        return tex
    }

    func stop() {
        player.pause()
        if let o = endObserver { NotificationCenter.default.removeObserver(o); endObserver = nil }
    }
}

private final class AudioLevel {
    private let engine = AVAudioEngine()
    private(set) var level: Float = 0

    func start() {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized: run()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { ok in if ok { DispatchQueue.main.async { self.run() } } }
        default: break
        }
    }

    private func run() {
        let input = engine.inputNode
        let fmt = input.outputFormat(forBus: 0)
        guard fmt.sampleRate > 0 else { return }
        input.installTap(onBus: 0, bufferSize: 1024, format: fmt) { [weak self] buf, _ in
            guard let self = self, let ch = buf.floatChannelData?[0] else { return }
            let n = Int(buf.frameLength)
            var sum: Float = 0
            for i in 0..<n { sum += ch[i] * ch[i] }
            let rms = sqrt(sum / Float(max(n, 1)))
            let target = min(1, rms * 8)
            self.level = target > self.level ? target : self.level * 0.92 + target * 0.08
        }
        try? engine.start()
    }

    func stop() {
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
    }
}
