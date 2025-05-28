import os
import argparse
from pathlib import Path
from pdf2image import convert_from_path
from datetime import datetime

def log(message):
    time = datetime.now().strftime("%H:%M:%S")
    print(f"[{time}] {message}")

def pdf_to_images(pdf_path, dpi=300, fmt="png"):
    pdf_path = Path(pdf_path).resolve()
    if not pdf_path.exists():
        log(f"❌ File not found: {pdf_path}")
        return

    # Create output directory
    output_folder = pdf_path.parent / f"{pdf_path.stem}_images"
    output_folder.mkdir(exist_ok=True)

    log(f"📄 PDF loaded: {pdf_path}")
    log(f"📁 Output directory: {output_folder}")
    log(f"🔧 Settings: DPI = {dpi}, Format = {fmt}")

    try:
        log("🚀 Starting conversion of PDF to images...")
        images = convert_from_path(str(pdf_path), dpi=dpi)
    except Exception as e:
        log(f"❌ Error during conversion: {e}")
        return

    for i, img in enumerate(images):
        page_number = i + 1
        image_path = output_folder / f"page_{page_number:03d}.{fmt}"
        try:
            log(f"🖼️  Processing page {page_number}...")
            img.save(image_path)
            log(f"✅ Page {page_number} saved as: {image_path.name}")
        except Exception as e:
            log(f"⚠️  Error saving page {page_number}: {e}")

    log(f"\n🎉 Done: {len(images)} pages converted successfully into '{output_folder}'.")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Convert a PDF into images.")
    parser.add_argument("pdf_path", help="Path to the PDF file to convert.")
    parser.add_argument("--dpi", type=int, default=300, help="Image resolution (default: 300).")
    parser.add_argument("--fmt", default="png", choices=["png", "jpeg", "jpg", "tiff"], help="Image output format.")

    args = parser.parse_args()
    pdf_to_images(args.pdf_path, dpi=args.dpi, fmt=args.fmt)
