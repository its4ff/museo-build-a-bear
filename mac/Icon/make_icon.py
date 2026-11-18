# museo for mac's app icon: the dot ring (Resources/RingDotsTiltLit.webp) on paper and on moss.
#   python3 mac/Icon/make_icon.py mac/Resources mac/Icon
# writes AppIcon-paper.png and AppIcon-moss.png (1024). The app uses Resources/AppIcon.icns, made from one of
# them with iconutil (an iconset of 16 to 1024). The app uses moss.
import sys, random
from PIL import Image, ImageDraw, ImageFilter, ImageChops
src, out = sys.argv[1], sys.argv[2]
ring = Image.open(f"{src}/RingDotsTiltLit.webp").convert("RGBA")
W = 1024; BODY = 824; R = 186
def hexrgb(h): return tuple(int(h[i:i+2],16) for i in (0,2,4))
INK, BONE, AMBER, WHITE = hexrgb("1B2118"), hexrgb("F4F1E8"), hexrgb("F57829"), hexrgb("FFFFFF")

def recolor(dot, light):
    px = ring.load(); w,h = ring.size
    outp = Image.new("RGBA", ring.size, (0,0,0,0)); op = outp.load()
    lit = Image.new("L", ring.size, 0); lp = lit.load()
    for y in range(h):
        for x in range(w):
            r,g,b,a = px[x,y]
            if a < 8: continue
            if r - b > 70 and r > 150:      # the amber light
                op[x,y] = light + (a,); lp[x,y] = a
            else:
                lum = (r+g+b)/765
                op[x,y] = dot + (int(a*min(1,lum*1.15)),)
    return outp, lit

def body(fill_top, fill_bottom, grain):
    img = Image.new("RGBA", (W,W), (0,0,0,0))
    grad = Image.new("RGBA", (BODY,BODY))
    gd = ImageDraw.Draw(grad)
    for y in range(BODY):
        t = y/(BODY-1)
        gd.line([(0,y),(BODY,y)], fill=tuple(int(fill_top[i]*(1-t)+fill_bottom[i]*t) for i in range(3))+(255,))
    random.seed(4)
    noise = Image.effect_noise((BODY,BODY), 40).convert("L")
    noise = noise.point(lambda v: 128 + (v-128)*grain/40)
    grad = Image.merge("RGBA", [ImageChops.add(c, noise, 1, -128) for c in grad.convert("RGB").split()] + [Image.new("L",(BODY,BODY),255)])
    mask = Image.new("L", (BODY,BODY), 0); ImageDraw.Draw(mask).rounded_rectangle([0,0,BODY-1,BODY-1], R, fill=255)
    off = (W-BODY)//2
    shadow = Image.new("RGBA",(W,W),(0,0,0,0)); sm = Image.new("L",(W,W),0)
    ImageDraw.Draw(sm).rounded_rectangle([off, off+14, off+BODY, off+BODY+14], R, fill=90)
    shadow.putalpha(sm.filter(ImageFilter.GaussianBlur(18)))
    img.alpha_composite(shadow)
    img.paste(grad, (off,off), mask)
    return img, mask, off

def make(name, top, bottom, dot, grain, glow_strength, light):
    img, mask, off = body(top, bottom, grain)
    art, lit = recolor(dot, light)
    scale = 2
    art = art.resize((art.width*scale, art.height*scale), Image.NEAREST)
    lit = lit.resize(art.size, Image.NEAREST)
    x = (W-art.width)//2; y = (W-art.height)//2 + 10
    # the light's glow, soft, under the dots
    glow = Image.new("RGBA", art.size, light+(0,))
    glow.putalpha(lit.filter(ImageFilter.GaussianBlur(26)).point(lambda v: min(255,int(v*glow_strength))))
    layer = Image.new("RGBA",(W,W),(0,0,0,0))
    layer.alpha_composite(glow,(x,y)); layer.alpha_composite(art,(x,y))
    clip = Image.new("L",(W,W),0); clip.paste(mask,(off,off))
    layer.putalpha(ImageChops.multiply(layer.getchannel("A"), clip))
    img.alpha_composite(layer)
    img.save(f"{out}/{name}.png")

# On paper the light stays amber (memory): white would vanish into the page.
make("AppIcon-paper", hexrgb("F8F6EF"), hexrgb("E9E3D2"), INK, 16, 1.6, AMBER)
# The app's icon: the white light of streaming, which is what the mac app is for. It sits on
# bone dots, so its glow is pushed harder than amber's was to read as a light.
make("AppIcon-moss", hexrgb("2E432F"), hexrgb("16211A"), BONE, 12, 3.2, WHITE)
