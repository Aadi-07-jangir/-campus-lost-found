"""
Campus Lost & Found — AI Model Server
======================================
Uses BLIP for image captioning and CLIP for embedding-based matching.
Built with FastAPI for high performance REST API.
"""

import io
import os
import logging
from typing import Optional
from contextlib import asynccontextmanager

import numpy as np
import torch
from PIL import Image
from fastapi import FastAPI, File, UploadFile, HTTPException, Form
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from transformers import BlipProcessor, BlipForConditionalGeneration, CLIPProcessor, CLIPModel

# ─── Config ───────────────────────────────────────────────────────
LOG_LEVEL = os.getenv("LOG_LEVEL", "INFO")
MODEL_CACHE = os.getenv("MODEL_CACHE", "./model_cache")
MATCH_THRESHOLD = float(os.getenv("MATCH_THRESHOLD", "0.60"))
HOST = os.getenv("HOST", "0.0.0.0")
PORT = int(os.getenv("PORT", "8000"))

logging.basicConfig(level=LOG_LEVEL)
logger = logging.getLogger("ai_server")

# ─── Global model holders ─────────────────────────────────────────
blip_processor = None
blip_model = None
clip_processor = None
clip_model = None
device = None


def load_models():
    """Load BLIP and CLIP models into memory."""
    global blip_processor, blip_model, clip_processor, clip_model, device

    device = "cuda" if torch.cuda.is_available() else "cpu"
    logger.info(f"Using device: {device}")

    logger.info("Loading BLIP model (image captioning)...")
    blip_processor = BlipProcessor.from_pretrained(
        "Salesforce/blip-image-captioning-base",
        cache_dir=MODEL_CACHE,
    )
    blip_model = BlipForConditionalGeneration.from_pretrained(
        "Salesforce/blip-image-captioning-base",
        cache_dir=MODEL_CACHE,
    ).to(device)

    logger.info("Loading CLIP model (embeddings & matching)...")
    clip_processor = CLIPProcessor.from_pretrained(
        "openai/clip-vit-base-patch32",
        cache_dir=MODEL_CACHE,
    )
    clip_model = CLIPModel.from_pretrained(
        "openai/clip-vit-base-patch32",
        cache_dir=MODEL_CACHE,
    ).to(device)

    logger.info("All models loaded successfully!")


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Load models on startup, cleanup on shutdown."""
    load_models()
    yield
    logger.info("Shutting down AI server...")


# ─── FastAPI App ──────────────────────────────────────────────────
app = FastAPI(
    title="Campus Lost & Found — AI Server",
    description="BLIP captioning + CLIP embedding + cosine matching",
    version="2.0.0",
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Tighten in production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# ─── Pydantic Schemas ────────────────────────────────────────────
class CaptionResponse(BaseModel):
    caption: str


class EmbeddingResponse(BaseModel):
    embedding: list[float]
    caption: str


class MatchRequest(BaseModel):
    embedding_a: list[float]
    embedding_b: list[float]


class MatchResponse(BaseModel):
    similarity: float
    is_match: bool
    threshold: float


class BulkMatchRequest(BaseModel):
    query_embedding: list[float]
    candidate_embeddings: list[list[float]]
    candidate_ids: list[str]
    threshold: Optional[float] = None
    query_caption: Optional[str] = None
    candidate_captions: Optional[list[str]] = None


class BulkMatchItem(BaseModel):
    item_id: str
    similarity: float


class BulkMatchResponse(BaseModel):
    matches: list[BulkMatchItem]
    threshold: float


class TextEmbeddingRequest(BaseModel):
    text: str


class TextEmbeddingResponse(BaseModel):
    embedding: list[float]


# ─── Helper Functions ─────────────────────────────────────────────
def read_image(file_bytes: bytes) -> Image.Image:
    """Read uploaded bytes into a PIL Image."""
    try:
        image = Image.open(io.BytesIO(file_bytes)).convert("RGB")
        return image
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Invalid image: {e}")


def generate_caption(image: Image.Image) -> str:
    """Generate a natural-language caption using BLIP."""
    inputs = blip_processor(image, return_tensors="pt").to(device)
    with torch.no_grad():
        output = blip_model.generate(**inputs, max_new_tokens=100)
    caption = blip_processor.decode(output[0], skip_special_tokens=True)
    return caption


def generate_image_embedding(image: Image.Image) -> np.ndarray:
    """Generate a CLIP image embedding (normalised)."""
    inputs = clip_processor(images=image, return_tensors="pt").to(device)
    with torch.no_grad():
        features = clip_model.get_image_features(**inputs)
    if hasattr(features, 'pooler_output'):
        embedding = features.pooler_output.cpu().numpy().flatten()
    elif hasattr(features, 'last_hidden_state'):
        embedding = features.last_hidden_state[:, 0, :].cpu().numpy().flatten()
    else:
        embedding = features.cpu().numpy().flatten()
    embedding = embedding / np.linalg.norm(embedding)
    return embedding


def generate_text_embedding(text: str) -> np.ndarray:
    """Generate a CLIP text embedding (normalised)."""
    inputs = clip_processor(text=[text], return_tensors="pt", padding=True).to(device)
    with torch.no_grad():
        features = clip_model.get_text_features(**inputs)
    if hasattr(features, 'pooler_output'):
        embedding = features.pooler_output.cpu().numpy().flatten()
    elif hasattr(features, 'last_hidden_state'):
        embedding = features.last_hidden_state[:, 0, :].cpu().numpy().flatten()
    else:
        embedding = features.cpu().numpy().flatten()
    embedding = embedding / np.linalg.norm(embedding)
    return embedding


def cosine_similarity(a: np.ndarray, b: np.ndarray) -> float:
    """Compute cosine similarity between two vectors."""
    return float(np.dot(a, b) / (np.linalg.norm(a) * np.linalg.norm(b) + 1e-8))


# ─── API Endpoints ────────────────────────────────────────────────
@app.get("/health")
async def health_check():
    """Health check endpoint."""
    return {
        "status": "healthy",
        "device": str(device),
        "models_loaded": blip_model is not None and clip_model is not None,
    }


@app.post("/caption", response_model=CaptionResponse)
async def caption_image(file: UploadFile = File(...)):
    """
    Upload an image → get an AI-generated caption via BLIP.
    Used when a student reports a lost/found item.
    """
    file_bytes = await file.read()
    image = read_image(file_bytes)
    caption = generate_caption(image)
    logger.info(f"Caption generated: {caption}")
    return CaptionResponse(caption=caption)


@app.post("/embed", response_model=EmbeddingResponse)
async def embed_image(file: UploadFile = File(...)):
    """
    Upload an image → get CLIP embedding + BLIP caption.
    This is the main endpoint called when a new item is reported.
    The embedding is stored in the database for later matching.
    """
    file_bytes = await file.read()
    image = read_image(file_bytes)

    caption = generate_caption(image)
    embedding = generate_image_embedding(image)

    logger.info(f"Embedding generated (dim={len(embedding)}), caption: {caption}")
    return EmbeddingResponse(
        embedding=embedding.tolist(),
        caption=caption,
    )


@app.post("/embed-text", response_model=TextEmbeddingResponse)
async def embed_text(request: TextEmbeddingRequest):
    """
    Generate CLIP text embedding from a description.
    Useful for text-based search across items.
    """
    embedding = generate_text_embedding(request.text)
    return TextEmbeddingResponse(embedding=embedding.tolist())


@app.post("/match", response_model=MatchResponse)
async def match_two_items(request: MatchRequest):
    """
    Compare two embeddings and return similarity score.
    Used to check if a specific lost item matches a found item.
    """
    a = np.array(request.embedding_a)
    b = np.array(request.embedding_b)
    sim = cosine_similarity(a, b)
    return MatchResponse(
        similarity=round(sim, 4),
        is_match=sim >= MATCH_THRESHOLD,
        threshold=MATCH_THRESHOLD,
    )


@app.post("/match-bulk", response_model=BulkMatchResponse)
async def match_bulk(request: BulkMatchRequest):
    """
    Compare a query embedding against many candidates.
    Returns all matches above the threshold sorted by similarity.
    """
    threshold = request.threshold or MATCH_THRESHOLD
    query = np.array(request.query_embedding)
    matches = []

    logger.info(f"Bulk match: query dim={len(request.query_embedding)}, candidates={len(request.candidate_embeddings)}, threshold={threshold}")

    for i, (cid, candidate) in enumerate(zip(request.candidate_ids, request.candidate_embeddings)):
        candidate_arr = np.array(candidate)
        sim = cosine_similarity(query, candidate_arr)
        logger.info(f"  Candidate {cid}: similarity={sim:.4f} (threshold={threshold})")

        if sim >= threshold:
            matches.append(BulkMatchItem(item_id=cid, similarity=round(sim, 4)))

    matches.sort(key=lambda m: m.similarity, reverse=True)
    logger.info(f"Bulk match: {len(matches)} matches found (threshold={threshold})")
    return BulkMatchResponse(matches=matches, threshold=threshold)


@app.post("/process-item")
async def process_item(
    file: UploadFile = File(...),
    item_type: str = Form(...),  # "lost" or "found"
    user_description: Optional[str] = Form(None),
):
    """
    All-in-one endpoint: upload image → caption + embedding + combined embedding.
    Combines image embedding with text embedding of (caption + user description)
    for more accurate matching.
    """
    file_bytes = await file.read()
    image = read_image(file_bytes)

    # Step 1: BLIP caption
    caption = generate_caption(image)

    # Step 2: CLIP image embedding
    img_embedding = generate_image_embedding(image)

    # Step 3: Combined text for richer embedding
    combined_text = caption
    if user_description:
        combined_text = f"{caption}. {user_description}"

    text_embedding = generate_text_embedding(combined_text)

    # Step 4: Fuse image + text embeddings (weighted average)
    # Image gets highly dominant weight (95%) so exact image matches aren't impacted by varying descriptions.
    fused = 0.95 * img_embedding + 0.05 * text_embedding
    fused = fused / np.linalg.norm(fused)  # Re-normalise

    return {
        "caption": caption,
        "embedding": fused.tolist(),
        "image_embedding": img_embedding.tolist(),
        "text_embedding": text_embedding.tolist(),
        "item_type": item_type,
    }


# ─── Run ──────────────────────────────────────────────────────────
if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host=HOST, port=PORT, reload=True)