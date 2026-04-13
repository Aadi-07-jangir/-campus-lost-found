FROM python:3.11-slim

WORKDIR /app

# System deps
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential && \
    rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

# Pre-download models during build (optional — saves startup time)
# RUN python -c "from transformers import BlipProcessor, BlipForConditionalGeneration, CLIPProcessor, CLIPModel; \
#     BlipProcessor.from_pretrained('Salesforce/blip-image-captioning-base'); \
#     BlipForConditionalGeneration.from_pretrained('Salesforce/blip-image-captioning-base'); \
#     CLIPProcessor.from_pretrained('openai/clip-vit-base-patch32'); \
#     CLIPModel.from_pretrained('openai/clip-vit-base-patch32')"

EXPOSE 8000

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
