from fastapi import FastAPI
from ner_utils import extract_tokens
from ics_utils import create_ics

app = FastAPI(
    title = "Event Extraction API",
    description = "Extrahiert Event-Informationen aus Bildern und erstellt .ics-Dateien.",
    version = "1.0.0",
)



@app.get("/")
def root():
    return {"Hello": "World"}


@app.post("/upload")
def upload(sentence: str) -> str:
    #picture -> ocr -> sentence
    name_tokens, date_tokens, time_tokens, location_tokens, duration_tokens, link_tokens = extract_tokens(sentence)
    ics_data = create_ics(name_tokens, date_tokens, time_tokens, location_tokens, duration_tokens, link_tokens)
    return ics_data


    #uvicorn main:app --reload
    #curl -X POST "http://127.0.0.1:8000/upload?sentence=16.%20April%202023%2015%20Uhr,%20Treffen%20am%20See%20f%FCrs%20Meeting"


