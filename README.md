# Campus Lost & Found — AI-Powered Item Recovery

## Tech Stack
- **Frontend:** Flutter (Web + Android + iOS)
- **Backend:** Supabase (Auth, Database, Storage)
- **AI Server:** Python FastAPI (BLIP + CLIP)

## Quick Start (3 Steps)

### Step 1: Supabase Setup (3 min)
1. Go to https://supabase.com → Sign up → New Project
2. Wait for project to be ready
3. Go to **SQL Editor** → New Query → Paste entire content of `supabase_setup.sql` → Click **RUN**
4. Go to **Settings** → **API** → Copy **Project URL** and **anon public key**

### Step 2: Config Update (1 min)
Open `flutter_app/lib/utils/config.dart` and replace:
- `YOUR_SUPABASE_URL` with your Project URL
- `YOUR_SUPABASE_ANON_KEY` with your anon key

### Step 3: Run Flutter App (2 min)
```
cd flutter_app
flutter clean && flutter pub get && flutter run -d chrome
```

## AI Server (Optional — for image matching)
```
cd ai_server
pip install -r requirements.txt
python main.py
```

## How AI Matching Works
1. Student uploads photo → BLIP generates caption
2. CLIP creates 512-dim embedding → stored in DB
3. New item compared against all opposite items via cosine similarity
4. 75%+ match → notification!

## Project Structure
```
campus-lost-found/
├── flutter_app/lib/
│   ├── main.dart
│   ├── models/ (item_model, user_model, match_result)
│   ├── providers/ (auth_provider, items_provider)
│   ├── screens/ (login, signup, home, report, detail, matches, profile)
│   ├── services/ (auth, database, storage, ai)
│   ├── utils/ (config, theme)
│   └── widgets/ (item_card)
├── ai_server/ (FastAPI + BLIP + CLIP)
├── supabase_setup.sql (one-click DB setup)
└── README.md
```
