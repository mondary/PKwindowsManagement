from pathlib import Path
import subprocess
from PIL import Image

store = Path(__file__).resolve().parents[1]
web = store / 'website'
src = store / 'sources'
frames = '/var/folders/jb/07k9zyks6_d60c27tclhjd2h0000gn/T/opencode/store-frames/%04d.png'
subprocess.run(['ffmpeg','-hide_banner','-loglevel','error','-y','-framerate','24','-i',frames,'-c:v','libx264','-crf','20','-pix_fmt','yuv420p','-movflags','+faststart',str(web/'videos/window-flow.mp4')],check=True)
for name,width,folder in [('wide',960,web/'gifs'),('compact',480,src/'gifs')]:
    graph = f'fps=12,scale={width}:-1:flags=lanczos,split[a][b];[a]palettegen=max_colors=128[p];[b][p]paletteuse=dither=bayer:bayer_scale=3'
    subprocess.run(['ffmpeg','-hide_banner','-loglevel','error','-y','-i',str(web/'videos/window-flow.mp4'),'-filter_complex',graph,'-loop','0',str(folder/f'window-flow-{name}.gif')],check=True)
Image.open(src/'screenshots/demo-poster.png').convert('RGB').save(web/'screenshots/demo-poster.webp',quality=88)
