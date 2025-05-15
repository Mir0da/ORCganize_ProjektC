from fastapi import FastAPI
from fastapi.responses import StreamingResponse
from ner_utils import extract_tokens
from ics_utils import create_file_content
from io import BytesIO
from pydantic import BaseModel


app = FastAPI(
    title = "Event Extraction API",
    description = "Extrahiert Event-Informationen aus Bildern und erstellt .ics-Dateien.",
    version = "1.0.0",
)

class TextInput(BaseModel): #Text Input Files
    content: str  

@app.get("/")
def root():
    return {"Hello": "World"}


@app.post("/upload")
def upload(data: TextInput):# -> str:
    #picture -> page segmentation -> ocr -> sentence
    sentence = data.content
    name_tokens, date_tokens, time_tokens, location_tokens, duration_tokens, link_tokens = extract_tokens(sentence)
    content = create_file_content(name_tokens, date_tokens, time_tokens, location_tokens, duration_tokens, link_tokens)

    file_like = BytesIO()
    file_like.write(content.encode("utf-8"))
    file_like.seek(0)  # Cursor zurück zum Anfang setzen

    return StreamingResponse(
        file_like,
        media_type="text/plain",
        headers={"Content-Disposition": "attachment; filename=entry.txt"}
    )

    # cd C:\Users\Avery\Documents\GitHub\ORCganize_ProjektC\backend\app
    # uvicorn main:app --reload
    # curl -X POST "http://127.0.0.1:8000/upload?sentence=16.%20April%202023%2015%20Uhr,%20Treffen%20am%20See%20f%FCrs%20Meeting"
    # curl -X POST http://127.0.0.1:8000/upload -H "Content-Type: application/json" -d @payload.json
