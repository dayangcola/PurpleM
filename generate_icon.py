#!/usr/bin/env python3
"""
Purple星语时光 App Icon Generator
生成一个紫微斗数主题的App图标
"""

from PIL import Image, ImageDraw, ImageFont
import math
import os

def create_app_icon(size=1024):
    """创建一个紫微斗数主题的App图标"""
    
    # 创建一个新的RGBA图像
    img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    
    # 定义颜色 - 调整为更浅的色调
    bg_gradient_start = (140, 100, 180)  # 浅紫色
    bg_gradient_end = (100, 120, 160)    # 浅蓝紫色
    gold = (255, 230, 140)              # 浅金色
    pink = (245, 180, 210)              # 浅粉色
    cyan = (150, 230, 255)              # 浅青色
    white = (255, 255, 255)            # 白色
    
    # 创建渐变背景
    for y in range(size):
        ratio = y / size
        r = int(bg_gradient_start[0] * (1 - ratio) + bg_gradient_end[0] * ratio)
        g = int(bg_gradient_start[1] * (1 - ratio) + bg_gradient_end[1] * ratio)
        b = int(bg_gradient_start[2] * (1 - ratio) + bg_gradient_end[2] * ratio)
        draw.rectangle([(0, y), (size, y + 1)], fill=(r, g, b))
    
    # 画圆形边框（模拟iOS圆角）
    corner_radius = int(size * 0.22)  # iOS标准圆角
    
    # 创建一个mask来实现圆角
    mask = Image.new('L', (size, size), 0)
    mask_draw = ImageDraw.Draw(mask)
    mask_draw.rounded_rectangle([(0, 0), (size-1, size-1)], corner_radius, fill=255)
    
    # 应用mask
    img.putalpha(mask)
    
    # 重新创建draw对象
    draw = ImageDraw.Draw(img)
    
    # 绘制12宫格（简化版）
    center_x, center_y = size // 2, size // 2
    radius = int(size * 0.35)
    
    # 绘制外圆
    draw.ellipse(
        [(center_x - radius, center_y - radius), 
         (center_x + radius, center_y + radius)],
        outline=gold, width=3
    )
    
    # 绘制内圆
    inner_radius = int(radius * 0.5)
    draw.ellipse(
        [(center_x - inner_radius, center_y - inner_radius), 
         (center_x + inner_radius, center_y + inner_radius)],
        outline=cyan, width=2
    )
    
    # 绘制12个分割线
    for i in range(12):
        angle = math.radians(i * 30 - 90)
        x1 = center_x + inner_radius * math.cos(angle)
        y1 = center_y + inner_radius * math.sin(angle)
        x2 = center_x + radius * math.cos(angle)
        y2 = center_y + radius * math.sin(angle)
        draw.line([(x1, y1), (x2, y2)], fill=gold, width=2)
    
    # 在四个角落添加星星装饰
    star_positions = [
        (size * 0.15, size * 0.15),
        (size * 0.85, size * 0.15),
        (size * 0.15, size * 0.85),
        (size * 0.85, size * 0.85)
    ]
    
    for pos_x, pos_y in star_positions:
        draw_star(draw, pos_x, pos_y, 15, pink)
    
    # 在中心绘制紫微星符号
    # 绘制一个大的主星
    draw_star(draw, center_x, center_y, 40, gold, filled=True)
    
    # 添加光晕效果
    for i in range(3):
        halo_radius = inner_radius - 10 - i * 15
        if halo_radius > 0:
            alpha = 50 - i * 15
            draw.ellipse(
                [(center_x - halo_radius, center_y - halo_radius), 
                 (center_x + halo_radius, center_y + halo_radius)],
                outline=(*gold, alpha), width=1
            )
    
    # 在底部添加"紫微"文字（如果能找到字体）
    try:
        # 尝试使用系统中文字体
        font_paths = [
            "/System/Library/Fonts/PingFang.ttc",
            "/System/Library/Fonts/STHeiti Light.ttc",
            "/Library/Fonts/Arial Unicode.ttf"
        ]
        font = None
        for font_path in font_paths:
            if os.path.exists(font_path):
                font = ImageFont.truetype(font_path, int(size * 0.08))
                break
        
        if font:
            text = "紫微"
            bbox = draw.textbbox((0, 0), text, font=font)
            text_width = bbox[2] - bbox[0]
            text_height = bbox[3] - bbox[1]
            text_x = center_x - text_width // 2
            text_y = center_y + radius + 20
            draw.text((text_x, text_y), text, fill=gold, font=font)
    except:
        pass  # 如果找不到字体，就跳过文字
    
    return img

def draw_star(draw, x, y, size, color, filled=False, points=5):
    """绘制一个五角星"""
    angles = []
    for i in range(points * 2):
        if i % 2 == 0:
            angles.append((x + size * math.cos(math.radians(i * 360 / (points * 2) - 90)),
                          y + size * math.sin(math.radians(i * 360 / (points * 2) - 90))))
        else:
            angles.append((x + size * 0.4 * math.cos(math.radians(i * 360 / (points * 2) - 90)),
                          y + size * 0.4 * math.sin(math.radians(i * 360 / (points * 2) - 90))))
    
    if filled:
        draw.polygon(angles, fill=color, outline=color)
    else:
        draw.polygon(angles, outline=color, width=2)

def main():
    """生成所需的图标文件"""
    output_dir = "/Users/link/Downloads/iztro-main/PurpleM/PurpleM/Assets.xcassets/AppIcon.appiconset"
    
    # 生成1024x1024的主图标
    icon = create_app_icon(1024)
    icon.save(os.path.join(output_dir, "AppIcon-1024.png"), "PNG")
    print(f"✅ Generated AppIcon-1024.png")
    
    # 生成其他尺寸（如果需要）
    sizes = [
        (16, 1), (16, 2),
        (32, 1), (32, 2),
        (128, 1), (128, 2),
        (256, 1), (256, 2),
        (512, 1), (512, 2)
    ]
    
    for base_size, scale in sizes:
        actual_size = base_size * scale
        resized = create_app_icon(actual_size)
        filename = f"AppIcon-{base_size}x{base_size}@{scale}x.png"
        resized.save(os.path.join(output_dir, filename), "PNG")
        print(f"✅ Generated {filename}")
    
    print("\n🎨 All icons generated successfully!")
    print(f"📁 Location: {output_dir}")

if __name__ == "__main__":
    main()