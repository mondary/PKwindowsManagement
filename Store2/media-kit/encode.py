from pathlib import Path
import subprocess
from PIL import Image

root = Path(__file__).resolve().parents[1]
frames = '/var/folders/jb/07k9zyks6_d60c27tclhjd2h0000gn/T/opencode/store2-frames/%04d.png'
subprocess.run(['ffmpeg','-hide_banner','-loglevel','error','-y','-framerate','24','-i',frames,'-c:v','libx264','-crf','20','-pix_fmt','yuv420p','-movflags','+faststart',str(root/'videos/window-flow.mp4')],check=True)
for name,width in [('wide',960),('compact',480)]:
    graph = f'fps=12,scale={width}:-1:flags=lanczos,split[a][b];[a]palettegen=max_colors=128[p];[b][p]paletteuse=dither=bayer:bayer_scale=3'
    subprocess.run(['ffmpeg','-hide_banner','-loglevel','error','-y','-i',str(root/'videos/window-flow.mp4'),'-filter_complex',graph,'-loop','0',str(root/f'gifs/window-flow-{name}.gif')],check=True)
Image.open(root/'screenshots/demo-poster.png').convert('RGB').save(root/'screenshots/demo-poster.webp',quality=88)
