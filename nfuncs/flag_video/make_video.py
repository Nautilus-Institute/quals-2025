from moviepy import TextClip, ColorClip, CompositeVideoClip, ImageClip, AudioFileClip
import moviepy.video.fx as vfx


def create_text_video(output_file="flag_2.mp4"):
    # Create a black background
    prefix = "Prepping -\\|/-\\|/-\\|/ "
    flag = "flag{1_000_000_p1eces_2cf8e7f99db1f30aa7f2cf12368b5c0p} "
    full_duration = len(prefix + flag) * 0.3

    bg = ColorClip(size=(720, 480), color=(0xff, 0xff, 0xff), duration=full_duration)
    colors = ['black', 'yellow', 'cyan', 'red', 'green', 'blue', 'purple', 'orange', 'pink', 'brown']
    rbg_colors = [
        (0, 0, 0),        # black
        (255, 255, 0),    # yellow
        (0, 255, 255),    # cyan
        (255, 0, 0),      # red
        (0, 255, 0),      # green
        (0, 0, 255),      # blue
        (128, 0, 128),    # purple
        (255, 165, 0),    # orange
        (255, 192, 203),  # pink
        (165, 42, 42)     # brown
    ]
    
    clips = []
    s = prefix + flag
    for i, char in enumerate(s):
        font_bg = rbg_colors[(i + 1) % len(rbg_colors)]
        side_font_color = rbg_colors[(i + 2) % len(rbg_colors)]
        
        # repeat this character everywhere
        for x in range(0):
            for y in range(7):
                txt = TextClip(
                    font='SourceCodePro-Regular.ttf',
                    text=f"\n{s[i-1] if i >= 1 else '?'}\n",
                    font_size=150,
                    stroke_width=6,
                    stroke_color=side_font_color,
                    color=side_font_color,
                )
                txt = txt.with_position((0 + x * 125, 0 + y * 140)).with_duration(0.2).with_start(0.5 + i * 0.3)
                clips.append(txt)

        txt = TextClip(
            font='SourceCodePro-Regular.ttf',
            text=f"\n{char}\n",
            font_size=150,
            stroke_width=2,
            stroke_color=colors[i % len(colors)],
            margin=(400, 400),
            color=colors[i % len(colors)],
            bg_color=font_bg,
        )
        txt = txt.with_position('center').with_duration(0.2).with_start(0.5 + i * 0.3)
        clips.append(txt)
    
    # add the logo and display it at bottom right
    logo = ImageClip("nautilus.png").with_effects([vfx.Resize(width=200, height=200)])
    logo = logo.with_position(("right", "bottom")).with_duration(full_duration)
    clips.append(logo)

    # add the audio
    audio = AudioFileClip("power_core.mp3").subclipped(0, full_duration)

    # Combine all clips
    final = CompositeVideoClip([bg, *clips])
    final.audio = audio
    # Write the video file
    final.write_videofile(output_file, fps=8, codec='libx264', audio_bitrate="32k")


if __name__ == "__main__":
    create_text_video() 