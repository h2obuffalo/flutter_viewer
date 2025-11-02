# Word Animation Guide

## Converting Your Adobe Illustrator File to SVG

Since the animation works best with SVG files that have text elements, you need to export your `.ai` file to SVG format:

### Method 1: Using Adobe Illustrator (Recommended)
1. Open your `BFW2025-SMILEY-LINEUP-Merch-Print.ai` file in Adobe Illustrator
2. Go to **File > Export > Export As...**
3. Choose **SVG (svg)** as the format
4. Click **Export**
5. In the SVG Options dialog:
   - Check **"Preserve Illustrator Editing Capabilities"** (optional but helpful)
   - Under **Fonts**, choose **Convert to Outlines** or keep as text (text is better for word separation)
   - Click **OK**
6. Save the SVG file

### Method 2: Using Online Converter
- Use services like:
  - https://convertio.co/ai-svg/
  - https://cloudconvert.com/ai-to-svg
  - https://www.zamzar.com/convert/ai-to-svg/
- Upload your `.ai` file and download the SVG

## Using the Animation

1. Open `word-animation.html` in your web browser
2. Click **"Upload SVG"** and select your exported SVG file
3. The words will be automatically extracted from the text elements
4. Use the buttons:
   - **Explode**: Words scatter outward in a circular pattern
   - **Mouse Mode**: Toggle interactive mode where words move away from your cursor
   - **Rearrange & Reassemble**: Words explode, shuffle positions, then return in a different order but same shape
   - **Reset**: Returns words to their original positions

## Features

- **Word Separation**: Automatically detects and separates words from SVG text elements
- **Mouse Interaction**: Words react to mouse movement, creating an interactive effect
- **Explode Animation**: Words scatter outward and can be rearranged
- **Smooth Animations**: Uses requestAnimationFrame for smooth 60fps animations

## Tips

- For best results, make sure your text in Illustrator is not converted to outlines (keep it as editable text)
- If words aren't being detected, check that your SVG contains `<text>` elements
- The animation works best when text elements are separate rather than grouped

